# PulseTempo

PulseTempo is an iOS app (SwiftUI) that matches your workout music to your heart rate using Apple Watch and Apple Music.

The core idea:

- While you run, PulseTempo reads live heart-rate data.
- It chooses songs whose BPM (beats per minute) is close to your current heart rate.
- As your heart rate changes, the app updates the music queue so tracks stay in sync with your effort.
- Long-term, the app will also provide short "AI DJ" voice prompts between songs.

> **Status:** Early prototype. Right now the app shows a single “Active Run” screen with:
> - A simulated heart-rate value that changes over time  
> - A fake playlist  
> - Basic “skip” / “play-pause” logic driven by a view model  

---

## Tech Stack

### Frontend (current)

- **Platform:** iOS (SwiftUI)
- **Language:** Swift
- **Architecture (planned):**
  - SwiftUI views
  - ObservableObject view models
  - Service layer for HealthKit, MusicKit, WatchConnectivity, and networking

### Backend (planned)

- **API framework:** FastAPI (Python)
- **DB:** Postgres (or compatible)
- **Responsibilities:**
  - Look up or estimate BPM for songs
  - Store user playlists / track metadata (IDs, BPM, etc.)
  - Store run summaries & analytics
  - Optionally generate AI DJ text snippets

### External Services (planned / exploratory)

- **Apple Music / MusicKit API** – to identify tracks and access metadata.
- **getSongBPM API** – to look up BPM for tracks based on name/artist or other identifiers.  
  - Backend will likely call this API (or similar) given track metadata and cache the result.
- Optional: audio analysis libraries (e.g., Essentia / librosa) for BPM detection when no external BPM is available.

---

## High-Level Architecture

**On-device (iOS / watchOS)**

- `HeartRateService` (planned): Streams live BPM from Apple Watch using HealthKit and HKWorkoutSession.
- `MusicService` (planned): Controls playback using MusicKit (playlists, queue, now-playing info).
- `RunSessionViewModel` (in progress):
  - Holds the current run mode (steady tempo / progressive build / recovery).
  - Manages the current playlist and current track.
  - Chooses the next track based on the user’s approximate heart rate and each track’s BPM.
- SwiftUI views:
  - `ActiveRunView` (current): big BPM display, current song card, transport controls, “next track queued” pill.
  - Future screens: onboarding, connect Apple Music, choose playlists, run summary, settings.

**Backend (FastAPI)**

- Endpoints (planned, not implemented yet):
  - `POST /tracks/register` – register a set of tracks by Apple Music ID / metadata.
  - `GET /bpm` – return a map of `{ track_id: bpm }` for requested tracks, querying cache + external BPM sources if necessary.
  - `POST /runs` – store run summaries.
  - `GET /coach-message` – optional: return short text for AI DJ prompts.

- BPM pipeline (planned):
  1. Receive track metadata from the app.
  2. Try to get BPM from cache.
  3. If missing, query **getSongBPM API** or other sources.
  4. Optionally fall back to audio analysis of previews.
  5. Store BPM + confidence in the database.

---

## Repo Structure

_Current / target layout:_

```text
PulseTempo/
  PulseTempo/           # iOS app code (Xcode project target)
    PulseTempoApp.swift # App entry point
    ContentView.swift   # Currently contains ActiveRunView
    Models.swift        # (if created) Track, Playlist, RunMode
    RunSessionViewModel.swift
    Assets.xcassets
  PulseTempoTests/
  PulseTempoUITests/
  README.md
  # backend/           # (planned) FastAPI backend will live here later

Will Evolve into / target layout:_

```text
pulsetempo/
  ios/                 # SwiftUI app + watchOS companion (future)
  backend/             # FastAPI app, BPM workers, DB migrations
  README.md
