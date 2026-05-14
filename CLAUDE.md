# CodClimb — Project Summary for AI Sessions

## Git workflow (IMPORTANT — follow this every session)
- **Always give commit/push commands for `dev` branch only**
- Frank commits via VSCode terminal, merges dev→main manually via GitHub PR UI
- Xcode Cloud watches `main` and auto-builds on every merge
- **Never tell Frank to run `git pull origin main`** — this risks overwriting dev work
- **Never tell Frank to push directly to `main`**
- The only safe commands to give are:
  ```bash
  git add .
  git commit -m "feat: description of what changed"
  git push origin dev
  ```
- After pushing to dev, Frank goes to github.com/FRFRANk-1/codclimb → Pull requests → merges dev→main in the browser UI
- GitHub repo: https://github.com/FRFRANk-1/codclimb (2 branches: main, dev)
- Team ID: D4G27562RV (Apple Developer — Individual)

## What this app is
CodClimb is an iOS climbing conditions app. It shows live weather-based climbability scores for 123 US crags, lets users post condition reports, save favorite crags, and plan weekend trips. Think "Strava meets Dark Sky for rock climbing."

## Tech stack
- **SwiftUI** (iOS 17+, iPhone 17 simulator on iOS 26.4)
- **Firebase**: Auth (email/password + Google Sign-In + anonymous), Firestore (condition reports), Storage (avatars + report photos)
- **Open-Meteo** free weather API (no key needed) — 7-day hourly forecast + 2-day past data
- **Unsplash API** — dynamic crag photos fetched by crag name
- **GoogleSignIn-iOS** SPM package

## Firebase project
- Project ID: `codclimb-2f37b`
- Bundle ID in GoogleService-Info.plist: `com.codclimb.app`
- Bundle ID in build settings: `com.codclimb.CodClimb` ← potential mismatch to check
- Google OAuth CLIENT_ID: `963343549538-up83m28l2jbfrmek54cevhphgi1qnk6k.apps.googleusercontent.com`
- REVERSED_CLIENT_ID (Info.plist URL scheme): `com.googleusercontent.apps.963343549538-up83m28l2jbfrmek54cevhphgi1qnk6k`

## Key files
| File | Purpose |
|------|---------|
| `CodClimb/CodClimbApp.swift` | App entry, FirebaseApp.configure() |
| `CodClimb/Info.plist` | Manual info plist (replaces GENERATE_INFOPLIST_FILE). Contains URL scheme for Google Sign-In |
| `CodClimb/GoogleService-Info.plist` | Firebase config — has CLIENT_ID + REVERSED_CLIENT_ID (updated May 2026) |
| `Services/FirebaseService.swift` | Auth (anon/email/Google), Firestore reports, Storage uploads. Singleton @MainActor ObservableObject |
| `Services/OpenMeteoClient.swift` | Weather fetch + 30-min disk cache |
| `Services/ScoringService.swift` | Scoring algorithm: temp(30%) + dryness(30%) + humidity(20%) + wind(15%) + cloud(5%) → 0-100 score |
| `Services/ScoringWeights.swift` | Weight struct with .default |
| `Services/UnsplashService.swift` | Fetches crag photos by name from Unsplash |
| `Services/WeatherCacheClient.swift` | Disk cache wrapper for OpenMeteo |
| `Services/CragRepository.swift` | Loads crags.json, provides list |
| `Services/FavoritesStore.swift` | UserDefaults-backed favorites |
| `Services/NotificationService.swift` | Local notifications for crag alerts |
| `Models/Crag.swift` | Crag model + inferredStyle + sunExposure computed props |
| `Models/WeatherSnapshot.swift` | WeatherSnapshot, WeatherBundle, DailySummary, RainWarning |
| `Models/ClimbScore.swift` | ClimbScore + Factor structs |
| `Models/ConditionReport.swift` | Community condition report model |
| `Models/UserProfile.swift` | User profile model |
| `Views/CragListView.swift` | Main list with search, region filter, CragFilter sheet integration |
| `Views/CragDetailView.swift` | Detail: score breakdown, weather, night banner, rain warning, hourly/daily forecast, reports |
| `Views/CragMapView.swift` | Map with lazy per-pin weather loading, score color pins |
| `Views/FavoritesView.swift` | Saved crags + TripPlannerSection (ranks favorites by best Sat/Sun score) |
| `Views/CommunityFeedView.swift` | Recent reports feed, add report |
| `Views/ProfileView.swift` | User profile, saved crags grid, recent reports |
| `Views/AuthView.swift` | Sign in / sign up / Google Sign-In |
| `Views/CragFilterSheet.swift` | Filter by rock type, style, sun exposure, region. Uses FlowLayout chip picker |
| `Views/CragAlertSheet.swift` | Set threshold alerts for a crag |
| `Views/SettingsView.swift` | App settings |
| `Views/OnboardingView.swift` | First-launch onboarding |
| `Views/SplashView.swift` | Animated splash screen |
| `Views/RootTabView.swift` | Tab bar: Explore / Map / Favorites / Community / Profile |
| `Resources/crags.json` | 123 US crags with lat/lon, rock type, aspect, region |

## Architecture decisions made
- `FirebaseService` is `@MainActor final class` singleton, used as `@ObservedObject` in views (NOT `let` — that breaks reactivity)
- Info.plist is MANUAL (not auto-generated). `GENERATE_INFOPLIST_FILE = NO`, `INFOPLIST_FILE = CodClimb/Info.plist`
- `CragFilterSheet.swift` was added to Xcode target via "Add Files to CodClimb" (it had `?` indicator — needed manual target membership)
- Weather scoring uses `hoursSinceLastPrecip` (not `recentRainMm`) from WeatherBundle
- `ScoringService.scoreInt(for:dryHours:)` is a public wrapper added for the trip planner
- Night mode score explanation shown as dark banner inside the score breakdown card in CragDetailView
- Map uses lazy per-pin weather loading via `CragMapViewModel.fetchIfNeeded(for:)`
- `GoogleSignInSwift` target is linked but only `GoogleSignIn` is strictly needed

## App icon
- Old icon: orange game-style climber scene — replaced
- New icon: forest green (#2d5a20) background, bold white mountain peak, green data dots, summit flag
- 1024×1024 PNG saved at: `codclimb/CodClimb-Icon-1024.png`

## Crag images
- Unsplash API fetches photos dynamically by crag name (no local storage needed for most crags)
- User's personal climbing photos registered as Xcode imagesets in Assets.xcassets (Acadia, Farley, Rumney photos)
- Wikimedia Commons links researched for 30 major crags — not downloaded yet. Unsplash is the pragmatic solution for now

## External accounts / services
- Firebase project: codclimb-2f37b (Google Cloud project same name)
- Instagram: @codclimb — Professional account, first post done
- Netlify: frfrank-1 account, has goatclimb01 + personal projects. CodClimb landing page TBD
- Apple Developer Program: enrolled May 2026, purchase processing (up to 48h)
- Domain: codclimb.app available (~$14/yr Namecheap) — not purchased yet

## What's done ✅
- Full crag list with search, region filter, and filter sheet (rock type/style/aspect)
- Crag detail with score breakdown, weather forecast, night mode banner, rain warning
- Map with score-colored pins and lazy weather loading
- Community feed (condition reports with photos)
- Favorites + weekend trip planner
- Auth: anonymous → email/password → Google Sign-In
- Profile page with saved crags, recent reports, bio edit
- Notifications for crag score thresholds
- Onboarding flow
- Splash screen animation
- App icon (new clean version)
- Instagram account set up + first post

## What's next 🔲
1. **Landing page** — build HTML, deploy to Netlify (user has account)
2. **Apple Developer** — wait for processing, then: App Store Connect setup, upload build, TestFlight public link
3. **Profile page improvements** — currently lacks: climbing style/preferences, streak, achievements
4. **Crag images** — Unsplash currently serves most; verify all 123 crags get sensible photos
5. **OAuth consent screen** — Change app name from "project-963343549538" to "CodClimb" in Google Cloud Console
6. **Bundle ID alignment** — GoogleService-Info says `com.codclimb.app`, build settings say `com.codclimb.CodClimb` — verify which Firebase is using
7. **App Store prep** — screenshots, description, privacy policy URL

## Scoring algorithm (reference)
```swift
// Weights: temp 30%, dryness 30%, humidity 20%, wind 15%, cloud 5%
// Ideal temp: 50°F. Dryness: 0 if <2h since rain, 1.0 if >24h
// Humidity: 1.0 if <50%, 0 if >90%
// Wind: best 5-15mph (1.0), worst >30mph (0.1)
// Score 80+: "Send conditions", 60-80: "Solid day", 40-60: "Marginal", <40: "Not worth it"
```
