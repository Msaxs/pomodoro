import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .landscape
    }

    func applicationWillTerminate(_ application: UIApplication) {
        ActivityManager.shared.terminateAllNow()
    }
}
#endif

@main
struct pomodoroApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var viewModel = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                #if os(iOS)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willTerminateNotification
                    )
                ) { _ in
                    ActivityManager.shared.terminateAllNow()
                }
                #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.sceneDidEnterBackground()
            case .active:
                viewModel.sceneDidEnterForeground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
