// CodClimb/Services/PhotoLibrary.swift
//
// Maps app contexts to Frank's climbing photos.
// All images live in Assets.xcassets as proper imagesets.

import SwiftUI

enum PhotoLibrary {

    // MARK: - Named assets

    /// All 6 photos in display order
    static let all: [String] = [
        "climb-acadia-1",
        "climb-acadia-2",
        "climb-outdoor-1",
        "climb-outdoor-2",
        "climb-outdoor-3",
        "climb-outdoor-4",
    ]

    // MARK: - Onboarding hero backgrounds

    /// One photo per onboarding slide (index 0–2)
    static func onboardingPhoto(slide: Int) -> Image {
        let names = ["climb-acadia-1", "climb-outdoor-1", "climb-outdoor-2"]
        let name = names[min(slide, names.count - 1)]
        return Image(name)
    }

    // MARK: - Crag hero image

    /// Exact crag-ID → asset name. Add entries here as you bundle more photos.
    private static let cragPhotoMap: [String: String] = [
        // Acadia, ME  (photo-acadia-frank = 1Y6A7272)
        "acadia-otter-cliffs":   "photo-acadia-frank",
        "acadia-south-wall":     "photo-acadia-frank",
        "acadia-canada-cliff":   "photo-acadia-frank",
        // Farley Ledge, MA  (three photos — rotate by sub-area)
        "farley-ledge":          "photo-farley-1",
        // Rumney, NH  (photo-rumney-arugula = 1Y6A6213)
        "rumney-main":           "photo-rumney-arugula",
        "rumney-meadows":        "photo-rumney-arugula",
        "rumney-waimea":         "photo-rumney-arugula",
    ]

    /// Returns a photo that best matches a crag.
    /// Priority: exact crag-ID map → region heuristic → default.
    static func heroPhoto(for crag: Crag) -> Image {
        // 1. Exact match
        if let assetName = cragPhotoMap[crag.id] {
            return Image(assetName)
        }

        // 2. Region heuristic for states we have photos for
        let region = crag.region.lowercased()
        if region.contains("acadia") || (region.contains(", me") || region.hasSuffix(" me")) {
            return Image("photo-acadia-frank")
        }
        if region.contains("rumney") || region.contains("cannon") || region.contains("cathedral") ||
           region.contains("whitehorse") {
            return Image("photo-rumney-arugula")
        }
        if region.contains("farley") {
            return Image("photo-farley-1")
        }

        // 3. Default — the wide-angle climbing shot (1Y6A7705)
        return Image("photo-default")
    }

    /// The three Farley photos for use in carousels or random selection.
    static let farleyPhotos = ["photo-farley-1", "photo-farley-chimney", "photo-farley-5-8"]

    // MARK: - Community feed header

    static var communityHeader: Image { Image("climb-outdoor-4") }

    // MARK: - Splash / ambient

    static var ambientBackground: Image { Image("climb-outdoor-2") }
}

// MARK: - Hero Photo View

/// Full-width photo banner with gradient overlay + crag title text.
/// Uses Unsplash for accurate crag-matched photos when configured;
/// falls back to local assets so the UI always looks great.
/// Complies with Unsplash guidelines: hotlinks photos, triggers download, shows attribution.
struct CragHeroPhotoView: View {
    let crag: Crag
    var height: CGFloat = 200

    @State private var photoInfo: UnsplashPhotoInfo? = nil
    @State private var isLoadingRemote = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // ── Photo layer ────────────────────────────────────────────────
            if let info = photoInfo {
                AsyncImage(url: info.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                // Required by Unsplash API guidelines
                                UnsplashService.shared.triggerDownload(for: info)
                            }
                    case .failure:
                        PhotoLibrary.heroPhoto(for: crag)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty:
                        ZStack {
                            PhotoLibrary.heroPhoto(for: crag)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            ProgressView().tint(.white).scaleEffect(1.4)
                        }
                    @unknown default:
                        PhotoLibrary.heroPhoto(for: crag)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
            } else {
                ZStack {
                    PhotoLibrary.heroPhoto(for: crag)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    if isLoadingRemote {
                        ProgressView().tint(.white).scaleEffect(1.4)
                    }
                }
            }

            // ── Gradient overlay ───────────────────────────────────────────
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Crag name + attribution ────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(crag.name)
                    .font(Theme.Typography.title)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                Text(crag.region)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)

                // Unsplash attribution — required by API guidelines
                if let info = photoInfo {
                    UnsplashAttribution(info: info)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius))
        .task(id: crag.id) {
            guard UnsplashService.shared.isConfigured else { return }
            isLoadingRemote = true
            photoInfo = await UnsplashService.shared.photo(for: crag)
            isLoadingRemote = false
        }
    }
}

// MARK: - Unsplash attribution line (required by API guidelines)

/// "Photo by [Name] on Unsplash" — styled to sit quietly over the hero gradient.
struct UnsplashAttribution: View {
    let info: UnsplashPhotoInfo

    var body: some View {
        HStack(spacing: 3) {
            Text("Photo by")
                .foregroundStyle(.white.opacity(0.65))
            // Photographer name — links to their Unsplash profile
            if let profileURL = info.photographerProfileURL {
                Link(info.photographerName, destination: profileURL)
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            } else {
                Text(info.photographerName)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text("on")
                .foregroundStyle(.white.opacity(0.65))
            Link("Unsplash", destination: URL(string: "https://unsplash.com/?utm_source=CodClimb&utm_medium=referral")!)
                .foregroundStyle(.white.opacity(0.85))
                .underline()
        }
        .font(.system(size: 10, weight: .medium))
    }
}

// MARK: - Onboarding Slide Background

struct OnboardingPhotoBg: View {
    let slide: Int

    var body: some View {
        ZStack {
            PhotoLibrary.onboardingPhoto(slide: slide)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .blur(radius: 1.5)

            // Dark overlay so text on top is readable
            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
