import Foundation
import UIKit

/// Renders any Aero entity into the user's chosen copy format and puts the
/// resulting string on the pasteboard. Centralized so the row swipe action,
/// the row context menu, and the detail-screen menu all stay byte-identical.
@MainActor
enum AeroCopier {

    // MARK: - Airworthiness Directives

    @discardableResult
    static func copy(_ summary: ADSummary, format: CopyFormat) -> String {
        let text: String
        switch format {
        case .short:
            text = "AD \(summary.adNumber)"
        case .withTitle, .fullDetail:
            text = "AD \(summary.adNumber) — \(summary.title)"
        }
        return Pasteboard.copy(text)
    }

    @discardableResult
    static func copyFullDetail(_ detail: ADDetail,
                               applicability: [ADApplicability]) -> String {
        var lines: [String] = []
        lines.append("AD \(detail.summary.adNumber) — \(detail.summary.title)")
        if let date = detail.summary.effectiveDate {
            lines.append("Effective: \(date)")
        }
        if let ata = detail.summary.ataChapter {
            lines.append("ATA \(ata)")
        }
        if let amd = detail.cfrAmendment {
            lines.append("Amendment 39-\(amd) (14 CFR Part 39)")
        }
        if let comp = detail.complianceTime, !comp.isEmpty {
            lines.append("Compliance: \(comp)")
        }
        if !applicability.isEmpty {
            let models = applicability.map {
                "  • \($0.manufacturer) \($0.model)"
                    + ($0.partType.map { " [\($0)]" } ?? "")
            }
            lines.append("Applies to:")
            lines.append(contentsOf: models.prefix(10))
            if applicability.count > 10 {
                lines.append("  …and \(applicability.count - 10) more.")
            }
        }
        if !detail.summary.summary.isEmpty {
            lines.append("")
            lines.append(detail.summary.summary)
        }
        if let url = detail.frURL {
            lines.append("")
            lines.append("Federal Register: \(url.absoluteString)")
        }
        return Pasteboard.copy(lines.joined(separator: "\n"))
    }

    // MARK: - 14 CFR (FAR)

    @discardableResult
    static func copy(_ section: FARSection, format: CopyFormat,
                     bluebook: Bool = false) -> String {
        let citation = bluebook ? bluebookCitation(section) : section.citation
        let text: String
        switch format {
        case .short:
            text = citation
        case .withTitle, .fullDetail:
            text = "\(citation) — \(section.heading)"
        }
        return Pasteboard.copy(text)
    }

    @discardableResult
    static func copyFullDetail(_ section: FARSection, bluebook: Bool) -> String {
        let citation = bluebook ? bluebookCitation(section) : section.citation
        var lines = ["\(citation) — \(section.heading)", ""]
        lines.append(section.body)
        return Pasteboard.copy(lines.joined(separator: "\n"))
    }

    /// Bluebook legal-citation form: "14 C.F.R. § 43.13".
    /// Adds the periods Bluebook style requires and preserves the § sign.
    static func bluebookCitation(_ s: FARSection) -> String {
        "14 C.F.R. § \(s.sectionNumber)"
    }

    // MARK: - Type Certificate Data Sheets

    @discardableResult
    static func copy(_ tcds: TCDSummary, format: CopyFormat) -> String {
        let text: String
        switch format {
        case .short:
            text = "TCDS \(tcds.tcdsNumber)"
        case .withTitle, .fullDetail:
            text = "TCDS \(tcds.tcdsNumber) — \(tcds.manufacturer)"
        }
        return Pasteboard.copy(text)
    }

    @discardableResult
    static func copyFullDetail(_ tcds: TCDSummary) -> String {
        var lines: [String] = []
        lines.append("TCDS \(tcds.tcdsNumber) (\(tcds.category))")
        lines.append("Manufacturer: \(tcds.manufacturer)")
        lines.append("Models: \(tcds.models)")
        if let d = tcds.issueDate {
            lines.append("Issued: \(d)")
        }
        return Pasteboard.copy(lines.joined(separator: "\n"))
    }
}
