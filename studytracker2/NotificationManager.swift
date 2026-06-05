//
//  NotificationManager.swift
//  studytracker2
//
//  Handles scheduling and canceling of local notifications.
//  Uses a static enum so any view can call these directly without needing
//  to pass an instance around.
//

import Foundation
import UserNotifications
import SwiftUI

// ── Notification Manager ───────────────────────────────────────────────────
// All methods are static — call them directly from any view or helper.

enum NotificationManager {

    // ── Permission ─────────────────────────────────────────────────────────

    /// Requests notification authorization. Safe to call multiple times; iOS
    /// will only show the system prompt once.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // ── Daily study reminder ────────────────────────────────────────────────

    /// Schedules (or reschedules) the repeating daily reminder.
    static func scheduleDailyReminder(hour: Int, minute: Int) {
        cancelDailyReminder()
        let content   = UNMutableNotificationContent()
        content.title = "📚 Study Reminder"
        content.body  = "Time to hit the books! Don't break your streak today."
        content.sound = .default

        var comps    = DateComponents()
        comps.hour   = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "daily.reminder", content: content, trigger: trigger)
        )
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["daily.reminder"])
    }

    // ── Exam reminders ──────────────────────────────────────────────────────

    /// Schedules reminders at 7 days, 3 days, 1 day before, and on exam day.
    static func scheduleExamNotifications(for exam: Exam) {
        cancelExamNotifications(for: exam.id)

        let calendar     = Calendar.current
        let examDayStart = calendar.startOfDay(for: exam.date)
        let subjectInfo  = exam.subject.isEmpty ? "" : " (\(exam.subject))"

        let milestones: [(offset: Int, title: String, body: String)] = [
            (7, "📅 1 Week Until Exam",
             "Your \(exam.name) exam is in 7 days\(subjectInfo). Start your review now!"),
            (3, "⚠️ 3 Days Until Exam",
             "Your \(exam.name) exam is in 3 days\(subjectInfo). Intensify your preparation!"),
            (1, "🔔 Exam Tomorrow!",
             "Your \(exam.name) exam is tomorrow\(subjectInfo). Do a final review tonight!"),
            (0, "📝 Exam Today — Good Luck!",
             "Your \(exam.name) exam is today\(subjectInfo). You've got this! 🍀"),
        ]

        for m in milestones {
            guard
                let notifDay = calendar.date(byAdding: .day, value: -m.offset, to: examDayStart),
                notifDay > Date()
            else { continue }

            let content   = UNMutableNotificationContent()
            content.title = m.title
            content.body  = m.body
            content.sound = .default

            var comps    = calendar.dateComponents([.year, .month, .day], from: notifDay)
            comps.hour   = 9
            comps.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id      = "exam.\(exam.id.uuidString).\(m.offset)"
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            )
        }
    }

    static func cancelExamNotifications(for examID: UUID) {
        let ids = [0, 1, 3, 7].map { "exam.\(examID.uuidString).\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// ── Notification Settings View ─────────────────────────────────────────────

struct NotificationSettingsView: View {

    @Environment(\.dismiss) var dismiss

    // Persisted settings
    @AppStorage("notif.dailyEnabled") private var dailyEnabled = false
    @AppStorage("notif.dailyHour")    private var dailyHour    = 19   // 7 PM default
    @AppStorage("notif.dailyMinute")  private var dailyMinute  = 0

    // Local state for the time picker (Date is easier to bind to DatePicker)
    @State private var reminderTime = Date()
    @State private var isAuthorized = false

    var body: some View {
        NavigationStack {
            Form {

                // ── Authorization status ─────────────────────────────────
                Section("Permission") {
                    if isAuthorized {
                        Label("Notifications are enabled", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Notifications are disabled", systemImage: "bell.slash.fill")
                                .foregroundStyle(.red)
                            Text("Enable notifications in iOS Settings to receive exam reminders and daily study prompts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Daily reminder ───────────────────────────────────────
                Section {
                    Toggle("Daily Study Reminder", isOn: $dailyEnabled)
                        .onChange(of: dailyEnabled) { _, enabled in
                            applyDailyReminderChange(enabled: enabled, time: reminderTime)
                        }

                    if dailyEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _, newTime in
                            let c    = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                            dailyHour   = c.hour   ?? 19
                            dailyMinute = c.minute ?? 0
                            NotificationManager.scheduleDailyReminder(hour: dailyHour, minute: dailyMinute)
                        }
                    }
                } header: {
                    Text("Daily Reminder")
                } footer: {
                    Text("A daily notification to remind you to log a study session.")
                }

                // ── Exam reminders info ──────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Automatic reminders", systemImage: "calendar.badge.clock")
                            .font(.subheadline).bold()
                        Text("When you add an exam, you'll automatically get reminders at 7 days, 3 days, 1 day before, and on exam day — all at 9:00 AM.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Exam Reminders")
                }
            }
            .navigationTitle("Notifications 🔔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                // Restore time picker from stored values
                var c    = DateComponents()
                c.hour   = dailyHour
                c.minute = dailyMinute
                reminderTime = Calendar.current.date(from: c) ?? Date()

                // Check actual system authorization status
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        isAuthorized = settings.authorizationStatus == .authorized
                    }
                }
            }
        }
    }

    private func applyDailyReminderChange(enabled: Bool, time: Date) {
        if enabled {
            NotificationManager.scheduleDailyReminder(hour: dailyHour, minute: dailyMinute)
        } else {
            NotificationManager.cancelDailyReminder()
        }
    }
}

#Preview {
    NotificationSettingsView()
}
