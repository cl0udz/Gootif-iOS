import Foundation

// MARK: - Visual blocks
//
// Agents may attach a `blocks` array to a report payload (rendered after the
// summary) and/or to individual items (rendered inside the item card). Each
// block is a small, typed visualization: stat row, table, bar chart, or line
// chart. Unknown block types decode as `.unknown` and are skipped, so older
// app builds never break on newer agents.

enum ReportBlock: Codable, Identifiable {
    case statRow(StatRowBlock)
    case table(TableBlock)
    case barChart(BarChartBlock)
    case lineChart(LineChartBlock)
    case unknown

    var id: UUID { UUID() }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""
        let single = try decoder.singleValueContainer()
        switch type {
        case "stat_row": self = .statRow(try single.decode(StatRowBlock.self))
        case "table": self = .table(try single.decode(TableBlock.self))
        case "bar_chart": self = .barChart(try single.decode(BarChartBlock.self))
        case "line_chart": self = .lineChart(try single.decode(LineChartBlock.self))
        default: self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .statRow(let b): try single.encode(b)
        case .table(let b): try single.encode(b)
        case .barChart(let b): try single.encode(b)
        case .lineChart(let b): try single.encode(b)
        case .unknown: break
        }
    }
}

struct StatRowBlock: Codable {
    let type: String?
    let stats: [Stat]

    struct Stat: Codable, Identifiable {
        let label: String
        let value: String
        let delta: String?
        let direction: String?  // up | down | flat — favorable/unfavorable coloring
        var id: String { label + value }
    }
}

struct TableBlock: Codable {
    let type: String?
    let title: String?
    let columns: [String]
    let rows: [[String]]
}

struct BarChartBlock: Codable {
    let type: String?
    let title: String?
    let unit: String?
    let bars: [Bar]

    struct Bar: Codable, Identifiable {
        let label: String
        let value: Double
        let color: String?  // positive | negative | neutral | accent
        var id: String { label }
    }
}

struct LineChartBlock: Codable {
    let type: String?
    let title: String?
    let unit: String?
    let series: [Series]

    struct Series: Codable, Identifiable {
        let name: String
        let points: [Point]
        var id: String { name }
    }

    struct Point: Codable, Identifiable {
        let x: String
        let y: Double
        var id: String { x }
    }
}
