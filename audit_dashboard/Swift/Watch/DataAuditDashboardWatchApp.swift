import SwiftUI

@main
struct DataAuditDashboardWatchApp: App {
    @StateObject private var store = ReportDataStore()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
        }
    }
}