import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(name: "floor_plan/native", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "shareFile" {
          guard let args = call.arguments as? [String: Any],
                let filePath = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Path is required", details: nil))
            return
          }
          let fileUrl = URL(fileURLWithPath: filePath)
          let activityVC = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          controller.present(activityVC, animated: true, completion: nil)
          result(true)
        } else if call.method == "printHtml" {
          guard let args = call.arguments as? [String: Any],
                let html = args["html"] as? String else {
            result(false)
            return
          }
          let printController = UIPrintInteractionController.shared
          let printInfo = UIPrintInfo(dictionary: nil)
          printInfo.outputType = .general
          printInfo.jobName = "План квартиры PRO"
          printController.printInfo = printInfo
          let formatter = UIMarkupTextPrintFormatter(markupText: html)
          formatter.perPageContentInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
          printController.printFormatter = formatter
          printController.present(animated: true, completionHandler: nil)
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
