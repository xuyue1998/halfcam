import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class NotifyAdaptor: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var model: AppModel? {
        didSet {
            if pendingDarkboxOpen, let model {
                pendingDarkboxOpen = false
                model.openDarkboxFromNotify()
            }
        }
    }
    private var pendingDarkboxOpen = false

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        ImageStore.shared.trimMemory()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            if let model {
                model.openDarkboxFromNotify()
            } else {
                pendingDarkboxOpen = true
            }
        }
    }
}

@main
struct HalfCamApp: App {
    @UIApplicationDelegateAdaptor(NotifyAdaptor.self) private var notify
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .onAppear { notify.model = model }
                .onOpenURL { url in
                    if url.host == "darkbox" {
                        model.openDarkboxFromNotify()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Haptics.shared.resume()
                        UIApplication.shared.isIdleTimerDisabled = true
                        model.refreshLiveActivities()
                        model.rolloverMonth()
                        Task { await model.membership.refresh() }
                        Task { await model.reconcileExportedPrints() }
                    } else if phase == .background {
                        UIApplication.shared.isIdleTimerDisabled = false
                        model.flushPersistence()
                    }
                }
        }
    }
}
