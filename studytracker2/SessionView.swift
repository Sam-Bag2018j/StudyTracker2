//
//  SessionView.swift
//  studytracker2
//
//  This file holds the StudySession data model.
//

import SwiftUI

// StudySession stores all info about one study session
struct StudySession: Identifiable, Codable {
    var id = UUID()          // unique ID so SwiftUI can track each session
    var subject: String      // e.g. "Math", "History"
    var minutes: Int         // how long the session was
    var date: Date           // when the session happened
    var notes: String        // optional notes about what was studied

    // Returns a nicely formatted duration string like "1 hr 30 min"
    var durationText: String {
        let hours = minutes / 60
        let mins  = minutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins  == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }

    // Returns "Today at 3:45 PM", "Yesterday at 9:00 AM", or "Jan 5 at 2:30 PM"
    var dateText: String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short           // e.g. "3:45 PM"
        let timeString = timeFormatter.string(from: date)

        if Calendar.current.isDateInToday(date)     { return "Today at \(timeString)" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday at \(timeString)" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return "\(dateFormatter.string(from: date)) at \(timeString)"
    }
}
