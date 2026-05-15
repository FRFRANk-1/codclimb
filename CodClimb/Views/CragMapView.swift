// CodClimb/Views/CragMapView.swift
// Map tab: all crags as score-coloured pins. Tap → crag detail sheet.
// Uses iOS 16-compatible MapKit APIs (Map(coordinateRegion:annotationItems:)).

import SwiftUI
import MapKit
import Combine

// MARK: - ViewModel

@MainActor
final class CragMapViewModel: ObservableObject {

    @Published private(set) var crags: [Crag] = []
    @Published private(set) var snapshots: [String: CragListViewModel.CragSnapshot] = [:]

    private let client = OpenMeteoClient()
    private let scorer = ScoringService()
    private var fetching: Set<String> = []

    func snapshot(for crag: Crag) -> CragListViewModel.CragSnapshot? {
        snapshots[crag.id]
    }

    func load() async {
        guard crags.isEmpty else { return }
        do { crags = try CragRepository.loadAll() }
        catch { print("[CragMapViewModel] \(error)") }
    }

    /// Lazily fetch weather for a single crag (hits disk cache first — usually instant).
    func fetchIfNeeded(for crag: Crag) async {
        guard snapshots[crag.id] == nil, !fetching.contains(crag.id) else { return }
        fetching.insert(crag.id)
        defer { fetching.remove(crag.id) }
        do {
            let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
            let score  = scorer.score(for: bundle)
            snapshots[crag.id] = CragListViewModel.CragSnapshot(bundle: bundle, score: score)
        } catch {
            print("[CragMapViewModel] weather fetch failed for \(crag.name): \(error)")
        }
    }
}

// MARK: - Root view

struct CragMapView: View {

    @StateObject private var viewModel = CragMapViewModel()
    @StateObject private var locManager = LocationManager()

    @State private var selectedCrag: Crag?
    @State private var searchText = ""
    @State private var isSearchFocused = false

    // iOS 16 uses MKCoordinateRegion
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5, longitude: -95.0),
        span: MKCoordinateSpan(latitudeDelta: 32, longitudeDelta: 32)
    )

    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5, longitude: -95.0),
        span: MKCoordinateSpan(latitudeDelta: 32, longitudeDelta: 32)
    )

    // Crags filtered by search
    private var filteredCrags: [Crag] {
        guard !searchText.isEmpty else { return viewModel.crags }
        return viewModel.crags.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.region.localizedCaseInsensitiveContains(searchText) ||
            $0.rockType.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Map ──────────────────────────────────────────────────
                Map(coordinateRegion: $region,
                    showsUserLocation: true,
                    annotationItems: viewModel.crags) { crag in
                    MapAnnotation(coordinate: crag.coordinate) {
                        let isHighlighted = !searchText.isEmpty &&
                            filteredCrags.contains(where: { $0.id == crag.id })
                        CragPin(
                            snapshot: viewModel.snapshot(for: crag),
                            isLoading: viewModel.snapshot(for: crag) == nil,
                            dimmed: !searchText.isEmpty && !isHighlighted
                        )
                        .task { await viewModel.fetchIfNeeded(for: crag) }
                        .onTapGesture {
                            isSearchFocused = false
                            selectedCrag = crag
                        }
                    }
                }
                .ignoresSafeArea()

                // ── Search bar (top) ─────────────────────────────────────
                VStack(spacing: 0) {
                    MapSearchBar(text: $searchText, isFocused: $isSearchFocused) {
                        // Fly to first match
                        if let first = filteredCrags.first {
                            withAnimation {
                                region = MKCoordinateRegion(
                                    center: first.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Search results dropdown
                    if isSearchFocused && !searchText.isEmpty {
                        SearchResultsList(crags: filteredCrags, viewModel: viewModel) { crag in
                            withAnimation {
                                region = MKCoordinateRegion(
                                    center: crag.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                                )
                            }
                            searchText = ""
                            isSearchFocused = false
                            selectedCrag = crag
                        }
                        .padding(.horizontal, 12)
                    }
                    Spacer()
                }

                // ── Zoom + Location controls (bottom-right) ───────────────
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 0) {
                            // Zoom in
                            MapControlButton(icon: "plus") {
                                withAnimation {
                                    region.span = MKCoordinateSpan(
                                        latitudeDelta:  max(0.02, region.span.latitudeDelta  / 2),
                                        longitudeDelta: max(0.02, region.span.longitudeDelta / 2)
                                    )
                                }
                            }
                            Divider().frame(width: 44)
                            // Zoom out
                            MapControlButton(icon: "minus") {
                                withAnimation {
                                    region.span = MKCoordinateSpan(
                                        latitudeDelta:  min(80, region.span.latitudeDelta  * 2),
                                        longitudeDelta: min(80, region.span.longitudeDelta * 2)
                                    )
                                }
                            }
                        }
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)

                        // User location — tap fires the permission + location request;
                        // the map moves via onChange when the callback delivers coordinates.
                        MapControlButton(icon: "location.fill") {
                            locManager.requestLocation()
                        }
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
                    }
                    .padding(.trailing, 14)
                    .padding(.bottom, 84)

                    // (Loading pill removed — map no longer pre-fetches weather)
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { withAnimation { region = defaultRegion } } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .tint(Theme.Palette.accent)
                }
            }
        }
        .task { await viewModel.load() }
        .onReceive(locManager.$lastLocation.compactMap { $0 }) { loc in
            // Fires once CLLocationManager async callback delivers coordinates.
            // onReceive needs no Equatable conformance on CLLocationCoordinate2D.
            withAnimation {
                region = MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
                )
            }
        }
        .sheet(item: $selectedCrag) { crag in
            CragDetailSheet(crag: crag, snapshot: viewModel.snapshot(for: crag))
        }
    }

    // MARK: - Loading pill

    private var loadingPill: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(Theme.Palette.accent)
            Text("Loading conditions…")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Theme.Palette.surface)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3))
        .padding(.bottom, 12)
    }
}

// MARK: - Search bar

private struct MapSearchBar: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textTertiary)
            TextField("Search crags, states, rock type…", text: $text)
                .font(Theme.Typography.body)
                .onTapGesture { isFocused = true }
                .onSubmit { onSubmit(); isFocused = false }
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = ""; isFocused = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.surface)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Search results dropdown

private struct SearchResultsList: View {
    let crags: [Crag]
    let viewModel: CragMapViewModel
    let onSelect: (Crag) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(crags.prefix(5)) { crag in
                Button { onSelect(crag) } label: {
                    HStack(spacing: 10) {
                        let snap = viewModel.snapshot(for: crag)
                        Circle()
                            .fill(snap?.score.verdict.color ?? Color(red: 0.75, green: 0.75, blue: 0.73))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(crag.name)
                                .font(Theme.Typography.callout).fontWeight(.medium)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(crag.region)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                        Spacer()
                        if let snap {
                            Text("\(snap.score.value)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(snap.score.verdict.color)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if crag.id != crags.prefix(5).last?.id {
                    Divider().padding(.horizontal, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.surface)
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Map control button (zoom / location)

private struct MapControlButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Location manager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] \(error.localizedDescription)")
    }
}

// MARK: - Pin annotation

private struct CragPin: View {
    let snapshot: CragListViewModel.CragSnapshot?
    let isLoading: Bool
    var dimmed: Bool = false

    @State private var pulsing = false

    private var scoreColor: Color {
        guard let s = snapshot else { return Color(red: 0.75, green: 0.75, blue: 0.73) }
        return s.score.verdict.color
    }

    private var scoreText: String {
        guard let s = snapshot else { return "—" }
        return "\(s.score.value)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Badge
            ZStack {
                Circle()
                    .fill(scoreColor)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 2)

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                        .scaleEffect(pulsing ? 1.0 : 0.82)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                        .onAppear { pulsing = true }
                } else {
                    Text(scoreText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                }
            }

            // Pointer triangle
            TrianglePointer()
                .fill(scoreColor)
                .frame(width: 10, height: 6)
        }
        .opacity(dimmed ? 0.30 : 1.0)
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Detail sheet

private struct CragDetailSheet: View {
    let crag: Crag
    let snapshot: CragListViewModel.CragSnapshot?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CragDetailView(crag: crag, preloaded: snapshot)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .tint(Theme.Palette.accent)
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    CragMapView()
        .environmentObject(FavoritesStore())
        .environmentObject(NotificationService())
        .environmentObject(ConditionReportStore())
}
