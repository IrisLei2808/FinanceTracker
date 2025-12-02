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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(watchlist)
        }
    }
}
