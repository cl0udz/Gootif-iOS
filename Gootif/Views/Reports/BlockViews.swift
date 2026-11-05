import SwiftUI
import Charts

// MARK: - Series palette
//
// Categorical slots for multi-series charts, validated per mode (lightness
// band, chroma floor, CVD separation, contrast vs card surface). Dark mode's
// CVD margin sits in the floor band, so line charts always add a secondary
// identity channel: per-series point symbols + a legend.

enum ChartPalette {
    static let light: [Color] = [
        Color(hex: "0284C7"), Color(hex: "7C3AED"),
        Color(hex: "DB2777"), Color(hex: "D97706"),
    ]
    static let dark: [Color] = [
        Color(hex: "0284C7"), Color(hex: "8B5CF6"),
        Color(hex: "EC4899"), Color(hex: "D97706"),
    ]

    static func slots(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark ? dark : light
    }
}

// MARK: - Blocks container

struct BlocksView: View {
    let blocks: [ReportBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .statRow(let b): StatRowView(block: b)
                case .table(let b): TableBlockView(block: b)
                case .barChart(let b): BarChartView(block: b)
                case .lineChart(let b): LineChartView(block: b)
                case .diagram(let b): DiagramView(block: b)
                case .unknown: EmptyView()
                }
            }
        }
    }
}

struct BlockTitle: View {
    let title: String?
    let unit: String?

    var body: some View {
        if let title {
            (Text(title) + Text(unit.map { $0.isEmpty ? "" : "  (\($0))" } ?? "").foregroundStyle(.secondary))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Stat row

struct StatRowView: View {
    @ScaledMetric(relativeTo: .footnote) private var minimumTileWidth = 150.0
    let block: StatRowBlock

    // Wrap instead of scrolling sideways, so no tile or label is ever cut off.
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumTileWidth), spacing: 10, alignment: .top)],
                  alignment: .leading, spacing: 10) {
            ForEach(block.stats) { stat in
                StatTile(stat: stat)
            }
        }
    }
}

private struct StatTile: View {
    let stat: StatRowBlock.Stat

    private var deltaColor: Color {
        switch stat.direction?.lowercased() {
        case "up": return AppColors.positive
        case "down": return AppColors.negative
        default: return .secondary
        }
    }

    private var deltaSymbol: String {
        switch stat.direction?.lowercased() {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(stat.value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let delta = stat.delta {
                HStack(spacing: 3) {
                    Image(systemName: deltaSymbol)
                        .font(.caption2.weight(.bold))
                    Text(delta)
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(deltaColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Table

struct TableBlockView: View {
    @ScaledMetric(relativeTo: .subheadline) private var minimumColumnWidth = 120.0
    let block: TableBlock

    /// Agents sometimes send all-empty column names; skip the header then.
    private var hasHeader: Bool {
        block.columns.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var columnCount: Int {
        max(block.columns.count, block.rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BlockTitle(title: block.title, unit: nil)

            ViewThatFits(in: .horizontal) {
                tableGrid
                    .frame(minWidth: CGFloat(max(columnCount, 1)) * minimumColumnWidth)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(block.rows.enumerated()), id: \.offset) { index, row in
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                VStack(alignment: .leading, spacing: 2) {
                                    if column < block.columns.count, !block.columns[column].isEmpty {
                                        Text(block.columns[column])
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(cell)
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        if index < block.rows.count - 1 { Divider() }
                    }
                }
            }
        }
        .padding(12)
        .background(AppColors.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tableGrid: some View {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
                if hasHeader {
                    GridRow {
                        ForEach(Array(block.columns.enumerated()), id: \.offset) { _, col in
                            Text(col)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                ForEach(Array(block.rows.enumerated()), id: \.offset) { index, row in
                    if hasHeader || index > 0 {
                        Divider().opacity(0.4)
                            .gridCellUnsizedAxes(.horizontal)
                            .gridCellColumns(columnCount)
                    }
                    GridRow(alignment: .top) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.subheadline)
                                .monospacedDigit()
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 320, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
    }
}

// MARK: - Bar chart

struct BarChartView: View {
    let block: BarChartBlock
    @Environment(\.colorScheme) private var scheme

    private func barColor(_ bar: BarChartBlock.Bar) -> Color {
        switch bar.color?.lowercased() {
        case "positive": return AppColors.positive
        case "negative": return AppColors.negative
        case "neutral": return Color.secondary.opacity(0.55)
        default: return ChartPalette.slots(scheme)[0]
        }
    }

    /// Largest magnitude, used to scale every bar against the same maximum.
    private var maxMagnitude: Double {
        max(block.bars.map { abs($0.value) }.max() ?? 1, .ulpOfOne)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BlockTitle(title: block.title, unit: block.unit)

            // Horizontal meter rows: the label gets the full row width (long
            // category names never collide the way they do on an x-axis) and
            // every value is labeled directly, so no axis is needed.
            ForEach(block.bars) { bar in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(bar.label)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(bar.value.formatted(.number.precision(.fractionLength(0...2))))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(barColor(bar).opacity(0.18))
                            Capsule()
                                .fill(barColor(bar))
                                .frame(width: max(6, geo.size.width * abs(bar.value) / maxMagnitude))
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(12)
        .background(AppColors.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Line chart

struct LineChartView: View {
    let block: LineChartBlock
    @Environment(\.colorScheme) private var scheme

    /// Flattened (series, point) pairs for Charts.
    private var flat: [(series: String, point: LineChartBlock.Point)] {
        block.series.flatMap { s in s.points.map { (s.name, $0) } }
    }

    var body: some View {
        let slots = ChartPalette.slots(scheme)
        let names = block.series.map(\.name)

        VStack(alignment: .leading, spacing: 8) {
            BlockTitle(title: block.title, unit: block.unit)

            Chart {
                ForEach(block.series) { series in
                    ForEach(series.points) { point in
                        LineMark(
                            x: .value("X", point.x),
                            y: .value(block.unit ?? "Value", point.y)
                        )
                        .foregroundStyle(by: .value("Series", series.name))
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("X", point.x),
                            y: .value(block.unit ?? "Value", point.y)
                        )
                        .foregroundStyle(by: .value("Series", series.name))
                        .symbol(by: .value("Series", series.name))
                        .symbolSize(30)
                    }
                }
            }
            .chartForegroundStyleScale(domain: names, range: Array(slots.prefix(max(names.count, 1))))
            .chartLegend(names.count > 1 ? .visible : .hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 190)
        }
        .padding(12)
        .background(AppColors.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
