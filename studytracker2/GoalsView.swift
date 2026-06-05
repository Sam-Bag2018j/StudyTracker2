//
//  GoalsView.swift
//  studytracker2
//

import SwiftUI

struct GoalsView: View {

    // Binding so changes here update ContentView directly
    @Binding var subjectGoals: [String: Int]

    // Unique subject names from all sessions (passed in from ContentView)
    let allSubjects: [String]

    @Environment(\.dismiss) var dismiss

    // Field for adding a brand-new subject goal manually
    @State private var newSubjectName = ""

    // Combines subjects from sessions + subjects that already have goals,
    // sorted alphabetically, with no duplicates
    var subjectsToShow: [String] {
        let fromSessions = Set(allSubjects)
        let fromGoals    = Set(subjectGoals.keys)
        return fromSessions.union(fromGoals).sorted()
    }

    var body: some View {
        NavigationStack {
            List {

                // ── No subjects yet ────────────────────────────
                if subjectsToShow.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "target")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No subjects yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add a study session first, or type a subject name below.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }

                // ── Subject goals list ─────────────────────────
                if !subjectsToShow.isEmpty {
                    Section {
                        ForEach(subjectsToShow, id: \.self) { subject in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject)
                                    .font(.headline)
                                // Stepper for this subject's daily goal
                                Stepper(
                                    "\(subjectGoals[subject] ?? 60) min / day",
                                    value: Binding(
                                        get: { subjectGoals[subject] ?? 60 },
                                        set: { subjectGoals[subject] = $0 }
                                    ),
                                    in: 5...480,
                                    step: 5
                                )
                            }
                            .padding(.vertical, 2)
                        }
                        // Swipe to remove a subject goal
                        .onDelete { indexSet in
                            let subjects = subjectsToShow
                            for i in indexSet {
                                subjectGoals.removeValue(forKey: subjects[i])
                            }
                        }
                    } header: {
                        Text("Daily Goal per Subject")
                    } footer: {
                        Text("Swipe left on a subject to remove its goal. Default is 60 min/day.")
                    }
                }

                // ── Add a new subject goal manually ───────────
                Section {
                    HStack {
                        TextField("Subject name", text: $newSubjectName)
                        Button("Add Goal") {
                            let name = newSubjectName.trimmingCharacters(in: .whitespaces)
                            // Only add if not empty and not already in the list
                            guard !name.isEmpty, subjectGoals[name] == nil else { return }
                            subjectGoals[name] = 60
                            newSubjectName = ""
                        }
                        .disabled(newSubjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Add New Subject")
                } footer: {
                    Text("Set a goal for a subject before you start studying it.")
                }
            }
            .navigationTitle("Subject Goals 🎯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    GoalsView(subjectGoals: .constant(["Math": 60, "History": 90]), allSubjects: ["Math", "History", "Python"])
}
