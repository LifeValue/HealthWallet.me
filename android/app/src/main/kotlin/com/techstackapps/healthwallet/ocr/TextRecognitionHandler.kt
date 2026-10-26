package com.techstackapps.healthwallet.ocr

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * On-device OCR with ML Kit (Latin script), on the same `dev.lifevalue.healthwallet/ocr`
 * channel the iOS, macOS and Windows runners implement.
 */
class TextRecognitionHandler(private val context: Context) {

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result
            ->
            if (call.method != "recognizeText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val imagePath = call.argument<String>("imagePath")
            if (imagePath == null) {
                result.error("INVALID_ARGS", "imagePath required", null)
                return@setMethodCallHandler
            }

            // fromFilePath applies the photo's EXIF rotation, so camera images are read upright.
            val image = try {
                InputImage.fromFilePath(context, Uri.fromFile(File(imagePath)))
            } catch (e: Exception) {
                result.error("OCR_FAILED", "Could not read $imagePath: ${e.message}", null)
                return@setMethodCallHandler
            }

            recognizer.process(image)
                .addOnSuccessListener { text -> result.success(text.text) }
                .addOnFailureListener { e -> result.error("OCR_FAILED", e.message, null) }
        }
    }

    fun close() {
        recognizer.close()
    }

    companion object {
        private const val CHANNEL = "dev.lifevalue.healthwallet/ocr"
    }
}
