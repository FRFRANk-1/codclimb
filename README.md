# CodClimb

iOS climbing-conditions app. Pulls live weather + 48h forecast from Open-Meteo, computes a 0–100 climbability score, shows a "best window in the next 48 hours" suggestion. Inspired by climbitscore and the RumneyPulse reference.

## Run it

1. **Install Xcode** (App Store, ~14 GB). Command Line Tools alone won't open `.xcodeproj` files.
2. Open `CodClimb.xcodeproj` in Xcode.
3. Pick an iOS 17+ simulator (e.g. iPhone 15) and hit Cmd+R.
4. No API keys, no signing config required for the simulator.

If you want to run on a physical device, set your team in **CodClimb target → Signing & Capabilities** and change the bundle id from `com.codclimb.CodClimb` to something unique.

## Layout

```
CodClimb/
  CodClimbApp.swift          @main
  Models/
    Crag.swift               curated crag struct (lat/lng, rock type, aspect, sub-areas)
    WeatherSnapshot.swift    one weather point + bundle wrapper
    ClimbScore.swift         0–100 score + per-factor breakdown
  Services/
    OpenMeteoClient.swift    fetches /v1/forecast with past_days=2
    ScoringService.swift     weighted heuristic (temp, dryness, humidity, wind, cloud)
    CragRepository.swift     loads crags.json from bundle
  Theme/
    Theme.swift              colors, fonts, metrics — single source of truth
  Views/
    CragListView.swift       home: hero + feature chips + crag cards
    CragDetailView.swift     score badge, stats grid, best-window, breakdown, hourly
    Components/
      ScoreBadgeView.swift   circular progress score
      StatTile.swift         tile for current conditions
      HourlyForecastView.swift  horizontal scroll of next 24 hours
      FactorRow.swift        one row in the score breakdown
  Resources/
    crags.json               5 NH crags to start: Rumney Main, Waimea, Cathedral, Cannon, Pawtuckaway
  Assets.xcassets            AppIcon + AccentColor (sage)
```

## Scoring weights

Lives in `ScoringService.swift` → `ScoringWeights`. Defaults:

- Temperature 30% — bell curve peaking near 50°F
- Dryness 30% — hours since last ≥0.01" precipitation
- Humidity 20%
- Wind 15%
- Cloud cover 5% (and the polarity flips above 75°F / below 35°F)

Tuning is one struct edit.

## Adding crags

Edit `CodClimb/Resources/crags.json`. Required fields: `id`, `name`, `region`, `latitude`, `longitude`, `elevationFt`, `rockType`, `aspect`, `subAreas`, `notes`.

## Swap palette

Edit `CodClimb/Theme/Theme.swift` and `CodClimb/Assets.xcassets/AccentColor.colorset/Contents.json`. The current accent (`#7A9B76`, sage) is set in two places — both need to change for full consistency.

## Deferred (not in MVP)

- Auth, accounts
- Community feed (alive feed / route logs / photos)
- Push notifications for "perfect window incoming"
- Map view of crags
- Web app (separate React/Next.js project later)
