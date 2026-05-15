// CodClimb/Views/ProfileView.swift
import SwiftUI
import PhotosUI

// MARK: - ProfileView (own profile, full edit)

struct ProfileView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var favorites: FavoritesStore
    @AppStorage("codclimb.username") private var username: String = ""

    @State private var avatarItem: PhotosPickerItem?
    @State private var editingBio = false
    @State private var draftBio = ""
    @State private var showingSettings = false
    @State private var showingAuth = false
    @State private var showingMyReports = false
    @State private var showingMySaved = false

    @ObservedObject private var firebase: FirebaseService = .shared
    private var isGuest: Bool { firebase.isAnonymous }
    private var profile: UserProfile? { profileStore.currentProfile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    statsRow
                    if isGuest {
                        guestBanner
                    } else {
                        climbingStylesSection
                        achievementBadgesSection
                        bioSection
                        savedCragsSection
                        recentReportsSection
                        signOutButton
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingAuth) {
                AuthView()
                    .environmentObject(profileStore)
            }
        }
        .task {
            await profileStore.loadCurrentProfile()
            profileStore.refreshStats(reports: Array(reportStore.reportsByID.values))
        }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task { await handleAvatarPick(item) }
        }
        .sheet(isPresented: $editingBio) {
            BioEditorSheet(bio: $draftBio) { saved in
                Task { await profileStore.saveProfile(displayName: username, bio: saved) }
            }
        }
        .sheet(isPresented: $showingMyReports) {
            MyReportsSheet()
                .environmentObject(reportStore)
        }
        .sheet(isPresented: $showingMySaved) {
            MySavedCragsSheet()
                .environmentObject(favorites)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Photo background strip
            PhotoLibrary.ambientBackground
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .overlay(LinearGradient(
                    colors: [.clear, Theme.Palette.background],
                    startPoint: .top, endPoint: .bottom))

            VStack(spacing: 8) {
                // Avatar
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let url = profile?.avatarURL, let parsed = URL(string: url) {
                                AsyncImage(url: parsed) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                            } else {
                                avatarPlaceholder
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.Palette.background, lineWidth: 3))

                        // Edit indicator
                        ZStack {
                            Circle().fill(Theme.Palette.accent)
                            Image(systemName: profileStore.isUploading ? "arrow.clockwise" : "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 26, height: 26)
                        .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(profileStore.isUploading)

                // Name + title
                VStack(spacing: 3) {
                    Text(profile?.displayName ?? username)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(profile?.climberTitle ?? "New to the Wall")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.accent)
                        .tracking(0.5)
                    if let since = profile?.memberSince {
                        Text("Member since \(since)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Theme.Palette.accentMuted)
            Text(String(username.prefix(1).uppercased()))
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        let savedCount = ((try? CragRepository.loadAll()) ?? []).filter { favorites.isFavorite($0) }.count
        return HStack(spacing: 0) {
            // Reports — tappable
            Button { showingMyReports = true } label: {
                ProfileStatCell(
                    value: "\(profile?.reportCount ?? 0)",
                    label: "Reports",
                    tappable: true
                )
            }
            .buttonStyle(.plain)

            Divider().frame(height: 40)

            // Thumbs-up — display only (we don't store per-liker data)
            ProfileStatCell(
                value: "\(profile?.totalThumbsUp ?? 0)",
                label: "Thumbs-up",
                tappable: false
            )

            Divider().frame(height: 40)

            // Saved — tappable
            Button { showingMySaved = true } label: {
                ProfileStatCell(
                    value: "\(savedCount)",
                    label: "Saved",
                    tappable: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.vertical, 16)
        .background(Theme.Palette.surface)
        .overlay(Rectangle().fill(Theme.Palette.divider).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Theme.Palette.divider).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Guest banner

    private var guestBanner: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Palette.accent)
            VStack(spacing: 6) {
                Text("You're browsing as a guest")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Create a free account to post condition reports, save your profile, upload an avatar, and get personalized crag alerts.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingAuth = true
            } label: {
                Text("Create Account")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.Palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button("Sign in to existing account") {
                showingAuth = true
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Palette.accent)
        }
        .padding(24)
    }

    // MARK: - Climbing styles

    private var climbingStylesSection: some View {
        let styles = profile?.climbingStyles ?? []
        let allStyles = ["Sport", "Trad", "Boulder", "Alpine"]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Climbing Styles")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text("tap to select")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            HStack(spacing: 8) {
                ForEach(allStyles, id: \.self) { style in
                    let selected = styles.contains(style)
                    Button {
                        var updated = styles
                        if selected { updated.removeAll { $0 == style } }
                        else { updated.append(style) }
                        Task { await profileStore.saveClimbingStyles(updated) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: styleIcon(style))
                                .font(.system(size: 11, weight: .medium))
                            Text(style)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(selected ? .white : Theme.Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected ? Theme.Palette.accent : Theme.Palette.surface)
                                .overlay(Capsule().stroke(
                                    selected ? Color.clear : Theme.Palette.divider,
                                    lineWidth: 1
                                ))
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selected)
                }
            }
        }
        .padding(Theme.Metrics.cardPadding)
    }

    private func styleIcon(_ style: String) -> String {
        switch style {
        case "Sport":   return "bolt.circle"
        case "Trad":    return "hexagon"
        case "Boulder": return "square.stack.3d.up"
        case "Alpine":  return "mountain.2"
        default:        return "figure.hiking"
        }
    }

    // MARK: - Achievement badges

    private var achievementBadgesSection: some View {
        let count = profile?.reportCount ?? 0
        let thumbs = profile?.totalThumbsUp ?? 0

        let badges: [(emoji: String, title: String, desc: String, earned: Bool)] = [
            ("🧗", "First Ascent",     "Posted your first condition report",   count >= 1),
            ("🔍", "Route Scout",      "Posted 5 reports",                     count >= 5),
            ("🏕️", "Crag Regular",    "Posted 10 reports",                    count >= 10),
            ("💪", "Trail Crusher",    "Posted 25 reports",                    count >= 25),
            ("👍", "Trusted Source",   "Received 10 thumbs-up",                thumbs >= 10),
            ("⭐", "Community Star",   "Received 50 thumbs-up",                thumbs >= 50),
        ]

        let earned = badges.filter(\.earned)
        let next   = badges.first(where: { !$0.earned })

        return VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)

            if earned.isEmpty {
                // Empty state — prompts action
                VStack(spacing: 8) {
                    Text("🧗")
                        .font(.system(size: 36))
                    Text("Post your first condition report to earn your first badge")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
            } else {
                // Earned badges row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(earned, id: \.title) { badge in
                            VStack(spacing: 6) {
                                Text(badge.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 56, height: 56)
                                    .background(Theme.Palette.accentMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(Theme.Palette.accent.opacity(0.3), lineWidth: 1))
                                Text(badge.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 68)
                        }

                        // Locked next badge preview
                        if let next = next {
                            VStack(spacing: 6) {
                                ZStack {
                                    Text(next.emoji)
                                        .font(.system(size: 28))
                                    Color.black.opacity(0.45)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.Palette.divider, lineWidth: 1))

                                Text(next.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 68)
                        }
                    }
                }

                // Next badge progress hint
                if let next = next {
                    Text("Next: \(next.desc)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .padding(Theme.Metrics.cardPadding)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button {
            Task { await FirebaseService.shared.signOut() }
        } label: {
            Text("Sign Out")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.nogo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Palette.nogo.opacity(0.08))
                )
        }
        .padding(.horizontal, Theme.Metrics.cardPadding)
        .padding(.top, 24)
    }

    // MARK: - Bio

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bio")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    draftBio = profile?.bio ?? ""
                    editingBio = true
                } label: {
                    Text("Edit")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.accent)
                }
            }

            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineSpacing(4)
            } else {
                Text("Add a short bio — where you climb, your style, home crag...")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .italic()
            }
        }
        .padding(Theme.Metrics.cardPadding)
    }

    // MARK: - Saved crags

    private var savedCragsSection: some View {
        let allCrags = (try? CragRepository.loadAll()) ?? []
        let saved = allCrags.filter { favorites.isFavorite($0) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Crags")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Text("\(saved.count)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)

            if saved.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text("No saved crags yet")
                        .font(Theme.Typography.callout).fontWeight(.medium)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Tap the bookmark on any crag to save it here for quick access and trip planning.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
                .padding(.horizontal, Theme.Metrics.cardPadding)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(saved) { crag in
                            SavedCragChip(crag: crag)
                        }
                    }
                    .padding(.horizontal, Theme.Metrics.cardPadding)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Recent reports

    private var recentReportsSection: some View {
        let myReports = reportStore.reportsByID.values
            .filter { $0.author == (profile?.displayName ?? username) }
            .sorted { $0.date > $1.date }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reports")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Metrics.cardPadding)

            if myReports.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text("No reports yet")
                        .font(Theme.Typography.callout).fontWeight(.medium)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Head to a crag and post your first condition report — earn your First Ascent badge.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
                .padding(.horizontal, Theme.Metrics.cardPadding)
            } else {
                let allCrags = (try? CragRepository.loadAll()) ?? []
                ForEach(Array(myReports)) { report in
                    let crag = allCrags.first(where: { $0.id == report.cragID })
                    TappableMiniReportRow(report: report, crag: crag)
                        .environmentObject(reportStore)
                        .padding(.horizontal, Theme.Metrics.cardPadding)
                }
            }
        }
    }

    // MARK: - Avatar upload handler

    private func handleAvatarPick(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let compressed = compressAvatar(data)
        await profileStore.uploadAvatar(compressed)
    }

    private func compressAvatar(_ data: Data) -> Data {
        guard let img = UIImage(data: data) else { return data }
        // Crop to square first
        let size = min(img.size.width, img.size.height)
        let origin = CGPoint(
            x: (img.size.width - size) / 2,
            y: (img.size.height - size) / 2
        )
        let cropped = img.cgImage?.cropping(to: CGRect(origin: origin, size: CGSize(width: size, height: size)))
            .map { UIImage(cgImage: $0) } ?? img

        // Resize to 200×200 and compress to ~100KB
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let resized = renderer.image { _ in cropped.draw(in: CGRect(origin: .zero, size: CGSize(width: 200, height: 200))) }
        var quality: CGFloat = 0.8
        while let compressed = resized.jpegData(compressionQuality: quality), compressed.count > 100_000, quality > 0.2 {
            quality -= 0.1
        }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}

// MARK: - Saved Crag chip (horizontal scroll in profile)

private struct SavedCragChip: View {
    let crag: Crag

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotoLibrary.heroPhoto(for: crag)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 72)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.45)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(crag.name)
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(crag.region)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
    }
}

// MARK: - Public Profile Sheet (view other climber)

struct PublicProfileSheet: View {
    let displayName: String
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var reportStore: ConditionReportStore
    @Environment(\.dismiss) private var dismiss

    private var profile: UserProfile? { profileStore.viewedProfile }

    private var userReports: [ConditionReport] {
        reportStore.reportsByID.values
            .filter { $0.author == displayName }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    private var allCrags: [Crag] { (try? CragRepository.loadAll()) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Header ──────────────────────────────────────────────
                    VStack(spacing: 16) {
                        // Avatar
                        Group {
                            if let url = profile?.avatarURL, let parsed = URL(string: url) {
                                AsyncImage(url: parsed) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    initialsAvatar
                                }
                            } else {
                                initialsAvatar
                            }
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.Palette.background, lineWidth: 3))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

                        VStack(spacing: 4) {
                            Text(displayName)
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(profile?.climberTitle ?? "Climber")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Palette.accent)
                            if let since = profile?.memberSince {
                                Text("Member since \(since)")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                        }

                        // Stats bar
                        HStack(spacing: 0) {
                            statCell(value: "\(profile?.reportCount ?? 0)", label: "Reports")
                            Divider().frame(height: 36)
                            statCell(value: "\(profile?.totalThumbsUp ?? 0)", label: "Thumbs-up")
                        }
                        .background(Theme.Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Palette.divider, lineWidth: 1))
                        .padding(.horizontal, Theme.Metrics.cardPadding)

                        // Bio
                        if let bio = profile?.bio, !bio.isEmpty {
                            Text(bio)
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, Theme.Metrics.cardPadding)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    Divider()

                    // ── Recent Reports ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Reports")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .padding(.horizontal, Theme.Metrics.cardPadding)

                        if userReports.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                                Text("No reports posted yet.")
                                    .font(Theme.Typography.callout)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                            .padding(Theme.Metrics.cardPadding)
                        } else {
                            ForEach(userReports) { report in
                                let crag = allCrags.first(where: { $0.id == report.cragID })
                                MiniReportRow(report: report, cragName: crag?.name)
                                    .padding(.horizontal, Theme.Metrics.cardPadding)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Theme.Palette.accent)
                }
            }
        }
        .presentationDetents([.large])
        .task { await profileStore.loadProfile(for: displayName) }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.headline).monospacedDigit()
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var initialsAvatar: some View {
        ZStack {
            Circle().fill(Theme.Palette.accentMuted)
            Text(String(displayName.prefix(1).uppercased()))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
        }
    }
}

// MARK: - Mini report row (used in ProfileView and PublicProfileSheet)

struct MiniReportRow: View {
    let report: ConditionReport
    var cragName: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(report.rockCondition.emoji)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(cragName ?? report.cragID.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(report.relativeTime)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 11))
                Text("\(report.thumbsUp)")
                    .font(Theme.Typography.caption)
            }
            .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
    }
}

// MARK: - Bio editor sheet

private struct BioEditorSheet: View {
    @Binding var bio: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .frame(minHeight: 100)
                } header: {
                    Text("Bio (max 150 characters)")
                } footer: {
                    Text("\(150 - draft.count) characters remaining")
                        .foregroundStyle(draft.count > 140 ? Theme.Palette.nogo : Theme.Palette.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(String(draft.prefix(150)))
                        dismiss()
                    }
                }
            }
            .onAppear { draft = bio }
            .onChange(of: draft) { v in if v.count > 150 { draft = String(v.prefix(150)) } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Reusable stat cell

private struct ProfileStatCell: View {
    let value: String
    let label: String
    var tappable: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.headline).monospacedDigit()
                .foregroundStyle(Theme.Palette.textPrimary)
            HStack(spacing: 2) {
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(tappable ? Theme.Palette.accent : Theme.Palette.textTertiary)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tappable mini report row (profile recent-reports list)

private struct TappableMiniReportRow: View {
    let report: ConditionReport
    let crag: Crag?
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @State private var showingDetail = false

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 10) {
                Text(report.rockCondition.emoji)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(crag?.name ?? "Unknown crag")
                        .font(Theme.Typography.callout).fontWeight(.medium)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(report.relativeTime)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ReportDetailSheet(report: report, crag: crag)
                .environmentObject(profileStore)
                .environmentObject(reportStore)
        }
    }
}

// MARK: - My Reports sheet

private struct MyReportsSheet: View {
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @AppStorage("codclimb.username") private var username: String = ""
    @Environment(\.dismiss) private var dismiss

    private var myReports: [ConditionReport] {
        reportStore.reportsByID.values
            .filter { $0.author == username }
            .sorted { $0.date > $1.date }
    }
    private var allCrags: [Crag] { (try? CragRepository.loadAll()) ?? [] }

    var body: some View {
        NavigationStack {
            Group {
                if myReports.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Palette.textTertiary)
                        Text("No reports yet")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Post your first condition report from any crag detail page.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(myReports) { report in
                                let crag = allCrags.first(where: { $0.id == report.cragID })
                                ReportCard(report: report, crag: crag)
                                    .environmentObject(reportStore)
                            }
                        }
                        .padding(Theme.Metrics.cardPadding)
                    }
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("My Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.tint(Theme.Palette.accent)
                }
            }
        }
    }
}

// MARK: - My Saved Crags sheet

private struct MySavedCragsSheet: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.dismiss) private var dismiss

    private var savedCrags: [Crag] {
        let all = (try? CragRepository.loadAll()) ?? []
        return all.filter { favorites.isFavorite($0) }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if savedCrags.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Palette.textTertiary)
                        Text("No saved crags yet")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Tap the bookmark icon on any crag to save it here.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(savedCrags) { crag in
                                NavigationLink {
                                    CragDetailView(crag: crag, preloaded: nil)
                                } label: {
                                    VStack(alignment: .leading, spacing: 0) {
                                        CragHeroPhotoView(crag: crag, height: 100)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(crag.name)
                                                .font(Theme.Typography.callout).fontWeight(.semibold)
                                                .foregroundStyle(Theme.Palette.textPrimary)
                                                .lineLimit(1)
                                            Text(crag.region)
                                                .font(Theme.Typography.caption)
                                                .foregroundStyle(Theme.Palette.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .padding(10)
                                    }
                                    .background(Theme.Palette.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.Palette.divider, lineWidth: 1))
                                }
                            }
                        }
                        .padding(Theme.Metrics.cardPadding)
                    }
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Saved Crags (\(savedCrags.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.tint(Theme.Palette.accent)
                }
            }
        }
    }
}
