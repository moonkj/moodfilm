import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    CameraEnginePlugin.register(with: self.registrar(forPlugin: "CameraEnginePlugin")!)
    FilterEnginePlugin.register(with: self.registrar(forPlugin: "FilterEnginePlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
