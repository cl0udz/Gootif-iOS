import SwiftUI

// MARK: - Diagram
//
// A paper's core figure (attack path, system overview, defense pipeline). The
// agent chooses the rows, so layout stays predictable at any width: each row is
// an HStack of equal-width cards, read top to bottom. Arrows, edge labels and
// dashed trust zones are then drawn in one Canvas from the measured card
// frames. Edges that skip rows or loop back up run along the side gutters.

struct DiagramView: View {
    let block: DiagramBlock

    @ScaledMetric(relativeTo: .caption2) private var labeledRowGap = 36.0
    @ScaledMetric(relativeTo: .caption2) private var plainRowGap = 24.0
    @ScaledMetric(relativeTo: .caption2) private var zoneGap = 14.0

    /// Room on both sides for gutter-routed edges.
    private let gutter: CGFloat = 18

    private var rowOf: [String: Int] {
        var map: [String: Int] = [:]
        for (r, row) in block.rows.enumerated() { for node in row { map[node.id] = r } }
        return map
    }

    private var rowGap: CGFloat {
        let rows = rowOf
        let labeled = block.edges.contains { edge in
            edge.label?.isEmpty == false && rows[edge.from] != rows[edge.to]
        }
        return labeled ? labeledRowGap : plainRowGap
    }

    private var zones: [DiagramBlock.Zone] { block.zones ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BlockTitle(title: block.title, unit: nil)

            graph

            legend

            if let caption = block.caption, !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(AppColors.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var graph: some View {
        let rows = rowOf
        return VStack(spacing: rowGap) {
            ForEach(Array(block.rows.enumerated()), id: \.offset) { r, row in
                let sideEdges = block.edges.contains { rows[$0.from] == r && rows[$0.to] == r }
                HStack(alignment: .top, spacing: sideEdges ? 22 : 10) {
                    ForEach(row) { node in
                        DiagramNodeCard(node: node)
                            .frame(maxWidth: row.count == 1 ? 240 : .infinity)
                            .anchorPreference(key: DiagramNodeBounds.self, value: .bounds) { [node.id: $0] }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                // Zone borders sit in the gaps; widen those gaps so edge labels clear them.
                .padding(.top, zones.contains { $0.fromRow == r && r > 0 } ? zoneGap : 0)
                .padding(.bottom, zones.contains { $0.toRow == r && r < block.rows.count - 1 } ? zoneGap : 0)
            }
        }
        .padding(.horizontal, gutter)
        .padding(.vertical, zones.isEmpty ? 2 : 14)
        .overlayPreferenceValue(DiagramNodeBounds.self) { anchors in
            GeometryReader { proxy in
                let frames = anchors.mapValues { proxy[$0] }
                Canvas { context, size in
                    DiagramPainter(block: block, frames: frames, rowOf: rows, size: size,
                                   gutter: gutter).draw(in: &context)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var legend: some View {
        let styles = Set(block.edges.compactMap(\.style))
        let entries = DiagramStyle.legendOrder.filter(styles.contains)
        if !entries.isEmpty {
            FlowLayout(spacing: 12) {
                ForEach(entries, id: \.self) { style in
                    HStack(spacing: 5) {
                        LegendStroke(style: style)
                            .frame(width: 22, height: 8)
                        Text(DiagramStyle.legendTitle(style))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var accessibilityDescription: String {
        let names = Dictionary(block.rows.flatMap { $0 }.map { ($0.id, $0.label) }) { first, _ in first }
        let steps = block.edges.map { edge in
            let arrow = "\(names[edge.from] ?? edge.from) → \(names[edge.to] ?? edge.to)"
            return edge.label.map { "\(arrow) (\($0))" } ?? arrow
        }
        return ([block.title ?? "Diagram"] + steps).joined(separator: "; ")
    }
}

// MARK: - Node

private struct DiagramNodeCard: View {
    let node: DiagramBlock.Node

    var body: some View {
        let color = DiagramStyle.color(role: node.role)
        VStack(spacing: 3) {
            (Text(Image(systemName: DiagramStyle.symbol(role: node.role))).foregroundStyle(color)
                + Text(" ") + Text(node.label))
                .font(.footnote.weight(.semibold))
            if let detail = node.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct LegendStroke: View {
    let style: String

    var body: some View {
        Canvas { context, size in
            var line = Path()
            line.move(to: CGPoint(x: 0, y: size.height / 2))
            line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(line, with: .color(DiagramStyle.color(edge: style)),
                           style: DiagramStyle.stroke(edge: style))
        }
    }
}

private struct DiagramNodeBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Style

enum DiagramStyle {
    static let legendOrder = ["attack", "blocked", "feedback"]

    static func color(role: String?) -> Color {
        switch role {
        case "attacker": return AppColors.negative
        case "user": return Color.teal
        case "model": return Color.purple
        case "system": return AppColors.info
        case "tool": return AppColors.warning
        case "defense": return AppColors.positive
        case "impact": return Color.pink
        case "result": return AppColors.accentSecondary
        default: return Color.secondary
        }
    }

    static func symbol(role: String?) -> String {
        switch role {
        case "attacker": return "exclamationmark.triangle.fill"
        case "user": return "person.fill"
        case "data": return "doc.text.fill"
        case "model": return "brain"
        case "system": return "gearshape.2.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        case "defense": return "shield.lefthalf.filled"
        case "impact": return "flame.fill"
        case "result": return "checkmark.seal.fill"
        default: return "circle.fill"
        }
    }

    static func color(edge style: String?) -> Color {
        switch style {
        case "attack": return AppColors.negative
        case "blocked": return AppColors.positive
        default: return Color.primary.opacity(0.42)
        }
    }

    static func stroke(edge style: String?) -> StrokeStyle {
        switch style {
        case "attack": return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        case "blocked": return StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 3])
        case "feedback": return StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [3, 3])
        default: return StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
        }
    }

    static func legendTitle(_ style: String) -> LocalizedStringKey {
        switch style {
        case "attack": return "Attack path"
        case "blocked": return "Blocked"
        default: return "Feedback"
        }
    }

    static func color(zone kind: String?) -> Color {
        switch kind {
        case "untrusted": return AppColors.negative
        case "trusted": return AppColors.info
        default: return Color.secondary
        }
    }
}

// MARK: - Painter

/// Draws zones, edges and edge labels from measured card frames.
private struct DiagramPainter {
    let block: DiagramBlock
    let frames: [String: CGRect]
    let rowOf: [String: Int]
    let size: CGSize
    let gutter: CGFloat

    private struct Route {
        var path = Path()
        var end: CGPoint
        var direction: CGVector  // unit direction of travel at `end`
        var labelAnchor: CGPoint?
    }

    /// Vertical extent of each row, from its cards.
    private var rowSpans: [ClosedRange<CGFloat>] {
        block.rows.map { row in
            let rects = row.compactMap { frames[$0.id] }
            guard let top = rects.map(\.minY).min(), let bottom = rects.map(\.maxY).max() else { return 0...0 }
            return top...bottom
        }
    }

    func draw(in context: inout GraphicsContext) {
        let spans = rowSpans
        var obstacles = Array(frames.values.map { $0.insetBy(dx: -2, dy: -2) })
        drawZones(in: &context, spans: spans, obstacles: &obstacles)

        let routes = block.edges.map { route(for: $0, spans: spans) }
        for (edge, route) in zip(block.edges, routes) {
            guard let route else { continue }
            let color = DiagramStyle.color(edge: edge.style)
            context.stroke(route.path, with: .color(color), style: DiagramStyle.stroke(edge: edge.style))
            drawHead(in: &context, route: route, color: color, blocked: edge.style == "blocked")
        }
        for (edge, route) in zip(block.edges, routes) {
            guard let route, let anchor = route.labelAnchor, let label = edge.label, !label.isEmpty else { continue }
            drawLabel(label, near: anchor, color: DiagramStyle.color(edge: edge.style),
                      in: &context, obstacles: &obstacles)
        }
    }

    // MARK: Zones

    private func drawZones(in context: inout GraphicsContext, spans: [ClosedRange<CGFloat>],
                           obstacles: inout [CGRect]) {
        for zone in block.zones ?? [] {
            guard spans.indices.contains(zone.fromRow), spans.indices.contains(zone.toRow),
                  zone.fromRow <= zone.toRow else { continue }
            let rect = CGRect(x: 3, y: spans[zone.fromRow].lowerBound - 9,
                              width: size.width - 6,
                              height: spans[zone.toRow].upperBound - spans[zone.fromRow].lowerBound + 18)
            let color = DiagramStyle.color(zone: zone.kind)
            context.stroke(Path(roundedRect: rect, cornerRadius: 10),
                           with: .color(color.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))

            // Fieldset-style legend sitting on the top border.
            let text = context.resolve(Text(zone.label).font(.caption2.weight(.semibold)).foregroundStyle(color))
            let textSize = text.measure(in: CGSize(width: rect.width - 24, height: 40))
            let labelRect = CGRect(x: rect.minX + 10, y: rect.minY - textSize.height / 2,
                                   width: textSize.width + 8, height: textSize.height)
            var cleared = context
            cleared.blendMode = .clear
            cleared.fill(Path(labelRect), with: .color(.black))
            context.draw(text, at: CGPoint(x: labelRect.midX, y: labelRect.midY))
            obstacles.append(labelRect)
        }
    }

    // MARK: Routing

    private func route(for edge: DiagramBlock.Edge, spans: [ClosedRange<CGFloat>]) -> Route? {
        guard let s = frames[edge.from], let t = frames[edge.to],
              let rs = rowOf[edge.from], let rt = rowOf[edge.to] else { return nil }

        if rs == rt {
            // Neighbours in one row: a short horizontal arrow between the cards.
            let forward = s.midX < t.midX
            let start = CGPoint(x: forward ? s.maxX : s.minX, y: s.midY)
            let end = CGPoint(x: forward ? t.minX : t.maxX, y: t.midY)
            var route = Route(end: end, direction: CGVector(dx: forward ? 1 : -1, dy: 0))
            route.path.move(to: start)
            route.path.addLine(to: end)
            return route
        }

        if rt > rs {
            let start = CGPoint(x: port(for: edge, outgoing: true), y: s.maxY)
            let end = CGPoint(x: port(for: edge, outgoing: false), y: t.minY)
            if rt == rs + 1 || !crossesCards(from: start, to: end, between: rs, and: rt) {
                var route = Route(end: end, direction: CGVector(dx: 0, dy: 1))
                let bend = (end.y - start.y) / 2
                route.path.move(to: start)
                route.path.addCurve(to: end, control1: CGPoint(x: start.x, y: start.y + bend),
                                    control2: CGPoint(x: end.x, y: end.y - bend))
                route.labelAnchor = rt == rs + 1
                    ? CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    : CGPoint(x: (start.x + end.x) / 2, y: gapCenter(between: rs, and: rt, spans: spans))
                return route
            }
        }

        // Skip edges that would cross cards, and loops back up, use a gutter.
        let left = rt > rs && (s.midX + t.midX) / 2 < size.width / 2
        let lane = CGFloat(gutterLane(for: edge, left: left))
        let x = left ? gutter / 2 - lane * 4 : size.width - gutter / 2 + lane * 4
        let start = CGPoint(x: left ? s.minX : s.maxX, y: s.midY)
        let end = CGPoint(x: left ? t.minX : t.maxX, y: t.midY)
        let radius = min(8, abs(end.y - start.y) / 2)
        let vertical: CGFloat = end.y > start.y ? 1 : -1
        let inward: CGFloat = left ? 1 : -1
        var route = Route(end: end, direction: CGVector(dx: inward, dy: 0))
        route.path.move(to: start)
        route.path.addLine(to: CGPoint(x: x + inward * radius, y: start.y))
        route.path.addQuadCurve(to: CGPoint(x: x, y: start.y + vertical * radius),
                                control: CGPoint(x: x, y: start.y))
        route.path.addLine(to: CGPoint(x: x, y: end.y - vertical * radius))
        route.path.addQuadCurve(to: CGPoint(x: x + inward * radius, y: end.y),
                                control: CGPoint(x: x, y: end.y))
        route.path.addLine(to: end)
        route.labelAnchor = CGPoint(x: x, y: gapCenter(between: min(rs, rt), and: max(rs, rt), spans: spans))
        return route
    }

    /// Spreads several downward edges leaving (or entering) one card across
    /// its bottom (or top), ordered by the far end so the arrows don't cross.
    private func port(for edge: DiagramBlock.Edge, outgoing: Bool) -> CGFloat {
        let id = outgoing ? edge.from : edge.to
        guard let rect = frames[id] else { return 0 }
        let siblings = block.edges.filter { other in
            guard let a = rowOf[other.from], let b = rowOf[other.to], b > a else { return false }
            return outgoing ? other.from == id : other.to == id
        }.sorted { a, b in
            let far = { (e: DiagramBlock.Edge) in self.frames[outgoing ? e.to : e.from]?.midX ?? 0 }
            return far(a) < far(b)
        }
        guard siblings.count > 1,
              let index = siblings.firstIndex(where: { $0.from == edge.from && $0.to == edge.to }) else {
            return rect.midX
        }
        let spacing = min(16, rect.width * 0.6 / CGFloat(siblings.count - 1))
        return rect.midX + (CGFloat(index) - CGFloat(siblings.count - 1) / 2) * spacing
    }

    private func crossesCards(from start: CGPoint, to end: CGPoint, between rs: Int, and rt: Int) -> Bool {
        let blockers = block.rows[(rs + 1)..<rt].flatMap { $0 }.compactMap { frames[$0.id]?.insetBy(dx: -4, dy: -4) }
        let bend = (end.y - start.y) / 2
        return (1..<24).contains { i in
            let t = CGFloat(i) / 24, u = 1 - t
            let p = CGPoint(
                x: u * u * u * start.x + 3 * u * u * t * start.x + 3 * u * t * t * end.x + t * t * t * end.x,
                y: u * u * u * start.y + 3 * u * u * t * (start.y + bend) + 3 * u * t * t * (end.y - bend) + t * t * t * end.y)
            return blockers.contains { $0.contains(p) }
        }
    }

    private func gutterLane(for edge: DiagramBlock.Edge, left: Bool) -> Int {
        var lane = 0
        for other in block.edges {
            if other.from == edge.from && other.to == edge.to { break }
            guard let a = rowOf[other.from], let b = rowOf[other.to], a != b,
                  let s = frames[other.from], let t = frames[other.to] else { continue }
            let skips = b > a + 1 || b < a
            let otherLeft = b > a && (s.midX + t.midX) / 2 < size.width / 2
            if skips && otherLeft == left { lane += 1 }
        }
        return min(lane, 2)
    }

    private func gapCenter(between a: Int, and b: Int, spans: [ClosedRange<CGFloat>]) -> CGFloat {
        let k = max(a, (a + b - 1) / 2)
        guard spans.indices.contains(k + 1) else { return spans[a].upperBound }
        return (spans[k].upperBound + spans[k + 1].lowerBound) / 2
    }

    // MARK: Marks

    private func drawHead(in context: inout GraphicsContext, route: Route, color: Color, blocked: Bool) {
        let d = route.direction, n = CGVector(dx: -d.dy, dy: d.dx), tip = route.end
        var head = Path()
        if blocked {
            // A stop bar: the defense ends this path.
            head.move(to: CGPoint(x: tip.x - d.dx * 2 + n.dx * 6, y: tip.y - d.dy * 2 + n.dy * 6))
            head.addLine(to: CGPoint(x: tip.x - d.dx * 2 - n.dx * 6, y: tip.y - d.dy * 2 - n.dy * 6))
            context.stroke(head, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        } else {
            head.move(to: tip)
            head.addLine(to: CGPoint(x: tip.x - d.dx * 7 + n.dx * 4, y: tip.y - d.dy * 7 + n.dy * 4))
            head.addLine(to: CGPoint(x: tip.x - d.dx * 7 - n.dx * 4, y: tip.y - d.dy * 7 - n.dy * 4))
            head.closeSubpath()
            context.fill(head, with: .color(color))
        }
    }

    private func drawLabel(_ label: String, near anchor: CGPoint, color: Color,
                           in context: inout GraphicsContext, obstacles: inout [CGRect]) {
        let text = context.resolve(Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary))
        let textSize = text.measure(in: CGSize(width: size.width / 2, height: 60))
        let box = CGSize(width: textSize.width + 10, height: textSize.height + 4)
        let candidates: [CGFloat] = [0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]
        let rects = candidates.map { shift in
            var rect = CGRect(x: anchor.x - box.width / 2 + shift * box.width, y: anchor.y - box.height / 2,
                              width: box.width, height: box.height)
            rect.origin.x = min(max(rect.minX, 0), max(size.width - rect.width, 0))
            return rect
        }
        let rect = rects.first { candidate in !obstacles.contains { $0.intersects(candidate) } } ?? rects[0]
        obstacles.append(rect)
        let pill = Path(roundedRect: rect, cornerRadius: rect.height / 2)
        context.fill(pill, with: .color(AppColors.cardBackground))
        context.stroke(pill, with: .color(color.opacity(0.35)), lineWidth: 0.8)
        context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
    }
}
