import SwiftUI
import Combine

@main
struct DataAuditDashboardApp: App {
    @StateObject private var store = ReportDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}