import Foundation

// MARK: - Codable Models matching the JSON output of generate_report.py

public struct DataAccess: Codable, Hashable {
    public let file: String
    public let app: String
    public let networkExfil: String
    public let zeroTrustVerified: Bool

    enum CodingKeys: String, CodingKey {
        case file, app
        case networkExfil = "network_exfil"
        case zeroTrustVerified = "zero_trust_verified"
    }
}

public struct ComplianceFlags: Codable, Hashable {
    public let GDPR: String
    public let SOX: String
}

public struct AuditEntry: Codable, Identifiable, Hashable {
    public var id: UUID { UUID() }

    public let timestamp: String
    public let user: String
    public let device: String
    public let dataAccess: DataAccess
    public let complianceFlags: ComplianceFlags

    enum CodingKeys: String, CodingKey {
        case timestamp, user, device
        case dataAccess = "data_access"
        case complianceFlags = "compliance_flags"
    }
}