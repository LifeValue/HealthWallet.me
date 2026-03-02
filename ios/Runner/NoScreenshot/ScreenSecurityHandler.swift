import Flutter
import UIKit

class PassthroughTextField: UITextField {
    override var canBecomeFirstResponder: Bool { false }
}

class ScreenSecurityHandler {
    private var secureField: UITextField?
    private var nativeOverlay: UIView?
    private weak var windowRef: UIWindow?

    func register(with controller: FlutterViewController, window: UIWindow?) {
        windowRef = window

        let methodChannel = FlutterMethodChannel(
            name: "app.screen_security",
            binaryMessenger: controller.binaryMessenger
        )

        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            DispatchQueue.main.async {
                switch call.method {
                case "enable":
                    self?.enable()
                    result(nil)
                case "disable":
                    self?.disable()
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    private func enable() {
        guard secureField == nil, let window = windowRef else { return }

        let overlay = buildBrandedOverlay(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        nativeOverlay = overlay

        let field = PassthroughTextField()
        field.isSecureTextEntry = true
        field.backgroundColor = .clear
        field.frame = window.bounds
        field.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        guard let secureContainer = field.subviews.first else { return }
        secureContainer.frame = field.bounds
        secureContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        secureContainer.isUserInteractionEnabled = true

        if let rootView = window.rootViewController?.view {
            secureContainer.addSubview(rootView)
            rootView.frame = secureContainer.bounds
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        window.addSubview(field)
        secureField = field
    }

    private func disable() {
        guard let window = windowRef else { return }

        if let rootView = window.rootViewController?.view {
            window.addSubview(rootView)
            rootView.frame = window.bounds
            rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        secureField?.removeFromSuperview()
        secureField = nil

        nativeOverlay?.removeFromSuperview()
        nativeOverlay = nil
    }

    private func buildBrandedOverlay(frame: CGRect) -> UIView {
        let container = UIView(frame: frame)
        container.backgroundColor = .white

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView()
        iconView.image = UIImage(named: "AppLogo")
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 18
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let appNameLabel = UILabel()
        appNameLabel.text = "HealthWallet.me"
        appNameLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        appNameLabel.textColor = UIColor(red: 0.17, green: 0.18, blue: 0.19, alpha: 1.0)
        appNameLabel.textAlignment = .center

        let warningLabel = UILabel()
        warningLabel.text = "NO SCREENSHOT ALLOWED ON THE SHARED HEALTH RECORDS"
        warningLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        warningLabel.textColor = .black
        warningLabel.textAlignment = .center
        warningLabel.numberOfLines = 0

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(appNameLabel)
        stack.addArrangedSubview(warningLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),
        ])

        return container
    }
}
