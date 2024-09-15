import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let BADGE_CHANNEL = FlutterMethodChannel(name: "mobile.lishogi.org/badge",
                                                    binaryMessenger: controller.binaryMessenger)

    let SYSTEM_CHANNEL = FlutterMethodChannel(name: "mobile.lishogi.org/system",
                                                    binaryMessenger: controller.binaryMessenger)

    BADGE_CHANNEL.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }

        if let args = call.arguments as? Dictionary<String, Any>,
            let badge = args["badge"] as? Int {
            UIApplication.shared.applicationIconBadgeNumber = badge
            result(nil)
        } else {
            result(FlutterError(code: "bad_args", message: "bad arguments", details: nil))
        }
    })

    SYSTEM_CHANNEL.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "getTotalRam" else {
        result(FlutterMethodNotImplemented)
        return
      }

      result(self.getPhysicalMemory())
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getPhysicalMemory() -> Int {
    let memory : Int = Int(ProcessInfo.processInfo.physicalMemory)
    let constant : Int = 1_048_576
    let res = memory / constant
    return Int(res)
  }
}
