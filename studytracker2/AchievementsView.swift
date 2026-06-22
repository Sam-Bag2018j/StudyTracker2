//
//  AchievementsView.swift
//  studytracker2
//
//  Milestone badges computed from the user's study session history.
//

import SwiftUI

// ── Achievement model ──────────────────────────────────────────────────────

struct Achievement: Identifiable {
    let id: String          // unique key
    let emoji: String
    let title: String
    let description: String
    let isUnlocked: Bool

    // Brief progress hint shown when still locked
    let progressHint: String?

    init(_ id: String, emoji: String, title: String,
         description: String, isUnlocked: Bool, progressHint: String? = nil) {
        self.id           = id
        self.emoji        = emoji
        self.title        = title
        self.description  = description
        self.isUnlocked   = isUnlocked
        self.progressHint = progressHint
    }
}

// ── Achievements view ──────────────────────────────────────────────────────

struct AchievementsView: View {

    let sessions: [StudySession]

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var achievements: [Achievement] { buildAchievements() }

    var unlockedCount: Int { achievements.filter { $0.isUnlocked }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // ── Banner ───────────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("\(unlockedCount) / \(achievements.count)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("achievements unlocked")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Progress bar
                        ProgressView(
                            value: Double(unlockedCount),
                            total: Double(achievements.count)
                        )
                        .tint(.yellow)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 24)

                    Divider().padding(.horizontal)

                    // ── Achievement grid ─────────────────────────────────
                    // 3 columns on iPad, 2 on iPhone
                    let columnCount = horizontalSizeClass == .regular ? 3 : 2
                    let columns = Array(repeating: GridItem(.flexible()), count: columnCount)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(achievements) { a in
                            AchievementCard(achievement: a)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements 🏆")
        }
    }

    // ── Achievement definitions ────────────────────────────────────────────

    private func buildAchievements() -> [Achievement] {
        let calendar     = Calendar.current
        let totalMinutes = sessions.reduce(0) { $0 + $1.minutes }
        let totalHours   = totalMinutes / 60

        // --- streak ---
        let streak = longestCurrentStreak()
        let bestStreak = longestEverStreak()

        // --- subject totals ---
        var subjectMinutes: [String: Int] = [:]
        for s in sessions { subjectMinutes[s.subject, default: 0] += s.minutes }
        let maxSubjectHours = (subjectMinutes.values.max() ?? 0) / 60

        // --- day-level counts ---
        let uniqueStudyDays = Set(sessions.map { calendar.startOfDay(for: $0.date) }).count

        // --- early bird / night owl ---
        let hasEarlySession = sessions.contains { session in
            let h = calendar.component(.hour, from: session.date)
            return h < 7
        }
        let hasLateSession = sessions.contains { session in
            let h = calendar.component(.hour, from: session.date)
            return h >= 22
        }

        // --- marathon (single session ≥ 120 min) ---
        let hasMarathon = sessions.contains { $0.minutes >= 120 }

        // --- most sessions in a day ---
        let sessionsByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        let maxSessionsInDay = sessionsByDay.values.map { $0.count }.max() ?? 0

        // --- weekend warrior (session on both Sat and Sun in same week) ---
        let hasWeekendWarrior = checkWeekendWarrior()

        return [
            Achievement(
                "first_step",
                emoji: "🌱",
                title: "First Step",
                description: "Log your very first study session.",
                isUnlocked: !sessions.isEmpty
            ),
            Achievement(
                "five_hours",
                emoji: "📖",
                title: "Getting Started",
                description: "Study for a total of 5 hours.",
                isUnlocked: totalHours >= 5,
                progressHint: totalHours < 5 ? "\(totalHours)/5 hours" : nil
            ),
            Achievement(
                "ten_hours",
                emoji: "📚",
                title: "Bookworm",
                description: "Accumulate 10 total hours of study time.",
                isUnlocked: totalHours >= 10,
                progressHint: totalHours < 10 ? "\(totalHours)/10 hours" : nil
            ),
            Achievement(
                "fifty_hours",
                emoji: "🎓",
                title: "Scholar",
                description: "Reach 50 total hours of studying.",
                isUnlocked: totalHours >= 50,
                progressHint: totalHours < 50 ? "\(totalHours)/50 hours" : nil
            ),
            Achievement(
                "century_club",
                emoji: "💯",
                title: "Century Club",
                description: "Hit 100 total hours of study time.",
                isUnlocked: totalHours >= 100,
                progressHint: totalHours < 100 ? "\(totalHours)/100 hours" : nil
            ),
            Achievement(
                "streak_3",
                emoji: "🔥",
                title: "On Fire",
                description: "Study 3 days in a row.",
                isUnlocked: bestStreak >= 3,
                progressHint: bestStreak < 3 ? "\(streak) day streak" : nil
            ),
            Achievement(
                "streak_7",
                emoji: "⚡",
                title: "Lightning Week",
                description: "Study every day for 7 consecutive days.",
                isUnlocked: bestStreak >= 7,
                progressHint: bestStreak < 7 ? "\(streak)/7 day streak" : nil
            ),
            Achievement(
                "streak_30",
                emoji: "🌟",
                title: "Unstoppable",
                description: "Maintain a 30-day study streak.",
                isUnlocked: bestStreak >= 30,
                progressHint: bestStreak < 30 ? "\(streak)/30 day streak" : nil
            ),
            Achievement(
                "marathon",
                emoji: "🏃",
                title: "Marathon Session",
                description: "Complete a single session of 2 or more hours.",
                isUnlocked: hasMarathon
            ),
            Achievement(
                "early_bird",
                emoji: "🐦",
                title: "Early Bird",
                description: "Log a study session before 7 AM.",
                isUnlocked: hasEarlySession
            ),
            Achievement(
                "night_owl",
                emoji: "🦉",
                title: "Night Owl",
                description: "Study after 10 PM.",
                isUnlocked: hasLateSession
            ),
            Achievement(
                "five_sessions_day",
                emoji: "⚡",
                title: "Power Day",
                description: "Log 5 or more sessions in a single day.",
                isUnlocked: maxSessionsInDay >= 5,
                progressHint: maxSessionsInDay < 5 ? "\(maxSessionsInDay)/5 sessions in a day" : nil
            ),
            Achievement(
                "subject_master",
                emoji: "🎯",
                title: "Subject Master",
                description: "Study a single subject for 20+ total hours.",
                isUnlocked: maxSubjectHours >= 20,
                progressHint: maxSubjectHours < 20 ? "\(maxSubjectHours)/20 hours in one subject" : nil
            ),
            Achievement(
                "consistent",
                emoji: "📅",
                title: "Consistent",
                description: "Study on 30 different days.",
                isUnlocked: uniqueStudyDays >= 30,
                progressHint: uniqueStudyDays < 30 ? "\(uniqueStudyDays)/30 days" : nil
            ),
            Achievement(
                "weekend_warrior",
                emoji: "🏅",
                title: "Weekend Warrior",
                description: "Study on both Saturday and Sunday in the same week.",
                isUnlocked: hasWeekendWarrior
            ),
        ]
    }

    // ── Streak helpers ─────────────────────────────────────────────────────

    /// Returns the current streak (consecutive days up to and including today)
    private func longestCurrentStreak() -> Int {
        let calendar    = Calendar.current
        let studiedDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var streak      = 0
        var day         = calendar.startOfDay(for: Date())

        while studiedDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Returns the longest streak ever (any consecutive run in history)
    private func longestEverStreak() -> Int {
        let calendar    = Calendar.current
        let studiedDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
            .sorted()
        guard !studiedDays.isEmpty else { return 0 }

        var best    = 1
        var current = 1

        for i in 1..<studiedDays.count {
            let prev = studiedDays[i - 1]
            let curr = studiedDays[i]
            if let expected = calendar.date(byAdding: .day, value: 1, to: prev), expected == curr {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// True if any calendar week contains sessions on both Saturday AND Sunday
    private func checkWeekendWarrior() -> Bool {
        let calendar = Calendar.current
        // Group sessions by their ISO week-of-year + year (handles year boundaries)
        var weekMap: [String: Set<Int>] = [:]
        for session in sessions {
            let week     = calendar.component(.weekOfYear, from: session.date)
            let year     = calendar.component(.year,        from: session.date)
            let weekday  = calendar.component(.weekday,     from: session.date) // 1=Sun, 7=Sat
            let key      = "\(year)-\(week)"
            weekMap[key, default: []].insert(weekday)
        }
        return weekMap.values.contains { $0.contains(1) && $0.contains(7) }
    }
}

// ── Achievement card ───────────────────────────────────────────────────────

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.emoji)
                .font(.system(size: 36))
                .opacity(achievement.isUnlocked ? 1 : 0.25)
                .grayscale(achievement.isUnlocked ? 0 : 1)

            Text(achievement.title)
                .font(.subheadline).bold()
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)

            Text(achievement.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if !achievement.isUnlocked, let hint = achievement.progressHint {
                Text(hint)
                    .font(.caption2).bold()
                    .foregroundStyle(.blue)
            } else if achievement.isUnlocked {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .font(.caption2).bold()
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(achievement.isUnlocked ? Color.yellow.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    AchievementsView(sessions: [])
}
