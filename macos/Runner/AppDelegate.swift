import Cocoa
import FlutterMacOS
import Vision

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    if !hasVisibleWindows {
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let messenger = controller.engine.binaryMessenger

    let ocrChannel = FlutterMethodChannel(name: "dev.lifevalue.healthwallet/ocr", binaryMessenger: messenger)
    ocrChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }

    let fsChannel = FlutterMethodChannel(name: "dev.lifevalue.healthwallet/fs", binaryMessenger: messenger)
    fsChannel.setMethodCallHandler { (call, result) in
      if call.method == "pickDirectory" {
        let args = call.arguments as? [String: Any]
        let initialPath = args?["initialDirectory"] as? String
        let title = args?["title"] as? String ?? "Choose Folder"

        DispatchQueue.main.async {
          let panel = NSOpenPanel()
          panel.canChooseDirectories = true
          panel.canChooseFiles = false
          panel.canCreateDirectories = true
          panel.allowsMultipleSelection = false
          panel.title = title
          panel.prompt = "Choose"

          if let path = initialPath {
            panel.directoryURL = URL(fileURLWithPath: path)
          }

          let response = panel.runModal()
          if response == .OK, let url = panel.url {
            result(url.path)
          } else {
            result(nil)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
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
