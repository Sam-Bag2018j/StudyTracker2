//
//  NewSessionView.swift
//  studytracker2
//

import SwiftUI

struct NewSessionView: View {

    // Called when the user taps Save — passes the new session back to ContentView
    var onSave: (StudySession) -> Void

    @Environment(\.dismiss) var dismiss

    // Recently used subjects stored in UserDefaults for autocomplete
    @AppStorage("recentSubjects") private var recentSubjectsData: Data = Data()

    // Form fields
    @State private var subject = ""
    @State private var minutes = 30
    @State private var notes   = ""
    @State private var showSubjectSuggestions = false

    // Recent subjects decoded from AppStorage
    var recentSubjects: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSubjectsData)) ?? []
    }

    // Subjects that match what the user has typed so far
    var filteredSubjects: [String] {
        guard !subject.isEmpty else { return recentSubjects }
        return recentSubjects.filter { $0.localizedCaseInsensitiveContains(subject) }
    }

    // ── Timer state ─────────────────────────────────────────────────────────
    // Whether the timer is actively counting
    @State private var isRunning = false
    // How many seconds have passed in total (survives Stop/Resume)
    @State private var elapsedSeconds = 0
    // The Date we "pretend" the timer started, adjusted for already-elapsed time.
    // Storing the start date (instead of just incrementing) means the timer
    // stays accurate even if the app goes to the background.
    @State private var timerStartDate: Date? = nil

    // This publisher fires every second on the main thread
    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Form {

                // ── Subject ────────────────────────────────────
                Section("Subject") {
                    TextField("e.g. Math, History, Python...", text: $subject)
                        .autocorrectionDisabled()
                        .onChange(of: subject) { _, _ in
                            showSubjectSuggestions = !subject.isEmpty
                        }
                    // Autocomplete suggestions
                    if showSubjectSuggestions && !filteredSubjects.isEmpty {
                        ForEach(filteredSubjects.prefix(4), id: \.self) { suggestion in
                            Button {
                                subject = suggestion
                                showSubjectSuggestions = false
                            } label: {
                                Label(suggestion, systemImage: "clock.arrow.circlepath")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                // ── Timer ──────────────────────────────────────
                Section {
                    VStack(spacing: 16) {

                        // Large timer display (MM:SS or H:MM:SS)
                        Text(timerDisplay)
                            .font(.system(size: 58, weight: .thin, design: .monospaced))
                            .foregroundStyle(isRunning ? .blue : .primary)

                        // Start / Stop / Resume button
                        Button(action: toggleTimer) {
                            Label(
                                isRunning ? "Stop" : (elapsedSeconds > 0 ? "Resume" : "Start"),
                                systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill"
                            )
                            .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRunning ? .red : .green)

                        // Reset button — only shown after the timer has been used
                        if elapsedSeconds > 0 && !isRunning {
                            Button("Reset Timer") {
                                elapsedSeconds  = 0
                                timerStartDate  = nil
                                minutes         = 30
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Tap Start when you begin studying. Tap Stop when you're done. The duration below will update automatically.")
                }

                // ── Duration (auto-filled by timer, or set manually) ────────
                Section("Duration") {
                    Stepper("\(minutes) minutes", value: $minutes, in: 1...300, step: 5)
                    Text(durationPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // ── Notes ──────────────────────────────────────
                Section("Notes (Optional)") {
                    TextField("What did you study?", text: $notes)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            // Every second: recalculate elapsed time from the stored start date
            .onReceive(ticker) { _ in
                guard isRunning, let start = timerStartDate else { return }
                elapsedSeconds = Int(Date().timeIntervalSince(start))
                // Keep the minutes stepper in sync (round up, cap at 300)
                let computed = max(1, (elapsedSeconds + 59) / 60)
                minutes = min(computed, 300)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = subject.trimmingCharacters(in: .whitespaces)
                        let session = StudySession(
                            subject: trimmed,
                            minutes: minutes,
                            date: Date(),
                            notes: notes.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(session)
                        saveRecentSubject(trimmed)
                        dismiss()
                    }
                    // Save is disabled until a subject is entered
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // ── Timer logic ─────────────────────────────────────────────────────────

    // Toggles the timer between running and stopped
    func toggleTimer() {
        if isRunning {
            isRunning = false   // pause: keeps elapsedSeconds frozen
        } else {
            // When starting (or resuming), set the "virtual" start date so that
            // already-elapsed seconds are accounted for
            timerStartDate = Date().addingTimeInterval(-TimeInterval(elapsedSeconds))
            isRunning = true
        }
    }

    // Formats elapsed seconds as "MM:SS" (or "H:MM:SS" for sessions over an hour)
    var timerDisplay: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // Friendly text shown under the duration stepper
    var durationPreview: String {
        let hours = minutes / 60
        let mins  = minutes % 60
        if hours == 0 { return "\(mins) minutes" }
        if mins  == 0 { return "\(hours) hour\(hours > 1 ? "s" : "")" }
        return "\(hours) hour\(hours > 1 ? "s" : "") and \(mins) minutes"
    }

    // Saves subject to the recent-subjects list (deduplicated, capped at 10)
    private func saveRecentSubject(_ name: String) {
        guard !name.isEmpty else { return }
        var list = recentSubjects
        list.removeAll { $0.lowercased() == name.lowercased() }
        list.insert(name, at: 0)
        if list.count > 10 { list = Array(list.prefix(10)) }
        recentSubjectsData = (try? JSONEncoder().encode(list)) ?? Data()
    }
}

#Preview {
    NewSessionView { _ in }
}
