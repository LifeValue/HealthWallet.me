import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let screenSecurity = ScreenSecurityHandler()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        screenSecurity.register(with: controller, window: window)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
