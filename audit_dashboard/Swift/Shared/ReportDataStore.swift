import Foundation
import Combine

/// Watches `~/.local/audit_reports/` for new `audit_*.json` files and publishes updates
public final class ReportDataStore: ObservableObject {
    @Published public private(set) var entries: [AuditEntry] = []

    private var directoryURL: URL
    private var monitor: DispatchSourceFileSystemObject?

    public init(directoryPath: String = "~/.local/audit_reports") {
        self.directoryURL = URL(fileURLWithPath: (directoryPath as NSString).expandingTildeInPath)
        loadExisting()
        startMonitoring()
    }

    deinit { monitor?.cancel() }

    /// Load all existing reports on disk
    private func loadExisting() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        let jsonFiles = files.filter { $0.lastPathComponent.hasPrefix("audit_") && $0.pathExtension == "json" }
        self.entries = jsonFiles.compactMap { try? Data(contentsOf: $0) }.
            compactMap { try? JSONDecoder().decode(AuditEntry.self, from: $0) }.
            sorted { $0.timestamp > $1.timestamp }
    }

    /// Watch directory for changes using GCD
    private func startMonitoring() {
        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd != -1 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                           eventMask: .write,
                                                           queue: DispatchQueue.global(qos: .utility))
        src.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.loadExisting()
            }
        }
        src.setCancelHandler {
            close(fd)
        }
        monitor = src
        src.resume()
    }
}