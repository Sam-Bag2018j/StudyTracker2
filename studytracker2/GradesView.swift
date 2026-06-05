//
//  GradesView.swift
//  studytracker2
//
//  Grade/mark input, per-subject averages, and letter-grade display.
//  GradeStore is an ObservableObject injected as an @EnvironmentObject
//  so both GradesView and ChartsView share the same data.
//

import SwiftUI

// ── Grade model ────────────────────────────────────────────────────────────

struct Grade: Identifiable, Codable {
    var id:       UUID   = UUID()
    var subject:  String
    var testName: String              // optional — e.g. "Midterm Exam"
    var score:    Double              // marks earned
    var maxScore: Double              // total marks possible
    var date:     Date

    var percentage: Double {
        guard maxScore > 0 else { return 0 }
        return (score / maxScore) * 100
    }

    var letterGrade: String {
        switch percentage {
        case 90...:   return "A+"
        case 85..<90: return "A"
        case 80..<85: return "A-"
        case 75..<80: return "B+"
        case 70..<75: return "B"
        case 65..<70: return "B-"
        case 60..<65: return "C+"
        case 55..<60: return "C"
        case 50..<55: return "D"
        default:      return "F"
        }
    }

    var gradeColor: Color {
        switch percentage {
        case 80...:   return .green
        case 70..<80: return .blue
        case 60..<70: return .orange
        case 50..<60: return .red
        default:      return .red
        }
    }
}

// ── Grade Store ────────────────────────────────────────────────────────────

final class GradeStore: ObservableObject {

    @Published var grades: [Grade] = []

    init() { load() }

    var allSubjects: [String] {
        Array(Set(grades.map { $0.subject })).sorted()
    }

    func add(_ grade: Grade) {
        grades.append(grade)
        save()
    }

    func delete(at offsets: IndexSet, from list: [Grade]) {
        let idsToDelete = offsets.map { list[$0].id }
        grades.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    /// Returns the average percentage across all grades for `subject`.
    func averagePercentage(for subject: String) -> Double {
        let s = grades.filter { $0.subject == subject }
        guard !s.isEmpty else { return 0 }
        return s.reduce(0) { $0 + $1.percentage } / Double(s.count)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(grades) else { return }
        UserDefaults.standard.set(data, forKey: "studytracker.grades")
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: "studytracker.grades"),
            let decoded = try? JSONDecoder().decode([Grade].self, from: data)
        else { return }
        grades = decoded
    }
}

// ── Grades View ────────────────────────────────────────────────────────────

struct GradesView: View {

    @EnvironmentObject var gradeStore: GradeStore

    @State private var showingAddGrade   = false
    @State private var selectedSubject: String? = nil

    var filteredGrades: [Grade] {
        let sorted = gradeStore.grades.sorted { $0.date > $1.date }
        if let s = selectedSubject { return sorted.filter { $0.subject == s } }
        return sorted
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Empty state ──────────────────────────────────────────
                if gradeStore.grades.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "graduationcap")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("No grades yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Tap + to record a test or exam grade.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }

                // ── Subject filter chips ─────────────────────────────────
                if gradeStore.allSubjects.count > 1 {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "All", isSelected: selectedSubject == nil) {
                                    selectedSubject = nil
                                }
                                ForEach(gradeStore.allSubjects, id: \.self) { subject in
                                    FilterChip(
                                        label: subject,
                                        isSelected: selectedSubject == subject
                                    ) {
                                        selectedSubject = selectedSubject == subject ? nil : subject
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // ── Subject averages ─────────────────────────────────────
                if !gradeStore.allSubjects.isEmpty {
                    Section("Subject Averages") {
                        ForEach(gradeStore.allSubjects, id: \.self) { subject in
                            SubjectAverageRow(
                                subject:  subject,
                                average:  gradeStore.averagePercentage(for: subject),
                                count:    gradeStore.grades.filter { $0.subject == subject }.count
                            )
                        }
                    }
                }

                // ── Individual grade entries ─────────────────────────────
                if !filteredGrades.isEmpty {
                    Section(selectedSubject.map { "Grades – \($0)" } ?? "All Grades") {
                        ForEach(filteredGrades) { grade in
                            GradeRowView(grade: grade)
                        }
                        .onDelete { offsets in
                            gradeStore.delete(at: offsets, from: filteredGrades)
                        }
                    }
                }
            }
            .navigationTitle("Grades 📝")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddGrade = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGrade) {
                AddGradeView { grade in gradeStore.add(grade) }
            }
        }
    }
}

// ── Subject average row ────────────────────────────────────────────────────

private struct SubjectAverageRow: View {
    let subject: String
    let average: Double
    let count:   Int

    var statusLabel: String {
        switch average {
        case 80...:   return "Excellent"
        case 70..<80: return "Good"
        case 60..<70: return "Needs Work"
        case 50..<60: return "Struggling"
        default:      return "Critical"
        }
    }

    var statusColor: Color {
        switch average {
        case 80...:   return .green
        case 70..<80: return .blue
        case 60..<70: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subject).font(.headline)
                Spacer()
                Text(statusLabel)
                    .font(.caption).bold()
                    .foregroundStyle(statusColor)
                Text(String(format: "%.1f%%", average))
                    .font(.subheadline).bold()
                    .foregroundStyle(statusColor)
            }
            ProgressView(value: min(average, 100), total: 100)
                .tint(statusColor)
            Text("\(count) grade\(count == 1 ? "" : "s") recorded")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// ── Grade row ──────────────────────────────────────────────────────────────

private struct GradeRowView: View {
    let grade: Grade

    var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: grade.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Letter-grade badge
            Text(grade.letterGrade)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(grade.gradeColor)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                Text(grade.testName.isEmpty ? grade.subject : grade.testName)
                    .font(.headline)
                if !grade.testName.isEmpty {
                    Text(grade.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f / %.0f", grade.score, grade.maxScore))
                    .font(.subheadline).bold()
                Text(String(format: "%.1f%%", grade.percentage))
                    .font(.caption)
                    .foregroundStyle(grade.gradeColor)
            }
        }
        .padding(.vertical, 2)
    }
}

// ── Filter chip ────────────────────────────────────────────────────────────

private struct FilterChip: View {
    let label:      String
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption).bold()
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// ── Add Grade sheet ────────────────────────────────────────────────────────

struct AddGradeView: View {

    var onSave: (Grade) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var subject  = ""
    @State private var testName = ""
    @State private var scoreText    = ""
    @State private var maxScoreText = "100"
    @State private var date     = Date()

    private var scoreVal:    Double { Double(scoreText)    ?? 0 }
    private var maxScoreVal: Double { Double(maxScoreText) ?? 100 }

    private var percentage: Double {
        guard maxScoreVal > 0, Double(scoreText) != nil else { return 0 }
        return (scoreVal / maxScoreVal) * 100
    }

    private var letterGrade: String {
        switch percentage {
        case 90...:   return "A+"
        case 85..<90: return "A"
        case 80..<85: return "A-"
        case 75..<80: return "B+"
        case 70..<75: return "B"
        case 65..<70: return "B-"
        case 60..<65: return "C+"
        case 55..<60: return "C"
        case 50..<55: return "D"
        default:      return "F"
        }
    }

    private var previewColor: Color {
        switch percentage {
        case 80...:   return .green
        case 70..<80: return .blue
        case 60..<70: return .orange
        default:      return .red
        }
    }

    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(scoreText) != nil &&
        maxScoreVal > 0 &&
        scoreVal <= maxScoreVal
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Subject & Test") {
                    TextField("Subject  (e.g. Math)", text: $subject)
                    TextField("Test / Exam name (optional)", text: $testName)
                }

                Section("Score") {
                    HStack {
                        TextField("Your score", text: $scoreText)
                            .keyboardType(.decimalPad)
                        Text("/")
                            .foregroundStyle(.secondary)
                        TextField("Out of", text: $maxScoreText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                // Live grade preview
                if !scoreText.isEmpty, Double(scoreText) != nil {
                    if scoreVal > maxScoreVal {
                        Section {
                            Label("Score cannot exceed the maximum.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    } else {
                        Section("Grade Preview") {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%.1f%%", percentage))
                                        .font(.title2).bold()
                                        .foregroundStyle(previewColor)
                                    Text(String(format: "%.0f out of %.0f", scoreVal, maxScoreVal))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(letterGrade)
                                    .font(.title2).bold()
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 40)
                                    .background(previewColor)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Grade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Grade(
                            subject:  subject.trimmingCharacters(in: .whitespaces),
                            testName: testName.trimmingCharacters(in: .whitespaces),
                            score:    scoreVal,
                            maxScore: maxScoreVal,
                            date:     date
                        ))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview {
    GradesView()
        .environmentObject(GradeStore())
}
