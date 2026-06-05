//
//  studytracker2App.swift
//  studytracker2
//
//  Created by Samera on 2026-05-01.
//

import SwiftUI

@main
struct studytracker2App: App {

    // GradeStore is created once here and injected into the whole view hierarchy
    // so both GradesView and ChartsView share the same grade data.
    @StateObject private var gradeStore = GradeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gradeStore)
        }
    }
}
