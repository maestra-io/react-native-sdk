import UIKit
import React
import UserNotifications
import Mindbox
import MindboxSdk


// https://developers.maestra.io/docs/41-ios-sending-push-notifications
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var bridge: RCTBridge!

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Set the current instance of UNUserNotificationCenter's delegate to self.
        // This enables the AppDelegate to respond to notification events
        UNUserNotificationCenter.current().delegate = self

        // Setting up React Native bridge
        bridge = RCTBridge(delegate: self, launchOptions: launchOptions)
        let rootView = RCTRootView(bridge: bridge, moduleName: "exampleApp", initialProperties: nil)

        // Configuring the application window
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let rootViewController = UIViewController()
        rootViewController.view = rootView
        self.window!.rootViewController = rootViewController
        self.window!.makeKeyAndVisible()

        // https://developers.maestra.io/docs/react-native-sdk
        // Tracking app launch for analytics
        let trackVisitData = TrackVisitData()
        trackVisitData.launchOptions = launchOptions
        Mindbox.shared.track(data: trackVisitData)

        // Register background tasks for iOS 13 and later, or set background fetch interval for earlier versions
        if #available(iOS 13.0, *) {
            Mindbox.shared.registerBGTasks()
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }

        return true
    }
    func notifyReactNative() {
      if let bridge = bridge, let eventEmitter = bridge.module(for: NotificationModule.self) as? NotificationModule {
      eventEmitter.notifyReactNative()
      }
    }
    // Handling remote notification fetch completion
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
        notifyReactNative()
    }

    // Updating APNS token in Maestra
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
    }

    // Handling Universal Links
    // https://developers.maestra.io/docs/universal-links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let trackVisitData = TrackVisitData()
        trackVisitData.universalLink = userActivity
        Mindbox.shared.track(data: trackVisitData)
        return true
    }

    // Displaying notifications when the app is active
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        notifyReactNative()
        completionHandler([.alert, .sound, .badge])
    }

    // Handling push notification clicks
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // https://developers.maestra.io/docs/42-ios-click-counts-for-mobile-push
        Mindbox.shared.pushClicked(response: response)
        // https://developers.maestra.io/docs/react-native-sdk
        // Tracking push notification clicks for analytics
        let trackVisitData = TrackVisitData()
        trackVisitData.push = response
        Mindbox.shared.track(data: trackVisitData)

        // Emitting event for further handling in JavaScript
        // https://developers.maestra.io/docs/5-navigating-push-notification-clicks
        MindboxJsDelivery.emitEvent(response)

        completionHandler()
    }
}

extension AppDelegate: RCTBridgeDelegate {
    func sourceURL(for bridge: RCTBridge!) -> URL! {
        #if DEBUG
            return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
        #else
            return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #endif
    }

    func extraModules(for bridge: RCTBridge!) -> [RCTBridgeModule]! {
      var modules = [RCTBridgeModule]()
      modules.append(NotificationModule())
      return modules
   }
}
