import Flutter
import UIKit
// Import GoogleMaps to provide the API key at app launch
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Provide the Google Maps API key for iOS (injected)
    GMSServices.provideAPIKey("AIzaSyBQzc7kXsWfJofK1i5c3JMmUaizwVJMbr0")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
