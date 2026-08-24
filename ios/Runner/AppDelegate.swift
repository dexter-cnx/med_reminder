import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      let settingsChannel = FlutterMethodChannel(
        name: "med_reminder/app_settings",
        binaryMessenger: controller.binaryMessenger
      )
      settingsChannel.setMethodCallHandler { call, result in
        guard call.method == "open" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }

      let emergencyChannel = FlutterMethodChannel(
        name: "med_reminder/emergency_contact",
        binaryMessenger: controller.binaryMessenger
      )
      emergencyChannel.setMethodCallHandler { call, result in
        guard let phoneNumber = call.arguments as? String,
              !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          result(false)
          return
        }

        let scheme: String
        switch call.method {
        case "call":
          scheme = "tel"
        case "sms":
          scheme = "sms"
        default:
          result(FlutterMethodNotImplemented)
          return
        }

        guard let encoded = phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(scheme):\(encoded)") else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }
    }

    return launched
  }
}
