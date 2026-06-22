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

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gradeStore)
        }
    }

    // Sets a consistent tint and navigation bar style across the whole app
    private func configureAppearance() {
        let indigo = UIColor(red: 0.267, green: 0.302, blue: 0.859, alpha: 1)
        UINavigationBar.appearance().tintColor = indigo
        UITabBar.appearance().tintColor = indigo
    }
}
