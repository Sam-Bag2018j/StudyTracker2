//
//  ChartsView.swift
//  studytracker2
//
//  Weekly and monthly study time bar charts with subject breakdown.
//

import SwiftUI
import Charts

// One data point: a single day's total study minutes
struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

// Subject breakdown data point
struct SubjectData: Identifiable {
    let id = UUID()
    let subject: String
    let minutes: Int
}

struct ChartsView: View {

    let sessions: [StudySession]

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // Max content width on iPad so charts don't stretch edge-to-edge
    var maxContentWidth: CGFloat { horizontalSizeClass == .regular ? 700 : .infinity }

    enum ChartPeriod: String, CaseIterable {
        case weekly  = "7 Days"
        case monthly = "30 Days"
    }

    @State private var selectedPeriod: ChartPeriod = .weekly
    @EnvironmentObject var gradeStore: GradeStore

    // ── Computed data ──────────────────────────────────────────────────────

    var chartData: [DayData] {
        let calendar = Calendar.current
        let dayCount = selectedPeriod == .weekly ? 7 : 30
        return (0..<dayCount).reversed().map { daysAgo in
            let date     = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            let minutes  = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
                .reduce(0) { $0 + $1.minutes }
            return DayData(date: dayStart, minutes: minutes)
        }
    }

    var subjectData: [SubjectData] {
        let calendar  = Calendar.current
        let dayCount  = selectedPeriod == .weekly ? 7 : 30
        let cutoff    = calendar.date(byAdding: .day, value: -dayCount, to: Date())!
        let inPeriod  = sessions.filter { $0.date >= cutoff }
        let subjects  = Array(Set(inPeriod.map { $0.subject })).sorted()
        return subjects.map { subject in
            let total = inPeriod.filter { $0.subject == subject }.reduce(0) { $0 + $1.minutes }
            return SubjectData(subject: subject, minutes: total)
        }.sorted { $0.minutes > $1.minutes }
    }

    var totalMinutes: Int  { chartData.reduce(0) { $0 + $1.minutes } }
    var daysActive:   Int  { chartData.filter { $0.minutes > 0 }.count }
    var avgMinutes:   Int  { daysActive == 0 ? 0 : totalMinutes / daysActive }
    var bestDay:      Int  { chartData.map { $0.minutes }.max() ?? 0 }

    var gradeAvgData: [GradeAvgData] {
        gradeStore.allSubjects
            .map { GradeAvgData(subject: $0, average: gradeStore.averagePercentage(for: $0)) }
            .sorted { $0.average > $1.average }
    }

    // Colour palette for subjects (cycles through if > 8 subjects)
    let palette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .red, .yellow]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Period picker ────────────────────────────────────
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ChartPeriod.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // ── Summary stats row ────────────────────────────────
                    HStack(spacing: 0) {
                        SummaryTile(title: "Total",     value: formatMinutes(totalMinutes))
                        Divider().frame(height: 40)
                        SummaryTile(title: "Daily Avg", value: formatMinutes(avgMinutes))
                        Divider().frame(height: 40)
                        SummaryTile(title: "Best Day",  value: formatMinutes(bestDay))
                        Divider().frame(height: 40)
                        SummaryTile(title: "Days Active", value: "\(daysActive)")
                    }
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // ── Study time bar chart ─────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Study Time")
                            .font(.headline)
                            .padding(.horizontal)

                        if totalMinutes == 0 {
                            noDataView("No sessions in this period.\nLog a session to see your chart!")
                                .frame(height: 220)
                                .padding(.horizontal)
                        } else {
                            Chart(chartData) { day in
                                BarMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Minutes", day.minutes)
                                )
                                .foregroundStyle(Color.blue.gradient)
                                .cornerRadius(3)
                            }
                            .chartXAxis {
                                let stride = selectedPeriod == .weekly ? 1 : 5
                                AxisMarks(
                                    values: .stride(by: .day, count: stride)
                                ) { _ in
                                    AxisValueLabel(
                                        format: selectedPeriod == .weekly
                                            ? .dateTime.weekday(.abbreviated)
                                            : .dateTime.day()
                                    )
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel {
                                        if let mins = value.as(Int.self) {
                                            Text(formatMinutes(mins))
                                                .font(.caption2)
                                        }
                                    }
                                    AxisGridLine()
                                }
                            }
                            .frame(height: 220)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // ── Subject breakdown ────────────────────────────────
                    if !subjectData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Subject")
                                .font(.headline)
                                .padding(.horizontal)

                            Chart(subjectData) { item in
                                BarMark(
                                    x: .value("Minutes", item.minutes),
                                    y: .value("Subject", item.subject)
                                )
                                .foregroundStyle(palette[(subjectData.firstIndex(where: { $0.subject == item.subject }) ?? 0) % palette.count].gradient)
                                .cornerRadius(4)
                                .annotation(position: .trailing) {
                                    Text(formatMinutes(item.minutes))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(height: max(60, CGFloat(subjectData.count) * 44))
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                        .padding(.horizontal)
                    }

                    // ── Grade analysis ───────────────────────────────────
                    if !gradeStore.grades.isEmpty {
                        GradeAnalysisSectionView(
                            gradeData:    gradeAvgData,
                            subjectData:  subjectData,
                            periodLabel:  selectedPeriod.rawValue,
                            formatMins:   formatMinutes
                        )
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 12)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)  // centres on iPad
            }
            .navigationTitle("Charts")
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    @ViewBuilder
    func noDataView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    func formatMinutes(_ total: Int) -> String {
        let h = total / 60
        let m = total % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// Small tile used in the summary row
private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ── Grade average data point ───────────────────────────────────────────────

struct GradeAvgData: Identifiable {
    let id      = UUID()
    let subject: String
    let average: Double   // 0 – 100
}

// ── Grade analysis section ─────────────────────────────────────────────────

private struct GradeAnalysisSectionView: View {

    let gradeData:   [GradeAvgData]
    let subjectData: [SubjectData]    // study-time per subject (from charts)
    let periodLabel: String
    let formatMins:  (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                Text("Grade Analysis")
                    .font(.headline)
                Spacer()
                Text(periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Horizontal bar chart — one bar per subject
            Chart(gradeData) { item in
                BarMark(
                    x: .value("Average %", item.average),
                    y: .value("Subject",   item.subject)
                )
                .foregroundStyle(gradeBarColor(item.average).gradient)
                .cornerRadius(4)
                .annotation(position: .trailing) {
                    Text(String(format: "%.0f%%", item.average))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                    AxisValueLabel {
                        if let n = v.as(Double.self) {
                            Text("\(Int(n))%").font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .frame(height: max(60, CGFloat(gradeData.count) * 46))
            .padding(.horizontal)

            // Recommendation cards — one per subject
            VStack(spacing: 8) {
                ForEach(gradeData) { item in
                    let studyMins = subjectData.first(where: { $0.subject == item.subject })?.minutes ?? 0
                    GradeRecommendationCard(
                        subject:     item.subject,
                        average:     item.average,
                        studyMins:   studyMins,
                        periodLabel: periodLabel,
                        formatMins:  formatMins
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private func gradeBarColor(_ pct: Double) -> Color {
        switch pct {
        case 80...:   return .green
        case 70..<80: return .blue
        case 60..<70: return .orange
        default:      return .red
        }
    }
}

// ── Grade recommendation card ──────────────────────────────────────────────

private struct GradeRecommendationCard: View {

    let subject:     String
    let average:     Double
    let studyMins:   Int
    let periodLabel: String
    let formatMins:  (Int) -> String

    private var rec: (icon: String, message: String, color: Color) {
        let studyHigh = studyMins >= 120     // 2+ hours in the period

        switch average {

        case 80...:
            return (
                "star.circle.fill",
                "\(subject): Excellent (\(fmt())). Outstanding performance — keep it up!",
                .green
            )

        case 70..<80:
            return (
                "checkmark.circle.fill",
                "\(subject): Good (\(fmt())). A little more consistent practice could push you into the A range.",
                .blue
            )

        case 60..<70:
            if studyHigh {
                return (
                    "info.circle.fill",
                    "\(subject): Passing but below average (\(fmt())). You're putting in time — try active recall, past papers, or study groups.",
                    .orange
                )
            } else {
                return (
                    "info.circle.fill",
                    "\(subject): Needs work (\(fmt())). Increase your weekly study time and review key concepts regularly.",
                    .orange
                )
            }

        case 50..<60:
            if studyHigh {
                return (
                    "exclamationmark.circle.fill",
                    "\(subject): Below passing (\(fmt())). Despite \(formatMins(studyMins)) of study this \(periodLabel.lowercased()), results are low — consider a different study strategy or seek help.",
                    .red
                )
            } else {
                return (
                    "exclamationmark.circle.fill",
                    "\(subject): Below passing (\(fmt())). Dedicate at least 1–2 hours more per week and review foundational topics.",
                    .red
                )
            }

        default: // < 50
            if studyHigh {
                return (
                    "exclamationmark.triangle.fill",
                    "\(subject): Critical grade (\(fmt())). Despite studying \(formatMins(studyMins)), the results are very low. Seek a tutor or teacher support as soon as possible.",
                    .red
                )
            } else {
                return (
                    "exclamationmark.triangle.fill",
                    "\(subject): Critical grade (\(fmt())). You're barely studying this subject. Prioritise it immediately and get extra help.",
                    .red
                )
            }
        }
    }

    private func fmt() -> String { String(format: "%.0f%%", average) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.icon)
                .foregroundStyle(rec.color)
                .font(.subheadline)
                .frame(width: 20)
            Text(rec.message)
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rec.color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ChartsView(sessions: [])
        .environmentObject(GradeStore())
}
