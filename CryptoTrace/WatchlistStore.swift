import Foundation
import SwiftUI
import Combine

@MainActor
final class WatchlistStore: ObservableObject {
    @Published private(set) var ids: Set<Int> = []

    private let defaultsKey = "watchlist.ids"

    init() {
        load()
    }

    func contains(_ id: Int) -> Bool {
        ids.contains(id)
    }

    func toggle(_ id: Int) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        persist()
    }

    func add(_ id: Int) {
        guard !ids.contains(id) else { return }
        ids.insert(id)
        persist()
    }

    func remove(_ id: Int) {
        guard ids.contains(id) else { return }
        ids.remove(id)
        persist()
    }

    private func load() {
        let arr = UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? []
        ids = Set(arr)
    }

    private func persist() {
        UserDefaults.standard.set(Array(ids), forKey: defaultsKey)
    }
}
