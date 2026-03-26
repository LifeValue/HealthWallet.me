import Flutter
import UIKit
import PassKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let screenSecurity = ScreenSecurityHandler()
    private var bluetoothDelegate: BluetoothStateDelegate?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        screenSecurity.register(with: controller, window: window)

        let walletChannel = FlutterMethodChannel(
            name: "com.techstackapps.healthwallet/apple_wallet",
            binaryMessenger: controller.binaryMessenger
        )
        walletChannel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "addPass" {
                guard let args = call.arguments as? [String: Any],
                      let filePath = args["filePath"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
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
            binaryMessenger: controller.binaryMessenger
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
            binaryMessenger: controller.binaryMessenger
        )
        bluetoothEventChannel.setStreamHandler(bluetoothDelegate)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func addPassToWallet(filePath: String, result: @escaping FlutterResult) {
        guard let passData = FileManager.default.contents(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Pass file not found at \(filePath)", details: nil))
            return
        }

        do {
            let pass = try PKPass(data: passData)
            guard let addPassVC = PKAddPassesViewController(pass: pass) else {
                result(FlutterError(code: "PASS_ERROR", message: "Could not create add pass controller", details: nil))
                return
            }

            let rootVC = window?.rootViewController
            var topVC = rootVC
            while let presented = topVC?.presentedViewController {
                topVC = presented
            }

            topVC?.present(addPassVC, animated: true) {
                result(true)
            }
        } catch {
            result(FlutterError(code: "PASS_INVALID", message: error.localizedDescription, details: nil))
        }
    }
}

class BluetoothStateDelegate: NSObject, FlutterStreamHandler, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var eventSink: FlutterEventSink?
    var isBluetoothOn = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn
        eventSink?(isBluetoothOn)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
