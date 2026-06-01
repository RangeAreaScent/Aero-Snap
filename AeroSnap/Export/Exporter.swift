import Foundation
import UIKit

/// CSV exporters for the two user-curated lists we want to ship to
/// spreadsheets or fleet-management tools: starred favorites and the
/// per-tail-number folder collections.
///
/// Output is RFC 4180 — UTF-8, CRLF line endings, fields with commas /
/// quotes / newlines double-quoted. Numbers stays able to open these
/// directly; Excel needs the `.csv` extension to recognize them.
enum Exporter {
    /// Quote a value if it contains a comma, double-quote, or newline.
    static func quote(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") || raw.contains("\r") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }

    // MARK: - Favorites

    static func csv(favoriteADs ads: [ADSummary]) -> String {
        let header = [
            "AD Number", "Title", "Effective Date",
            "ATA Chapter", "Emergency", "Summary",
        ]
        var rows: [[String]] = [header]
        for s in ads {
            rows.append([
                s.adNumber,
                s.title,
                s.effectiveDate ?? "",
                s.ataChapter ?? "",
                s.isEmergency ? "Yes" : "No",
                s.summary,
            ])
        }
        return rows
            .map { $0.map(quote).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Folder collection (manual list with per-item compliance)

    static func csv(folder collection: AircraftCollection,
                    items: [(item: AircraftCollectionItem, summary: ADSummary?)]) -> String {
        let header = [
            "AD Number", "Title", "Effective Date", "ATA Chapter",
            "Emergency", "Complied", "Complied Date", "Notes",
        ]
        var rows: [[String]] = [header]
        let isoOut = ISO8601DateFormatter()
        isoOut.formatOptions = [.withFullDate]
        for (item, summary) in items {
            rows.append([
                item.adNumber,
                summary?.title ?? "",
                summary?.effectiveDate ?? "",
                summary?.ataChapter ?? "",
                (summary?.isEmergency ?? false) ? "Yes" : "No",
                item.complied ? "Yes" : "No",
                item.compliedAt.map(isoOut.string(from:)) ?? "",
                item.notes ?? "",
            ])
        }
        return rows
            .map { $0.map(quote).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Temp file helpers

    /// Writes `content` to a temp file suitable for ShareLink. The caller
    /// owns the URL only for the lifetime of the share sheet; iOS cleans
    /// the temp dir periodically.
    static func tempFile(named name: String, content: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safe)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func tempFile(named name: String, data: Data) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safe)
        try? data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - PDF rendering

    /// Render plain text into a US-Letter PDF, paginating automatically.
    /// We use a monospaced body font so the AD numbers and dates stay
    /// column-aligned when the user prints the doc on the way out to a
    /// hangar floor.
    static func pdf(title: String, plainText: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter @ 72 DPI
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.preferredFont(forTextStyle: .title2)
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.black,
        ]
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black,
        ]

        let attributed = NSMutableAttributedString(
            string: title + "\n\n",
            attributes: titleAttrs
        )
        attributed.append(NSAttributedString(string: plainText, attributes: bodyAttrs))

        return renderer.pdfData { ctx in
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            var currentRange = CFRange(location: 0, length: 0)
            let inset: CGFloat = 36   // 0.5"
            let contentRect = pageRect.insetBy(dx: inset, dy: inset)

            repeat {
                ctx.beginPage()
                let cgPath = CGPath(rect: contentRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, currentRange, cgPath, nil)

                let cgCtx = ctx.cgContext
                cgCtx.textMatrix = .identity
                cgCtx.translateBy(x: 0, y: pageRect.height)
                cgCtx.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, cgCtx)
                cgCtx.scaleBy(x: 1, y: -1)
                cgCtx.translateBy(x: 0, y: -pageRect.height)

                let visible = CTFrameGetVisibleStringRange(frame)
                currentRange = CFRange(
                    location: visible.location + visible.length,
                    length: 0
                )
            } while currentRange.location < attributed.length
        }
    }

    /// Pad `s` on the right with spaces so the column lines up at `width`.
    /// Truncates if too long. ASCII-only is fine for our column data.
    private static func pad(_ s: String, _ width: Int) -> String {
        if s.count >= width { return String(s.prefix(width)) }
        return s + String(repeating: " ", count: width - s.count)
    }

    /// Same CSV columns as the spreadsheet exporter, but formatted as
    /// space-padded monospace text for the PDF version.
    static func plainText(favoriteADs ads: [ADSummary]) -> String {
        var lines: [String] = []
        lines.append(pad("AD Number", 14) + pad("Effective", 12)
                     + pad("ATA", 5) + pad("Em?", 4) + "Title")
        lines.append(String(repeating: "-", count: 96))
        for s in ads {
            lines.append(
                pad(s.adNumber, 14)
                + pad(s.effectiveDate ?? "—", 12)
                + pad(s.ataChapter ?? "—", 5)
                + pad(s.isEmergency ? "Yes" : "—", 4)
                + s.title
            )
        }
        return lines.joined(separator: "\n")
    }

    static func plainText(folder collection: AircraftCollection,
                          items: [(item: AircraftCollectionItem, summary: ADSummary?)]) -> String {
        let isoOut = ISO8601DateFormatter()
        isoOut.formatOptions = [.withFullDate]
        var lines: [String] = []
        if let notes = collection.notes, !notes.isEmpty {
            lines.append("NOTES")
            lines.append(notes)
            lines.append("")
        }
        lines.append(pad("AD Number", 14) + pad("Complied", 10)
                     + pad("Date", 12) + "Title")
        lines.append(String(repeating: "-", count: 96))
        for (item, summary) in items {
            let date = item.compliedAt.map(isoOut.string(from:)) ?? "—"
            lines.append(
                pad(item.adNumber, 14)
                + pad(item.complied ? "Yes" : "—", 10)
                + pad(date, 12)
                + (summary?.title ?? "")
            )
            if let note = item.notes, !note.isEmpty {
                lines.append("    note: \(note)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
