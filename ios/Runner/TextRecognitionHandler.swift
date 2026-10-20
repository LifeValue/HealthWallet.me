import Flutter
import ImageIO
import Vision

/// On-device OCR with Apple's Vision framework, on the same `dev.lifevalue.healthwallet/ocr`
/// channel the macOS, Windows and Android runners implement.
class TextRecognitionHandler {
    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "dev.lifevalue.healthwallet/ocr", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard call.method == "recognizeText" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "imagePath required", details: nil))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let text = self?.recognizeText(imagePath: imagePath)
                DispatchQueue.main.async {
                    if let text = text {
                        result(text)
                    } else {
                        result(FlutterError(code: "OCR_FAILED", message: "Could not read \(imagePath)", details: nil))
                    }
                }
            }
        }
    }

    private func recognizeText(imagePath: String) -> String? {
        let url = URL(fileURLWithPath: imagePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        // Camera photos are stored rotated with an EXIF orientation tag; Vision needs it to read
        // the text upright.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
        } catch {
            return nil
        }

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
