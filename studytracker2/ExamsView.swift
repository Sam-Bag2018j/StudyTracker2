//
//  ExamsView.swift
//  studytracker2
//
//  Add upcoming exams and see a live countdown (in days) to each one.
//  Exams are persisted to UserDefaults so they survive app restarts.
//

import SwiftUI

// ── Data model ─────────────────────────────────────────────────────────────

struct Exam: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var subject: String
    var date: Date

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var examStart: Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Whole days remaining until the exam (0 = today, negative = past)
    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: todayStart, to: examStart).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }
    var isPast:  Bool { daysUntil  < 0 }
}

// ── Main view ──────────────────────────────────────────────────────────────

struct ExamsView: View {

    @State private var exams: [Exam] = []
    @State private var showingAddExam = false

    var upcomingExams: [Exam] { exams.filter { !$0.isPast }.sorted { $0.date < $1.date } }
    var pastExams:     [Exam] { exams.filter {  $0.isPast }.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            List {

                // ── Empty state ──────────────────────────────────────────
                if exams.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("No exams added")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Tap + to add an upcoming exam and track the countdown.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }

                // ── Upcoming exams ───────────────────────────────────────
                if !upcomingExams.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingExams) { exam in
                            ExamRowView(exam: exam)
                        }
                        .onDelete { indexSet in
                            deleteExams(from: upcomingExams, at: indexSet)
                        }
                    }
                }

                // ── Past exams ───────────────────────────────────────────
                if !pastExams.isEmpty {
                    Section("Past") {
                        ForEach(pastExams) { exam in
                            ExamRowView(exam: exam)
                        }
                        .onDelete { indexSet in
                            deleteExams(from: pastExams, at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Exams ⏰")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExam) {
                AddExamView { newExam in
                    exams.append(newExam)
                    saveExams()
                    NotificationManager.scheduleExamNotifications(for: newExam)
                }
            }
            .onAppear { loadExams() }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private func deleteExams(from list: [Exam], at indexSet: IndexSet) {
        let toDelete    = indexSet.map { list[$0] }
        toDelete.forEach { NotificationManager.cancelExamNotifications(for: $0.id) }
        let idsToDelete = toDelete.map { $0.id }
        exams.removeAll { idsToDelete.contains($0.id) }
        saveExams()
    }

    private func loadExams() {
        guard let data = UserDefaults.standard.data(forKey: "studytracker.exams"),
              let decoded = try? JSONDecoder().decode([Exam].self, from: data)
        else { return }
        exams = decoded
    }

    private func saveExams() {
        guard let data = try? JSONEncoder().encode(exams) else { return }
        UserDefaults.standard.set(data, forKey: "studytracker.exams")
    }
}

// ── Exam row ───────────────────────────────────────────────────────────────

private struct ExamRowView: View {
    let exam: Exam

    var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: exam.date)
    }

    var urgencyColor: Color {
        if exam.isPast             { return .secondary }
        if exam.isToday            { return .red }
        if exam.daysUntil <= 3     { return .red }
        if exam.daysUntil <= 7     { return .orange }
        return .blue
    }

    var body: some View {
        HStack(spacing: 14) {

            // Left: name + subject + date
            VStack(alignment: .leading, spacing: 4) {
                Text(exam.name)
                    .font(.headline)
                if !exam.subject.isEmpty {
                    Text(exam.subject)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: countdown badge
            if exam.isPast {
                Text("Done")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.secondary.opacity(0.15))
                    .cornerRadius(8)
            } else if exam.isToday {
                Text("TODAY")
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red)
                    .cornerRadius(8)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(exam.daysUntil)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(urgencyColor)
                    Text(exam.daysUntil == 1 ? "day left" : "days left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ── Add Exam sheet ─────────────────────────────────────────────────────────

struct AddExamView: View {
    var onSave: (Exam) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name    = ""
    @State private var subject = ""
    @State private var date    = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exam Details") {
                    TextField("Exam name  (e.g. Final Exam)", text: $name)
                    TextField("Subject  (e.g. Math)", text: $subject)
                }
                Section {
                    DatePicker(
                        "Exam Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                }
                Section {
                    let days = Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to:   Calendar.current.startOfDay(for: date)
                    ).day ?? 0

                    if days > 0 {
                        Label("\(days) day\(days == 1 ? "" : "s") from today", systemImage: "clock")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if days == 0 {
                        Label("Exam is today!", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    } else {
                        Label("Date is in the past", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exam = Exam(
                            name:    name.trimmingCharacters(in: .whitespaces),
                            subject: subject.trimmingCharacters(in: .whitespaces),
                            date:    date
                        )
                        onSave(exam)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

#Preview {
    ExamsView()
}
