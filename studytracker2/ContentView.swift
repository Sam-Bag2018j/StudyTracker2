//
//  ContentView.swift
//  studytracker2
//

import SwiftUI

struct ContentView: View {

    // All study sessions are stored here
    @State private var sessions: [StudySession] = []

    // Controls whether the "Add Session" sheet is showing
    @State private var showingNewSession = false

    // Controls whether the Goals sheet is showing
    @State private var showingGoals = false

    // Controls whether Notification Settings sheet is showing
    @State private var showingNotificationSettings = false

    // Upcoming exams cached from UserDefaults — refreshed each time the tab appears
    @State private var upcomingExams: [Exam] = []

    // Per-subject daily goals: maps subject name → goal in minutes
    @State private var subjectGoals: [String: Int] = [:]
          // Daily goal in minutes (2 hours = 120 minutes)
    let dailyGoalMinutes = 120

    // --- Computed properties for stats ---

    // Total minutes studied today
    var todayMinutes: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
    }

    // Total minutes studied in the last 7 days
    var weekMinutes: Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessions
            .filter { $0.date >= sevenDaysAgo }
            .reduce(0) { $0 + $1.minutes }
    }

    // Sessions sorted newest first (for the list)
    var sortedSessions: [StudySession] {
        sessions.sorted { $0.date > $1.date }
    }

    // All unique subject names from sessions (sorted A–Z)
    var allSubjects: [String] {
        Array(Set(sessions.map { $0.subject })).sorted()
    }

    // Subjects that have a custom goal set (sorted A–Z)
    var subjectsWithGoals: [String] {
        subjectGoals.keys.sorted()
    }

    // Upcoming (non-past) exams sorted by nearest date first
    var sortedUpcomingExams: [Exam] {
        upcomingExams.filter { !$0.isPast }.sorted { $0.date < $1.date }
    }

    // Today's minutes studied for one specific subject
    func todayMinutes(for subject: String) -> Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.date) && $0.subject == subject }
            .reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        TabView {

        // ── Sessions tab ────────────────────────────────────────
        NavigationStack {
            List {

                // ── Stats Card ─────────────────────────────────
                Section {
                    VStack(spacing: 14) {

                        // Daily goal progress bar
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Daily Goal")
                                    .font(.headline)
                                Spacer()
                                Text("\(todayMinutes) / \(dailyGoalMinutes) min")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            // Progress bar — capped at 100% so it doesn't overflow
                            ProgressView(
                                value: Double(min(todayMinutes, dailyGoalMinutes)),
                                total: Double(dailyGoalMinutes)
                            )
                            .tint(.blue)

                            // Celebration message when goal is reached
                            if todayMinutes >= dailyGoalMinutes {
                                Text("🎉 Daily goal reached! Great work!")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        Divider()

                        // Today / This Week / Total sessions row
                        HStack {
                            StatCard(title: "Today",     value: formatMinutes(todayMinutes))
                            Divider()
                            StatCard(title: "This Week", value: formatMinutes(weekMinutes))
                            Divider()
                            StatCard(title: "Sessions",  value: "\(sessions.count)")
                        }
                        .frame(height: 50)
                    }
                    .padding(.vertical, 4)
                }

                // ── Upcoming Exams Countdown ──────────────────
                if !sortedUpcomingExams.isEmpty {
                    Section {
                        ForEach(sortedUpcomingExams.prefix(5), id: \.id) { exam in
                            ExamCountdownRow(exam: exam)
                        }
                    } header: {
                        HStack {
                            Text("Upcoming Exams")
                            Spacer()
                            if sortedUpcomingExams.count > 5 {
                                Text("+\(sortedUpcomingExams.count - 5) more in Exams tab")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // ── Per-Subject Goals ─────────────────────────
                if !subjectsWithGoals.isEmpty {
                    Section("Today's Goals by Subject") {
                        ForEach(subjectsWithGoals, id: \.self) { subject in
                            SubjectGoalRow(
                                subject: subject,
                                studiedMinutes: todayMinutes(for: subject),
                                goalMinutes: subjectGoals[subject] ?? 60
                            )
                        }
                    }
                }

                // ── Sessions List ──────────────────────────────
                if sessions.isEmpty {
                    // Empty state — shown when no sessions have been added yet
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No sessions yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Tap + to log your first study session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else {
                    Section("Recent Sessions") {
                        ForEach(sortedSessions) { session in
                            SessionRowView(session: session)
                        }
                        // Swipe-to-delete — maps sorted index back to sessions array
                        .onDelete { indexSet in
                            let idsToDelete = indexSet.map { sortedSessions[$0].id }
                            sessions.removeAll { idsToDelete.contains($0.id) }
                            saveSessions()
                        }
                    }
                }
            }
            .navigationTitle("Study Tracker 📚")
            .toolbar {
                // Goals button — always visible
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingGoals = true
                    } label: {
                        Label("Goals", systemImage: "target")
                    }
                }
                // Edit button — only shown when there are sessions to edit
                if !sessions.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
                // Add session button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        Image(systemName: "bell")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Sheet that slides up when adding a new session
            .sheet(isPresented: $showingNewSession) {
                NewSessionView { newSession in
                    sessions.append(newSession)
                    saveSessions()
                }
            }
            // Sheet for managing per-subject goals
            .sheet(isPresented: $showingGoals) {
                GoalsView(subjectGoals: $subjectGoals, allSubjects: allSubjects)
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .onAppear {
                loadSessions()
                loadUpcomingExams()
            }
        }
        .tabItem { Label("Sessions", systemImage: "book.fill") }

        // ── Charts tab ───────────────────────────────────────────
        ChartsView(sessions: sessions)
            .tabItem { Label("Charts", systemImage: "chart.bar.fill") }

        // ── Exams tab ────────────────────────────────────────────
        ExamsView()
            .tabItem { Label("Exams", systemImage: "calendar") }

        // ── Grades tab ──────────────────────────────────────────
        GradesView()
            .tabItem { Label("Grades", systemImage: "graduationcap.fill") }

        // ── Achievements tab ─────────────────────────────────────
        AchievementsView(sessions: sessions)
            .tabItem { Label("Achievements", systemImage: "trophy.fill") }

        } // end TabView
        .task {
            await NotificationManager.requestPermission()
        }
    }

    // Converts total minutes into a short readable string like "1h 30m"
    func formatMinutes(_ total: Int) -> String {
        let hours = total / 60
        let mins  = total % 60
        if hours == 0 { return "\(mins)m" }
        if mins  == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    func loadUpcomingExams() {
        guard
            let data    = UserDefaults.standard.data(forKey: "studytracker.exams"),
            let decoded = try? JSONDecoder().decode([Exam].self, from: data)
        else { return }
        upcomingExams = decoded
    }

    func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "studytracker.sessions")
        }
    }

    func loadSessions() {
        guard
            let data    = UserDefaults.standard.data(forKey: "studytracker.sessions"),
            let decoded = try? JSONDecoder().decode([StudySession].self, from: data)
        else { return }
        sessions = decoded
    }
}

// ── Stat Card ─────────────────────────────────────────
// Small card showing a number and a label (used in the stats row)
struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ── Session Row ───────────────────────────────────────
// One row in the sessions list
struct SessionRowView: View {
    let session: StudySession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.subject)
                    .font(.headline)
                Spacer()
                Text(session.durationText)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.blue)
            }
            HStack(spacing: 4) {
                Text(session.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // Only show notes if the user wrote something
                if !session.notes.isEmpty {
                    Text("· \(session.notes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// ── Subject Goal Row ─────────────────────────────────
// Progress bar for one subject shown in "Today's Goals by Subject"
struct SubjectGoalRow: View {
    let subject: String
    let studiedMinutes: Int
    let goalMinutes: Int

    // Progress from 0.0 to 1.0, capped so the bar never overflows
    var progress: Double {
        min(Double(studiedMinutes) / Double(goalMinutes), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subject)
                    .font(.headline)
                Spacer()
                // Green checkmark when the goal is reached
                if studiedMinutes >= goalMinutes {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Text("\(studiedMinutes) / \(goalMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(studiedMinutes >= goalMinutes ? .green : .blue)
        }
        .padding(.vertical, 2)
    }
}

// ── Exam Countdown Row ───────────────────────────────
// Compact row shown on the Sessions page for each upcoming exam
struct ExamCountdownRow: View {
    let exam: Exam

    var urgencyColor: Color {
        if exam.isToday        { return .red }
        if exam.daysUntil <= 3 { return .red }
        if exam.daysUntil <= 7 { return .orange }
        return .blue
    }

    var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: exam.date)
    }

    var body: some View {
        HStack(spacing: 12) {

            // Left urgency stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(urgencyColor)
                .frame(width: 4, height: 48)

            // Name + subject + date
            VStack(alignment: .leading, spacing: 3) {
                Text(exam.name)
                    .font(.headline)
                if !exam.subject.isEmpty {
                    Text(exam.subject)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Countdown badge
            if exam.isToday {
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

#Preview {
    ContentView()
        .environmentObject(GradeStore())
}
