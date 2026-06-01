import Foundation

// MARK: - Airworthiness Directive

struct ADSummary: Identifiable, Hashable, Codable, Sendable {
    var id: String { adNumber }
    let adNumber: String          // "2024-17-05"
    let adYear: Int
    let title: String
    let effectiveDate: String?    // ISO 8601
    let ataChapter: String?       // "32"
    let isEmergency: Bool
    let summary: String           // ~1-2 paragraph abstract
}

struct ADDetail: Hashable, Sendable {
    let summary: ADSummary
    let body: String              // may be empty when body-cutoff applied
    let bodyDropped: Bool
    let cfrAmendment: String?     // "39-22456"
    let federalRegisterID: String?
    let complianceTime: String?
    let supersedes: String?
    let supersededBy: String?
    let pdfURL: URL?
    let frURL: URL?
}

struct ADApplicability: Hashable, Sendable {
    let adNumber: String
    let manufacturer: String
    let model: String
    let modelSeries: String?
    let serialRangeStart: String?
    let serialRangeEnd: String?
    let partType: String?         // Airframe / Engine / Propeller / Appliance
    let notes: String?
}

// MARK: - 14 CFR (FAR)

struct FARSection: Identifiable, Hashable, Sendable {
    let id: String                // "14-cfr-43.13"
    let partNumber: String        // "43"
    let sectionNumber: String     // "43.13"
    let subpart: String?
    let heading: String
    let body: String
    let citation: String          // "14 CFR § 43.13"
    let lastAmended: String?
}

// MARK: - Type Certificate Data Sheet

struct TCDSummary: Identifiable, Hashable, Sendable {
    var id: String { tcdsNumber }
    let tcdsNumber: String        // "3A12"
    let category: String          // "Aircraft" / "Engine" / "Propeller"
    let manufacturer: String
    let models: String            // CSV — split on demand for filter UI
    let issueDate: String?
    let lastRevision: String?
    let specifications: String    // JSON blob
    let pdfURL: URL?
}

// MARK: - Advisory Circular

struct ACEntry: Identifiable, Hashable, Sendable {
    var id: String { acNumber }
    let acNumber: String          // "AC 43.13-1B"
    let title: String
    let issueDate: String?
    let relatedFAR: String?
    let pdfURL: URL
}
