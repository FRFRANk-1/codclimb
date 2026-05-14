# CodClimb

A native iOS climbing-conditions app that pulls live weather from [Open-Meteo](https://open-meteo.com), computes a 0–100 climbability score for 123 curated crags across the US, and helps climbers find the best window to get on rock.

> Built with SwiftUI · Firebase · Open-Meteo · Unsplash API

---

## Screenshots

<!-- Add simulator screenshots here once you have them -->

---

## Features

**Explore**
- 123 crags across the US with live weather scores (0–100 climbability)
- Per-factor score breakdown: temperature, dryness, humidity, wind, cloud cover
- Best climbing window in the next 48 hours
- 24-hour hourly forecast strip + 7-day daily summary
- Rain warning banner with hours until next rain
- Night mode — score card and breakdown adapt after sunset with tomorrow's context

**Map**
- Full-screen MapKit view of all 123 crags as score-colored pins
- Pins load weather lazily (disk-cached, no rate-limit risk)
- Tap any pin to open the crag detail sheet
- Search bar to filter and fly to a crag by name, state, or rock type
- Zoom +/− controls + user location button

**Favorites**
- Bookmark any crag with one tap
- Favorites list with live scores
- "Discover Climbing Areas" — curated iconic destinations with photos and beta

**Community**
- Global condition report feed (last 7 days)
- Post reports with rock condition, crowd level, notes, and a photo
- Thumbs-up reactions
- Tap any report card to open a detail sheet with the poster's profile and other reports
- Sign-up gate for guests (first 3 reports visible; sign in to see all)

**Profile**
- Firebase Email/Password auth (sign in, sign up, forgot password)
- Password reveal toggle
- Public profile sheets: avatar, report count, recent reports
- Condition alert emails — get notified when a saved crag hits your score threshold

**Onboarding & Splash**
- Animated splash screen with custom canvas climber
- 3-slide onboarding with hero photo backgrounds

---

## Tech Stack

| Layer | Detail |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Auth | Firebase Authentication (Email/Password) |
| Database | Firebase Firestore (condition reports, user profiles) |
| Storage | Firebase Storage (report photos) |
| Weather | Open-Meteo `/v1/forecast` — free, no key required |
| Photos | Unsplash API (crag hero images with required attribution) |
| Caching | 30-min disk cache on weather responses (`FileManager.cachesDirectory`) |
| Maps | MapKit (`Map` + `MapAnnotation`) |

---

## Run It Locally

1. **Install Xcode** (App Store, ~14 GB)
2. Clone the repo:
   ```bash
   git clone https://github.com/FRFRANk-1/codclimb.git
   cd codclimb
   ```
3. Open `CodClimb.xcodeproj` in Xcode
4. Pick an iOS 17+ simulator (iPhone 15 or later) and hit `Cmd+R`

**No API key is needed for weather** — Open-Meteo is free and open.

**For Unsplash photos:** add your Access Key to `UnsplashService.swift`. Without it, the app falls back to bundled local climbing photos (Frank's personal shots) and still looks great.

**For Firebase:** the `GoogleService-Info.plist` is gitignored. To enable auth and community features, create a Firebase project, enable Email/Password auth and Firestore, and drop in your own plist. Without it, community features gracefully degrade.

**Running on a physical device:** set your team in `CodClimb target → Signing & Capabilities` and use a unique bundle ID.

---

## Project Structure

```
CodClimb/
├── CodClimbApp.swift              @main — sets up environment objects
├── Models/
│   ├── Crag.swift                 Crag struct (lat/lng, rock type, aspect, sub-areas)
│   ├── WeatherSnapshot.swift      Single weather point + WeatherBundle wrapper
│   ├── ClimbScore.swift           0–100 score + per-factor breakdown
│   └── ConditionReport.swift      Community report model
├── Services/
│   ├── OpenMeteoClient.swift      Weather fetch + 30-min disk cache
│   ├── ScoringService.swift       Weighted scoring heuristic
│   ├── CragRepository.swift       Loads crags.json from bundle
│   ├── FirebaseService.swift      Auth + Firestore + Storage
│   ├── UnsplashService.swift      Crag hero photo search + attribution
│   ├── PhotoLibrary.swift         Local photo assets + CragHeroPhotoView
│   └── SolarCalculator.swift      Sunrise/sunset times for night mode
├── Stores/
│   ├── FavoritesStore.swift       Bookmarked crag IDs (@AppStorage)
│   ├── ConditionReportStore.swift Firestore-backed community reports
│   ├── UserProfileStore.swift     Firebase user profiles
│   └── NotificationService.swift  Local alert scheduling
├── Theme/
│   └── Theme.swift                Colors, fonts, metrics — single source of truth
├── Views/
│   ├── CragListView.swift         Explore tab — crag cards with live scores
│   ├── CragDetailView.swift       Score badge, breakdown, forecast, reports
│   ├── CragMapView.swift          Map tab — lazy-loading score pins
│   ├── FavoritesView.swift        Favorites + Discover section
│   ├── CommunityFeedView.swift    Reports feed + submit + detail sheets
│   ├── ProfileView.swift          User profile + public profile sheets
│   ├── AuthView.swift             Sign in / Sign up / Forgot password
│   ├── SplashView.swift           Animated canvas splash screen
│   ├── OnboardingView.swift       3-slide onboarding
│   └── Components/
│       ├── ScoreBadgeView.swift   Circular progress score badge
│       ├── StatTile.swift         Current conditions tile
│       ├── FactorRow.swift        Score breakdown row with progress bar
│       ├── HourlyForecastView.swift  24-hour horizontal forecast scroll
│       └── DailyForecastView.swift   7-day forecast
└── Resources/
    └── crags.json                 123 US crags with coordinates, rock type, sub-areas
```

---

## Scoring Model

Defined in `ScoringService.swift → ScoringWeights`. Weights:

| Factor | Weight | Notes |
|---|---|---|
| Temperature | 30% | Bell curve peaking ~50–60°F; penalizes <35°F and >80°F |
| Dryness | 30% | Hours since last ≥0.01" precipitation |
| Humidity | 20% | Linear penalty above 70% |
| Wind | 15% | Sweet spot 5–15 mph; penalizes calm (sweaty) and gusty |
| Cloud cover | 5% | Polarity flips: clouds help on hot days, hurt on cold days |

Score is multiplied by a **night penalty** after sunset (displayed, not hidden).

---

## Adding Crags

Edit `CodClimb/Resources/crags.json`. Required fields:

```json
{
  "id": "your-crag-id",
  "name": "Crag Name",
  "region": "State, Country",
  "latitude": 44.0,
  "longitude": -71.0,
  "elevationFt": 1200,
  "rockType": "Granite",
  "aspect": "South",
  "subAreas": ["Main Wall", "Upper Tier"],
  "notes": "Classic single-pitch trad and sport."
}
```

To assign a local hero photo to a new crag, add an entry to `cragPhotoMap` in `PhotoLibrary.swift`.

---

## Rate Limits

Open-Meteo free tier: **10,000 requests/day per IP.** The app uses `LazyVStack` so only visible crag cards trigger weather fetches, and all responses are cached to disk for 30 minutes. In production, each user has their own IP so the limit effectively doesn't apply.

---

## License

MIT — see `LICENSE` file.

Photos by Frank Li (personal climbing shots). Unsplash photos comply with the [Unsplash API guidelines](https://unsplash.com/api-terms) — photos are hotlinked and attribution is displayed in-app.
