//
//  FinanceTrackerApp.swift
//  FinanceTracker
//
//  Created by Owner on 11/30/25.
//

import SwiftUI
import Combine

@main
struct FinanceTrackerApp: App {
    @StateObject private var watchlist = WatchlistStore()

    // Read theme from Settings
    @AppStorage("settings.theme") private var theme: Theme = .system

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(watchlist)
                .preferredColorScheme(colorScheme(for: theme))
        }
    }

    private func colorScheme(for theme: Theme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

