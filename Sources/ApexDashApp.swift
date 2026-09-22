import SwiftUI

@main
struct ApexDashApp: App {
    @StateObject private var client = TelemetryClient()

    var body: some Scene {
        WindowGroup {
            RootDashboardView()
                .environmentObject(client)
                .preferredColorScheme(.dark)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    client.start()
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                    client.stop()
                }
        }
    }
}
