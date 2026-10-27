import CoreBluetooth
import Flutter
import PassKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private let screenSecurity = ScreenSecurityHandler()
    private let textRecognition = TextRecognitionHandler()
    private var bluetoothDelegate: BluetoothStateDelegate?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // With the UIScene lifecycle the scene creates the Flutter engine after launch, so plugins and
    // the app's own channels are registered here, once the engine exists.
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let messenger = engineBridge.applicationRegistrar.messenger()
        screenSecurity.register(with: messenger, windowProvider: { AppDelegate.activeWindow() })
        textRecognition.register(with: messenger)

        let walletChannel = FlutterMethodChannel(
            name: "com.techstackapps.healthwallet/apple_wallet",
            binaryMessenger: messenger
        )
        walletChannel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "addPass" {
                guard let args = call.arguments as? [String: Any],
                    let filePath = args["filePath"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGS", message: "filePath required", details: nil))
                    return
                }
                self?.addPassToWallet(filePath: filePath, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        bluetoothDelegate = BluetoothStateDelegate()

        let bluetoothChannel = FlutterMethodChannel(
            name: "com.techstackapps.healthwallet/bluetooth",
            binaryMessenger: messenger
        )
        bluetoothChannel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "isBluetoothEnabled":
                result(self?.bluetoothDelegate?.isBluetoothOn ?? false)
            case "requestEnable":
                if let url = URL(string: "App-Prefs:Bluetooth") {
                    UIApplication.shared.open(url)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let bluetoothEventChannel = FlutterEventChannel(
            name: "com.techstackapps.healthwallet/bluetooth_state",
            binaryMessenger: messenger
        )
        bluetoothEventChannel.setStreamHandler(bluetoothDelegate)
    }

    /// The foreground scene's window. With the UIScene lifecycle the window belongs to the scene;
    /// the app delegate's `window` is nil.
    static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }

    private func addPassToWallet(filePath: String, result: @escaping FlutterResult) {
        guard let passData = FileManager.default.contents(atPath: filePath) else {
            result(
                FlutterError(
                    code: "FILE_NOT_FOUND", message: "Pass file not found at \(filePath)",
                    details: nil))
            return
        }

        do {
            let pass = try PKPass(data: passData)
            guard let addPassVC = PKAddPassesViewController(pass: pass) else {
                result(
                    FlutterError(
                        code: "PASS_ERROR", message: "Could not create add pass controller",
                        details: nil))
                return
            }

            let rootVC = AppDelegate.activeWindow()?.rootViewController
            var topVC = rootVC
            while let presented = topVC?.presentedViewController {
                topVC = presented
            }

            topVC?.present(addPassVC, animated: true) {
                result(true)
            }
        } catch {
            result(
                FlutterError(
                    code: "PASS_INVALID", message: error.localizedDescription, details: nil))
        }
    }
}

class BluetoothStateDelegate: NSObject, FlutterStreamHandler, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var eventSink: FlutterEventSink?
    var isBluetoothOn = false

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self, queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: false
            ])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn
        eventSink?(isBluetoothOn)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
