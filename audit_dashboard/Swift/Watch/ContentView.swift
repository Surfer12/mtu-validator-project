import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var store: ReportDataStore

    private var latest: AuditEntry? { store.entries.first }

    var body: some View {
        VStack {
            if let entry = latest {
                ComplianceBadge(flags: entry.complianceFlags)
                    .padding(.bottom, 4)
                Text(entry.timestamp)
                    .font(.caption2)
                Text(entry.dataAccess.app)
                    .font(.caption)
            } else {
                Text("No Reports Yet")
            }
        }
    }
}

#if DEBUG
struct WatchContentView_Previews: PreviewProvider {
    static var previews: some View {
        WatchContentView()
            .environmentObject(ReportDataStore())
    }
}
#endif