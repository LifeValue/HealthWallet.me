#include "windows_ocr_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <roapi.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <algorithm>
#include <future>
#include <string>
#include <memory>
#include <thread>

namespace wrt {
  using namespace winrt::Windows::Foundation;
  using namespace winrt::Windows::Graphics::Imaging;
  using namespace winrt::Windows::Media::Ocr;
  using namespace winrt::Windows::Storage;
  using namespace winrt::Windows::Storage::Streams;
}

static std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), nullptr, 0);
  std::wstring wide(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), wide.data(), size);
  return wide;
}

static std::string PerformOcr(const std::string& image_path) {
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
  } catch (...) {
    // Already initialized — fine
  }

  try {
    // Normalize path: forward slashes to backslashes
    std::string normalized = image_path;
    std::replace(normalized.begin(), normalized.end(), '/', '\\');
    std::wstring wide_path = Utf8ToWide(normalized);

    auto file = wrt::StorageFile::GetFileFromPathAsync(wide_path).get();
    auto stream = file.OpenAsync(wrt::FileAccessMode::Read).get();

    auto decoder = wrt::BitmapDecoder::CreateAsync(stream).get();
    auto bitmap = decoder.GetSoftwareBitmapAsync().get();

    auto engine = wrt::OcrEngine::TryCreateFromUserProfileLanguages();
    if (!engine) {
      return "";
    }

    auto ocr_result = engine.RecognizeAsync(bitmap).get();
    auto text = ocr_result.Text();

    return winrt::to_string(text);
  } catch (const winrt::hresult_error& e) {
    OutputDebugStringW(L"[OCR] WinRT error: ");
    OutputDebugStringW(e.message().c_str());
    OutputDebugStringW(L"\n");
    return "";
  } catch (...) {
    OutputDebugStringW(L"[OCR] Unknown error\n");
    return "";
  }
}

void RegisterOcrChannel(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "dev.lifevalue.healthwallet/ocr",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        if (call.method_name() == "recognizeText") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Success(flutter::EncodableValue(std::string("")));
            return;
          }

          auto it = args->find(flutter::EncodableValue(std::string("imagePath")));
          if (it == args->end()) {
            result->Success(flutter::EncodableValue(std::string("")));
            return;
          }

          const auto* path = std::get_if<std::string>(&it->second);
          if (!path) {
            result->Success(flutter::EncodableValue(std::string("")));
            return;
          }

          std::string image_path = *path;
          auto shared_result = std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
              std::move(result));

          std::thread([image_path, shared_result]() {
            auto text = PerformOcr(image_path);
            shared_result->Success(flutter::EncodableValue(text));
          }).detach();

        } else {
          result->NotImplemented();
        }
      });
}
