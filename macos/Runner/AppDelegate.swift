import Cocoa
import FlutterMacOS
import Vision

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "dev.lifevalue.healthwallet/ocr",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
    super.applicationDidFinishLaunching(notification)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeText" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let args = call.arguments as? [String: Any],
          let imagePath = args["imagePath"] as? String else {
      result("")
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let recognized = self.performOCR(imagePath: imagePath)
      DispatchQueue.main.async {
        result(recognized)
      }
    }
  }

  private func performOCR(imagePath: String) -> String {
    let url = URL(fileURLWithPath: imagePath)

    guard let image = NSImage(contentsOf: url),
          let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let cgImage = bitmap.cgImage else {
      return ""
    }

    var recognizedText = ""
    let semaphore = DispatchSemaphore(value: 0)

    let request = VNRecognizeTextRequest { (request, error) in
      defer { semaphore.signal() }

      guard error == nil,
            let observations = request.results as? [VNRecognizedTextObservation] else {
        return
      }

      let lines = observations.compactMap { observation in
        observation.topCandidates(1).first?.string
      }

      recognizedText = lines.joined(separator: "\n")
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    do {
      try handler.perform([request])
      semaphore.wait()
    } catch {
      return ""
    }

    return recognizedText
  }
}
