//
//  HomeworkView.swift
//  studytracker2
//

import SwiftUI

// ── Data model ─────────────────────────────────────────────────────────────

struct Homework: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subject: String
    var dueDate: Date

    private var todayStart: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var dueDateStart: Date {
        Calendar.current.startOfDay(for: dueDate)
    }

    /// Whole days remaining until the homework is due (0 = today, negative = past)
    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: todayStart, to: dueDateStart).day ?? 0
    }

    var isToday: Bool { daysUntil == 0 }
    var isPast:  Bool { daysUntil < 0 }
}

// ── Main view ──────────────────────────────────────────────────────────────

struct HomeworkView: View {

    @State private var homeworkItems: [Homework] = []
    @State private var showingAddHomework = false

    var upcomingHomework: [Homework] {
        homeworkItems.filter { !$0.isPast }.sorted { $0.dueDate < $1.dueDate }
    }

    var pastHomework: [Homework] {
        homeworkItems.filter { $0.isPast }.sorted { $0.dueDate > $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            List {
                if homeworkItems.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("No homework added")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Tap + to add your next assignment and keep track of due dates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }

                if !upcomingHomework.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingHomework) { homework in
                            HomeworkRowView(homework: homework)
                        }
                        .onDelete { indexSet in
                            deleteHomework(from: upcomingHomework, at: indexSet)
                        }
                    }
                }

                if !pastHomework.isEmpty {
                    Section("Past") {
                        ForEach(pastHomework) { homework in
                            HomeworkRowView(homework: homework)
                        }
                        .onDelete { indexSet in
                            deleteHomework(from: pastHomework, at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Homework")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHomework = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHomework) {
                AddHomeworkView { newHomework in
                    homeworkItems.append(newHomework)
                    saveHomework()
                }
            }
            .onAppear { loadHomework() }
        }
    }

    private func deleteHomework(from list: [Homework], at indexSet: IndexSet) {
        let toDelete = indexSet.map { list[$0] }
        let idsToDelete = toDelete.map { $0.id }
        homeworkItems.removeAll { idsToDelete.contains($0.id) }
        saveHomework()
    }

    private func loadHomework() {
        guard
            let data = UserDefaults.standard.data(forKey: "studytracker.homework"),
            let decoded = try? JSONDecoder().decode([Homework].self, from: data)
        else { return }
        homeworkItems = decoded
    }

    private func saveHomework() {
        guard let data = try? JSONEncoder().encode(homeworkItems) else { return }
        UserDefaults.standard.set(data, forKey: "studytracker.homework")
    }
}

// ── Homework row ─────────────────────────────────────────────────────────────

private struct HomeworkRowView: View {
    let homework: Homework

    var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: homework.dueDate)
    }

    var urgencyColor: Color {
        if homework.isPast { return .secondary }
        if homework.isToday { return .red }
        if homework.daysUntil <= 3 { return .red }
        if homework.daysUntil <= 7 { return .orange }
        return .blue
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(homework.name)
                    .font(.headline)
                if !homework.subject.isEmpty {
                    Text(homework.subject)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if homework.isPast {
                Text("Done")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.secondary.opacity(0.15))
                    .cornerRadius(8)
            } else if homework.isToday {
                Text("TODAY")
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.red)
                    .cornerRadius(8)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(homework.daysUntil)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(urgencyColor)
                    Text(homework.daysUntil == 1 ? "day left" : "days left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ── Add Homework sheet ───────────────────────────────────────────────────────

struct AddHomeworkView: View {
    var onSave: (Homework) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var subject = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Homework title (e.g. Read chapter 5)", text: $name)
                    TextField("Subject (e.g. Math)", text: $subject)
                }

                Section {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                }

                Section {
                    let days = Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: dueDate)
                    ).day ?? 0

                    if days > 0 {
                        Label("\(days) day\(days == 1 ? "" : "s") from today", systemImage: "clock")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if days == 0 {
                        Label("Due today", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    } else {
                        Label("Date is in the past", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add Homework")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newHomework = Homework(
                            name: name.trimmingCharacters(in: .whitespaces),
                            subject: subject.trimmingCharacters(in: .whitespaces),
                            dueDate: dueDate
                        )
                        onSave(newHomework)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

#Preview {
    HomeworkView()
}
