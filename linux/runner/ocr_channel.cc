#include "ocr_channel.h"

#include <leptonica/allheaders.h>
#include <tesseract/baseapi.h>

#include <cstring>
#include <string>

namespace {

constexpr char kChannelName[] = "dev.lifevalue.healthwallet/ocr";

// PDF pages reach OCR rasterised at 200 dpi (OcrProcessingHelper.pdfDpi);
// photos carry no resolution, and Tesseract would guess 70 dpi for them.
constexpr int kDefaultDpi = 200;

// The Tesseract language for the user's locale, read alongside English as
// Windows.Media.Ocr reads the user's profile languages. Empty when the locale
// is English or one the app is not translated into.
std::string LocaleLanguage() {
  const gchar* const* names = g_get_language_names();
  if (names == nullptr || names[0] == nullptr) return "";
  const std::string locale = names[0];
  if (locale.rfind("de", 0) == 0) return "deu";
  if (locale.rfind("es", 0) == 0) return "spa";
  if (locale.rfind("ro", 0) == 0) return "ron";
  return "";
}

// Loads English and, when its language data is installed, the locale's
// language. Returns false when not even English could be loaded.
bool InitTesseract(tesseract::TessBaseAPI& api) {
  const std::string extra = LocaleLanguage();
  if (!extra.empty()) {
    const std::string both = "eng+" + extra;
    if (api.Init(nullptr, both.c_str()) == 0) return true;
    api.End();
  }
  return api.Init(nullptr, "eng") == 0;
}

// The text in the image at |image_path|, line by line; empty when the image
// cannot be read or Tesseract or its English data is missing.
std::string RecognizeText(const char* image_path) {
  tesseract::TessBaseAPI api;
  if (!InitTesseract(api)) {
    g_warning("OCR: Tesseract could not load its English language data");
    return "";
  }

  Pix* image = pixRead(image_path);
  if (image == nullptr) {
    g_warning("OCR: the image could not be read");
    api.End();
    return "";
  }

  api.SetImage(image);
  if (pixGetXRes(image) <= 0) api.SetSourceResolution(kDefaultDpi);

  std::string text;
  char* recognized = api.GetUTF8Text();
  if (recognized != nullptr) {
    text = recognized;
    delete[] recognized;
  }

  api.End();
  pixDestroy(&image);
  return text;
}

// Runs on a worker thread: Tesseract takes seconds on a full page.
void RecognizeInThread(GTask* task, gpointer source_object, gpointer task_data,
                       GCancellable* cancellable) {
  const std::string text = RecognizeText(static_cast<const char*>(task_data));
  g_task_return_pointer(task, g_strdup(text.c_str()), g_free);
}

// Back on the main thread, where method calls must be answered.
void RespondWithText(GObject* source_object, GAsyncResult* result,
                     gpointer user_data) {
  g_autoptr(FlMethodCall) method_call = FL_METHOD_CALL(user_data);
  g_autofree gchar* text =
      static_cast<gchar*>(g_task_propagate_pointer(G_TASK(result), nullptr));
  g_autoptr(FlValue) value = fl_value_new_string(text != nullptr ? text : "");
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, value, &error)) {
    g_warning("OCR: failed to send the result: %s", error->message);
  }
}

void RespondEmpty(FlMethodCall* method_call) {
  g_autoptr(FlValue) value = fl_value_new_string("");
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, value, &error)) {
    g_warning("OCR: failed to send the result: %s", error->message);
  }
}

void HandleMethodCall(FlMethodChannel* channel, FlMethodCall* method_call,
                      gpointer user_data) {
  if (std::strcmp(fl_method_call_get_name(method_call), "recognizeText") != 0) {
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond_not_implemented(method_call, &error)) {
      g_warning("OCR: failed to answer: %s", error->message);
    }
    return;
  }

  // Same contract as the other platforms: bad arguments read as no text.
  FlValue* args = fl_method_call_get_args(method_call);
  FlValue* path =
      args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
          ? fl_value_lookup_string(args, "imagePath")
          : nullptr;
  if (path == nullptr || fl_value_get_type(path) != FL_VALUE_TYPE_STRING) {
    RespondEmpty(method_call);
    return;
  }

  GTask* task =
      g_task_new(nullptr, nullptr, RespondWithText, g_object_ref(method_call));
  g_task_set_task_data(task, g_strdup(fl_value_get_string(path)), g_free);
  g_task_run_in_thread(task, RecognizeInThread);
  g_object_unref(task);
}

}  // namespace

FlMethodChannel* ocr_channel_new(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, HandleMethodCall, nullptr,
                                            nullptr);
  return channel;
}
