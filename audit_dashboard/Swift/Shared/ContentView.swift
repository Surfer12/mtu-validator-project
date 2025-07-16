import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ReportDataStore

    var body: some View {
        NavigationView {
            List(store.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.timestamp)
                            .font(.footnote)
                        Spacer()
                        ComplianceBadge(flags: entry.complianceFlags)
                    }
                    Text("File: \(entry.dataAccess.file)")
                        .font(.subheadline)
                    Text("App: \(entry.dataAccess.app)")
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Audit Reports")
        }
    }
}

struct ComplianceBadge: View {
    let flags: ComplianceFlags

    var body: some View {
        HStack(spacing: 6) {
            Label("GDPR", systemImage: flags.GDPR == "PASS" ? "checkmark.seal" : "exclamationmark.triangle")
                .foregroundColor(flags.GDPR == "PASS" ? .green : .yellow)
                .font(.caption)
            Label("SOX", systemImage: flags.SOX.hasPrefix("PASS") ? "checkmark.seal" : "xmark.octagon")
                .foregroundColor(flags.SOX.hasPrefix("PASS") ? .green : .red)
                .font(.caption)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ReportDataStore())
    }
}
#endif