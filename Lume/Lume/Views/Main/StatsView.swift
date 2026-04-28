import SwiftUI
import Charts
import GRDB

struct StatsView: View {
    @LumeAccent private var accent
    let environment: AppEnvironment
    @State private var totals: Totals = .empty
    @State private var byDay: [DayBucket] = []

    struct Totals {
        var total: Int
        var byKind: [(ClipKind, Int)]
        var bySource: [(String, Int)]
        var pinned: Int
        var encrypted: Int
        var bytes: Int
        static let empty = Totals(total: 0, byKind: [], bySource: [], pinned: 0, encrypted: 0, bytes: 0)
    }

    struct DayBucket: Identifiable, Hashable {
        var date: Date
        var count: Int
        var id: Date { date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                Text("Stats").font(.title2.weight(.semibold))

                statTiles

                if !byDay.isEmpty {
                    sectionHeader("Captures per day", subtitle: "Last 30 days")
                    Chart(byDay) { bucket in
                        BarMark(
                            x: .value("Day", bucket.date, unit: .day),
                            y: .value("Clips", bucket.count)
                        )
                        .foregroundStyle(accent)
                        .cornerRadius(2)
                    }
                    .frame(height: 180)
                    .chartYAxis { AxisMarks(position: .leading) }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    }
                }

                if !totals.byKind.isEmpty {
                    sectionHeader("By type", subtitle: nil)
                    ForEach(totals.byKind, id: \.0) { (kind, n) in
                        bar(label: kind.displayName, value: n, max: totals.total)
                    }
                }

                if !totals.bySource.isEmpty {
                    sectionHeader("Top sources", subtitle: nil)
                    ForEach(totals.bySource.prefix(8), id: \.0) { (source, n) in
                        HStack(spacing: 8) {
                            AppIconView(bundleID: source, size: 16)
                            bar(label: appLabel(source), value: n, max: totals.total)
                        }
                    }
                }
            }
            .padding(Tokens.Spacing.l)
        }
        .navigationTitle("Stats")
        .onAppear(perform: reload)
    }

    private var statTiles: some View {
        HStack(spacing: Tokens.Spacing.m) {
            tile("Total clips", "\(totals.total)")
            tile("Pinned", "\(totals.pinned)")
            tile("Encrypted", "\(totals.encrypted)")
            tile("Storage", ByteCountFormatter.string(fromByteCount: Int64(totals.bytes), countStyle: .file))
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        GlassCard(radius: Tokens.Radius.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.system(.title3, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, Tokens.Spacing.s)
    }

    private func bar(label: String, value: Int, max: Int) -> some View {
        let frac = max == 0 ? 0 : Double(value) / Double(max)
        return HStack {
            Text(label).font(.caption).frame(width: 140, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent)
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 6)
            Text("\(value)").font(.caption.monospacedDigit()).frame(width: 56, alignment: .trailing)
        }
    }

    private func appLabel(_ bundleID: String) -> String {
        bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }

    private func reload() {
        Task.detached {
            let pool = environment.clipRepository.pool
            let result: (Totals, [DayBucket]) = (try? await pool.read { db -> (Totals, [DayBucket]) in
                let total = try Int.fetchOne(db, sql: "SELECT count(*) FROM clip") ?? 0
                let pinned = try Int.fetchOne(db, sql: "SELECT count(*) FROM clip WHERE isPinned = 1") ?? 0
                let encrypted = try Int.fetchOne(db, sql: "SELECT count(*) FROM clip WHERE isEncrypted = 1") ?? 0
                let bytes = try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(byteSize), 0) FROM clip") ?? 0

                let byKindRows = try Row.fetchAll(db, sql: "SELECT kind, count(*) AS n FROM clip GROUP BY kind ORDER BY n DESC")
                let byKind: [(ClipKind, Int)] = byKindRows.compactMap { row in
                    guard let raw: Int = row["kind"], let n: Int = row["n"], let k = ClipKind(rawValue: raw) else { return nil }
                    return (k, n)
                }

                let bySourceRows = try Row.fetchAll(db, sql: "SELECT sourceBundleID AS s, count(*) AS n FROM clip WHERE sourceBundleID IS NOT NULL GROUP BY s ORDER BY n DESC LIMIT 16")
                let bySource: [(String, Int)] = bySourceRows.compactMap { row in
                    guard let s: String = row["s"], let n: Int = row["n"] else { return nil }
                    return (s, n)
                }

                // Per-day for the last 30 days. GRDB stores Date as ISO-8601
                // TEXT, so bucket via SQLite's date(..., 'localtime') and key
                // back into Swift by the same yyyy-MM-dd string.
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let firstDay = cal.date(byAdding: .day, value: -29, to: today) ?? today
                let dayRows = try Row.fetchAll(db, sql: """
                    SELECT date(lastSeenAt, 'localtime') AS day, COUNT(*) AS n
                    FROM clip
                    WHERE lastSeenAt >= ?
                    GROUP BY day
                """, arguments: [firstDay])
                var counts: [String: Int] = [:]
                for row in dayRows {
                    if let day: String = row["day"], let n: Int = row["n"] { counts[day] = n }
                }
                let dayFmt = DateFormatter()
                dayFmt.dateFormat = "yyyy-MM-dd"
                dayFmt.timeZone = .current
                dayFmt.locale = Locale(identifier: "en_US_POSIX")
                var buckets: [DayBucket] = []
                for d in 0..<30 {
                    guard let date = cal.date(byAdding: .day, value: d, to: firstDay) else { continue }
                    let key = dayFmt.string(from: date)
                    buckets.append(DayBucket(date: date, count: counts[key] ?? 0))
                }
                let totals = Totals(total: total, byKind: byKind, bySource: bySource,
                                    pinned: pinned, encrypted: encrypted, bytes: bytes)
                return (totals, buckets)
            }) ?? (.empty, [])
            await MainActor.run {
                totals = result.0
                byDay = result.1
            }
        }
    }
}
