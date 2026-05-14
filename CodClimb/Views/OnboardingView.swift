// CodClimb/Views/OnboardingView.swift
import SwiftUI

// MARK: - Onboarding model

private struct OnboardingPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let body: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        systemImage: "chart.bar.fill",
        imageColor: Theme.Palette.send,
        title: "Live Condition Scores",
        body: "Every crag gets a real-time score (0–100) based on temperature, wind, humidity, rain, and forecast. Green means send conditions. Red means stay home."
    ),
    OnboardingPage(
        systemImage: "bell.badge.fill",
        imageColor: Theme.Palette.accent,
        title: "Crag Alerts",
        body: "Favorite a crag and set a score threshold. CodClimb will notify you the moment your wall hits send conditions — so you never miss a window."
    ),
    OnboardingPage(
        systemImage: "person.2.fill",
        imageColor: Color(red: 0.35, green: 0.55, blue: 0.85),
        title: "Community Reports",
        body: "Trust the beta. Real climbers post live condition reports from the wall — rock feel, seepage, crowd level, and photos. Post your own after every session."
    )
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Photo background — cross-fades as page changes
            OnboardingPhotoBg(slide: currentPage)
                .animation(.easeInOut(duration: 0.6), value: currentPage)

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        PageContent(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom controls
                VStack(spacing: 24) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage
                                      ? Theme.Palette.accent
                                      : Theme.Palette.divider)
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // Primary button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                hasSeenOnboarding = true
                            }
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Palette.accent)
                            )
                    }
                    .padding(.horizontal, 32)

                    // Skip on early pages
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            withAnimation { hasSeenOnboarding = true }
                        }
                        .font(Theme.Typography.callout)
                        .foregroundStyle(.white.opacity(0.70))
                    } else {
                        // Spacer to keep layout consistent
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Page content

private struct PageContent: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon — frosted glass circle over photo
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(page.imageColor.opacity(0.20))
                    .frame(width: 140, height: 140)
                Image(systemName: page.systemImage)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(.bottom, 48)

            // Title — white over photo
            Text(page.title)
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

            // Body
            Text(page.body)
                .font(Theme.Typography.body)
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}
