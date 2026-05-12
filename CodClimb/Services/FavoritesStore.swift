import SwiftUI
import Combine

/// Persists a set of favourited crag IDs to UserDefaults via @AppStorage.
/// Inject as an @EnvironmentObject so any view can read/write without prop drilling.
@MainActor
final class FavoritesStore: ObservableObject {

    // Stored as a comma-separated string so @AppStorage can handle it.
    @AppStorage("codclimb.favorites") private var raw: String = ""

    /// Live set of favorited crag IDs.
    var ids: Set<String> {
        get { Set(raw.split(separator: ",").map(String.init)) }
        set { raw = newValue.sorted().joined(separator: ",") }
    }

    func isFavorite(_ crag: Crag) -> Bool {
        ids.contains(crag.id)
    }

    func toggle(_ crag: Crag) {
        var current = ids
        if current.contains(crag.id) {
            current.remove(crag.id)
        } else {
            current.insert(crag.id)
        }
        ids = current
        // Trigger @Published update manually since we're mutating via the computed setter
        objectWillChange.send()
    }
}
