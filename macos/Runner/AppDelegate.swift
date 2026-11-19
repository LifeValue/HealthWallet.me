import Cocoa
import FlutterMacOS
import Vision

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool)
        -> Bool
    {
        mainFlutterWindow?.makeKeyAndOrderFront(nil)
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    /// Registers the app's own channels. MainFlutterWindow calls it right after the
    /// generated plugins, before Dart can call them: applicationDidFinishLaunching
    /// runs after the Dart code has already started.
    func registerChannels(messenger: FlutterBinaryMessenger) {
        let ocrChannel = FlutterMethodChannel(
            name: "dev.lifevalue.healthwallet/ocr", binaryMessenger: messenger)
        ocrChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }

        let fsChannel = FlutterMethodChannel(
            name: "dev.lifevalue.healthwallet/fs", binaryMessenger: messenger)
        fsChannel.setMethodCallHandler { [unowned self] (call, result) in
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
            } else if call.method == "createBookmark" {
                self.createBookmark(call, result: result)
            } else if call.method == "resolveBookmark" {
                self.resolveBookmark(call, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

    }

    /// Folders opened through a bookmark in this run, so access is started once.
    private var accessedFolders = [String: URL]()

    /// Saves a security-scoped bookmark for a folder the user just chose, so the
    /// sandboxed app can open it again after a restart. Returns it as base64.
    private func createBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
            result(FlutterError(code: "bad_args", message: "path is required", details: nil))
            return
        }
        do {
            let data = try URL(fileURLWithPath: path, isDirectory: true).bookmarkData(
                options: [.withSecurityScope], includingResourceValuesForKeys: nil,
                relativeTo: nil)
            result(data.base64EncodedString())
        } catch {
            result(
                FlutterError(
                    code: "bookmark_failed", message: error.localizedDescription, details: nil))
        }
    }

    /// Opens a folder from its bookmark and keeps it accessible for this run.
    /// Returns the folder path, whether access was granted and, when macOS marks
    /// the bookmark stale, a fresh one to save instead.
    private func resolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let base64 = (call.arguments as? [String: Any])?["bookmark"] as? String,
            let data = Data(base64Encoded: base64)
        else {
            result(FlutterError(code: "bad_args", message: "bookmark is required", details: nil))
            return
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            var granted = accessedFolders[url.path] != nil
            if !granted {
                granted = url.startAccessingSecurityScopedResource()
                if granted { accessedFolders[url.path] = url }
            }
            var refreshed: String?
            if isStale {
                refreshed = try? url.bookmarkData(
                    options: [.withSecurityScope], includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ).base64EncodedString()
            }
            result(["path": url.path, "granted": granted, "bookmark": refreshed as Any])
        } catch {
            result(
                FlutterError(
                    code: "bookmark_failed", message: error.localizedDescription, details: nil))
        }
    }

    override func applicationWillTerminate(_ notification: Notification) {
        for url in accessedFolders.values {
            url.stopAccessingSecurityScopedResource()
        }
        accessedFolders.removeAll()
        super.applicationWillTerminate(notification)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "recognizeText" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String
        else {
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
            let cgImage = bitmap.cgImage
        else {
            return ""
        }

        var recognizedText = ""
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { (request, error) in
            defer { semaphore.signal() }

            guard error == nil,
                let observations = request.results as? [VNRecognizedTextObservation]
            else {
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
