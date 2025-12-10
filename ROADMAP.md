# PulseTempo Development Roadmap

This document outlines the complete development plan for taking PulseTempo from prototype to production-ready iOS app.

---

## Overview

**Total Timeline:** 13-17 weeks
**Current Status:** Early prototype with simulated heart rate and fake playlist

---

## Product Vision

### Core Concept
PulseTempo is a workout music app that intelligently matches your music to your heart rate in real-time, creating a seamless flow state during runs and workouts.

### How It Works

#### 1. **Run Start**
- User starts a workout session
- App plays either:
  - A random track from selected playlists, OR
  - A user-chosen track
- **Rationale**: User isn't warmed up yet, so BPM matching isn't critical at this stage

#### 2. **During Workout (Continuous BPM Matching)**
- App continuously monitors heart rate via Apple Watch
- As HR changes, app intelligently selects the NEXT track that matches current HR
- **Key Principle**: Never interrupt the currently playing song
- Next track is queued and ready to play when:
  - Current song ends naturally, OR
  - User manually skips forward/backward

#### 3. **Smart Track Selection Algorithm**
When selecting the next track, the app scores each available track using:
- **BPM Match (60% weight)**: How close is the track's BPM to current heart rate?
- **Variety (20% weight)**: Avoid recently played tracks to keep workout fresh
- **Energy (20% weight)**: Match HR zone to appropriate BPM range (e.g., high HR → high-energy tracks)

#### 4. **User Experience Goals**
- ✅ **Non-disruptive**: Songs never cut off mid-play
- ✅ **Predictable**: Users know what to expect
- ✅ **Flow state**: Music adapts to effort without breaking rhythm
- ✅ **User control**: Can skip anytime, or let it play naturally
- ✅ **Intelligent**: Learns from workout patterns and avoids repetition

#### 5. **Future Enhancement: Cadence Matching** 🔮
> **Note**: This feature will be implemented after the core HR-based matching is complete and tested.

- **Concept**: Match music BPM to your running cadence (steps per minute)
- **How it works**:
  - Apple Watch tracks steps per minute during run
  - App selects tracks with BPM matching your cadence
  - Same queue-based, non-disruptive approach as HR matching
- **User choice**: Toggle between HR matching mode or Cadence matching mode
- **Advanced option**: Hybrid mode that considers both HR and cadence
- **Use case**: Runners who want music rhythm to match their footstrike pattern
- **Benefits**:
  - Natural synchronization between movement and music
  - Can help maintain consistent running pace
  - Different workout feel compared to HR-based matching

### Key Differentiators
1. **Queue-based matching** (not mid-song interruption)
2. **Real-time HR monitoring** with Apple Watch integration
3. **Smart scoring algorithm** (not just simple BPM matching)
4. **Workout-aware** (understands warm-up, steady state, cool-down)
5. **Demo mode** for development/testing without Apple Watch
6. **Dual matching modes** (future): HR-based OR Cadence-based matching



---

## **Phase 1: Core iOS Foundation** (2-3 weeks)

### 1.1 Service Layer Architecture

#### HeartRateService
Integrate HealthKit for real heart rate monitoring:
- Request HealthKit permissions
- Set up `HKWorkoutSession` for live workout tracking
- Stream heart rate data via `HKAnchoredObjectQuery`
- Handle Apple Watch connectivity via WatchConnectivity framework
- Implement error handling for missing watch/permissions
- **Add Demo Mode for development without Apple Watch**
  - Simulate realistic workout HR patterns (warm-up, steady, intense, cool-down)
  - Auto-varying HR simulation during workouts
  - Toggle between Demo Mode and Apple Watch Mode
  - Seamless transition when Watch becomes available

**Files to create:**
- `PulseTempo/Services/HeartRateService.swift` ✅
- `PulseTempo/Services/HealthKitManager.swift` ✅

**Files to enhance:**
- `PulseTempo/Services/HeartRateService.swift` - Add demo mode functionality

#### MusicService
Integrate MusicKit for Apple Music control:
- Request MusicKit authorization
- Implement playback control (play, pause, skip)
- Queue management for dynamic track switching
- Fetch user's playlists and track metadata
- Handle now-playing info and playback state

**Files to create:**
- `PulseTempo/Services/MusicService.swift` ✅
- `PulseTempo/Services/MusicKitManager.swift` ✅

### 1.2 Enhanced View Models

**Note:** Demo Mode integration happens here - RunSessionViewModel will use simulated HR until Apple Watch is available.

#### Refactor RunSessionViewModel ✅
- ✅ Connect to HeartRateService for live BPM updates
- ✅ Connect to MusicService for actual playback control
- ✅ Implement smart track selection algorithm (BPM tolerance ±5-10)
- ✅ Add run session state management (notStarted, active, paused, completed)
- ✅ Track run metrics (duration, average HR, max HR, distance)

**Files to update:**
- `PulseTempo/RunSessionViewModel.swift` ✅

**Files to create:**
- `PulseTempo/ViewModels/PlaylistSelectionViewModel.swift` ✅
- `PulseTempo/ViewModels/RunSummaryViewModel.swift` ✅

### 1.3 Additional UI Screens

#### Onboarding Flow
- Welcome screen with app explanation
- **Account creation / Sign in with Apple step** (creates or restores a backend session)
- HealthKit permission request
- Apple Music authorization
- Apple Watch pairing check

**Files to create:**
- `PulseTempo/Views/Onboarding/WelcomeView.swift`
- `PulseTempo/Views/Onboarding/AccountCreationView.swift`
- `PulseTempo/Views/Onboarding/HealthKitPermissionView.swift`
- `PulseTempo/Views/Onboarding/MusicKitPermissionView.swift`
- `PulseTempo/Views/Onboarding/OnboardingCoordinator.swift`

**Backend requirements:**
- FastAPI endpoint for account creation / authentication (JWT issuance, token refresh)
- Secure token storage strategy on iOS (Keychain) coordinated with onboarding state

#### Playlist Selection Screen
- Fetch and display user's Apple Music playlists
- Allow multi-playlist selection
- Show track count and estimated BPM range

**Files to create:**
- `PulseTempo/Views/PlaylistSelectionView.swift`

#### Home Library & Sharing Screen
- Central hub post-onboarding that surfaces the user's Apple Music playlists
- Allow users to select playlists to sync/share with PulseTempo
- Trigger track fetches to populate the in-app experience and prep uploads to backend
- Provide share/export actions (e.g., ShareLink or API call) for selected playlists

**Files to create:**
- `PulseTempo/Views/HomeView.swift`
- `PulseTempo/ViewModels/HomeViewModel.swift` *(or reuse `PlaylistSelectionViewModel` if sufficient)*

#### Run Mode Selection ⏸️ **DEFERRED**
> **Note:** This feature will be implemented after Phase 2 (Backend) is complete, as it's not critical for MVP functionality. The app currently defaults to Steady Tempo mode.

- Choose between Steady Tempo, Progressive Build, Recovery
- Explain each mode's behavior

**Files to create:**
- `PulseTempo/Views/RunModeSelectionView.swift`

#### Run Summary Screen ⏸️ **DEFERRED**
> **Note:** This feature will be implemented after Phase 2 (Backend) is complete, as it requires workout history storage and analytics from the backend.

- Display post-run statistics with charts
- Heart rate graph over time
- List of tracks played during run
- Save run history locally

**Files to create:**
- `PulseTempo/Views/RunSummaryView.swift`
- `PulseTempo/Views/Components/HeartRateChart.swift`

#### Home Screen (Dashboard) ✅ **COMPLETED**
Central hub before starting workouts with key sections:

**1. Quick Start Area**
- Large "Start Workout" button as primary action
- Last workout summary (duration, avg BPM, songs played)
- Estimated workout info (selected playlist count, total songs available)

**2. Playlist Management**
- Selected playlists overview cards showing active playlists
- "Manage Playlists" button to add/remove playlists
- Track count badge (e.g., "142 songs ready for your workout")
- Quick view option to see songs in each playlist

**Files to create:**
- `PulseTempo/Views/HomeView.swift`
- `PulseTempo/ViewModels/HomeViewModel.swift`
- `PulseTempo/Views/Components/PlaylistOverviewCard.swift`

**Navigation Flow:**
```
Home Screen
├─ [Start Workout] → ActiveRunView (workout in progress)
├─ [Manage Playlists] → PlaylistSelectionView (edit selections)
├─ [View Playlist] → PlaylistSongsView (see songs in a playlist)
└─ [Past Workout] → RunSummaryView (workout details)
```

---

## **Phase 1.4: Comprehensive Testing** (1 week) ⚡ **IN PROGRESS - 70% Complete**

> **Critical:** All Phase 1 features must be thoroughly tested before proceeding to Phase 2 (Backend). This ensures a stable foundation for backend integration.

> **Current Status (Dec 4, 2024):** ✅ **66 tests passing** - Core RunSessionViewModel navigation + BPM matching algorithm complete. Service layer tests expanded. Now focusing on remaining service tests and UI tests.

### Testing Strategy

#### Unit Tests
Test individual components and business logic in isolation.

**Service Layer Tests:**
- `HeartRateService` - Mock heart rate data, test monitoring start/stop ✅ COMPLETE (7 tests)
- `MusicService` - Mock MusicKit, test playback controls, queue management ✅ COMPLETE (10 tests)
- `HealthKitManager` - Test authorization flow, permission handling ✅ COMPLETE (4 tests)
- `MusicKitManager` - Test authorization flow ✅ COMPLETE (7 tests)
- `PlaylistStorageManager` - Test save/load/clear operations ✅ COMPLETE (4 tests)

**View Model Tests:**
- `RunSessionViewModel` - ✅ COMPLETE (28 tests total)
  - ✅ Test rapid skip forward/backward scenarios (5 tests)
  - ✅ Test `tracksPlayed` array management
  - ✅ Test `playedTrackIds` set management
  - ✅ Test edge cases (no previous track, end of playlist)
  - ✅ **BPM Matching Algorithm Tests (23 tests)** - NEW!
    - ✅ BPM scoring (perfect match, close, moderate, large differences, missing BPM)
    - ✅ Variety penalties (fresh vs recently played tracks)
    - ✅ Energy zone mapping (low, moderate, high, max intensity)
    - ✅ Track selection (best match, tied scores, pool exhaustion, variety weighting)
    - ✅ Queue updates (initial queue, HR changes, consistent selection, manual skips)
    - ✅ Edge cases (empty lists, single track, missing BPM, extreme HRs)
- `PlaylistSelectionViewModel` - Test playlist fetching, selection logic ⏳ TODO
- `HomeViewModel` - Test playlist loading, track fetching ✅ COMPLETE (3 tests)

**Files created/to create:**
```
PulseTempoTests/
├── Services/
│   ├── HeartRateServiceTests.swift ✅ CREATED
│   ├── MusicServiceTests.swift ✅ CREATED
│   ├── HealthKitManagerTests.swift ✅ CREATED
│   ├── MusicKitManagerTests.swift ✅ CREATED
│   └── PlaylistStorageManagerTests.swift ✅ CREATED
├── ViewModels/
│   ├── RunSessionViewModelTests.swift ✅ CREATED (5 navigation tests)
│   ├── BPMMatchingAlgorithmTests.swift ✅ CREATED (23 BPM algorithm tests)
│   ├── PlaylistSelectionViewModelTests.swift ⏳ TODO
│   └── HomeViewModelTests.swift ✅ CREATED
└── Models/
    └── ModelsTests.swift ⏳ TODO
```

#### Integration Tests
Test how components work together.

**Key Integration Flows:**
- Onboarding flow (Welcome → HealthKit → MusicKit → Playlist Selection → Home) ✅ PARTIAL (1 test)
- Playlist selection and persistence ✅ COMPLETE (2 tests)
- Track fetching and workout initialization ✅ COMPLETE (1 test)
- Music playback and heart rate monitoring coordination ⏳ TODO

**Files created/to create:**
```
PulseTempoTests/Integration/
├── IntegrationFlowTests.swift ✅ CREATED (3 tests: onboarding, workout flow, persistence)
├── OnboardingFlowTests.swift ⏳ TODO (dedicated onboarding tests)
├── PlaylistPersistenceTests.swift ⏳ TODO (dedicated persistence tests)
├── WorkoutFlowTests.swift ⏳ TODO (dedicated workout tests)
└── MusicPlaybackIntegrationTests.swift ⏳ TODO
```

#### UI Tests
Test user interactions and navigation flows.

**Critical User Journeys:**
1. Complete onboarding as new user ⏳ TODO
2. Select playlists and start workout ⏳ TODO
3. Control music playback during workout ⏳ TODO
4. Navigate between screens ⏳ TODO
5. Manage playlist selections from Home ⏳ TODO

**Files to create:**
```
PulseTempoUITests/
├── OnboardingUITests.swift ⏳ TODO
├── HomeScreenUITests.swift ⏳ TODO
├── PlaylistSelectionUITests.swift ⏳ TODO
├── ActiveRunUITests.swift ⏳ TODO
└── NavigationUITests.swift ⏳ TODO
```

#### Manual Testing Checklist

**Onboarding:**
- [ ] Welcome screen displays correctly
- [ ] HealthKit permission request works
- [ ] MusicKit permission request works
- [ ] Playlist selection loads user's playlists
- [ ] Can select/deselect playlists
- [ ] Can view songs in a playlist
- [ ] Continue button saves selections
- [ ] Skip button works at each step
- [ ] Back navigation works correctly

**Home Screen:**
- [ ] Displays selected playlists
- [ ] Shows correct playlist count
- [ ] "Manage Playlists" opens selection view
- [ ] "Start Workout" button fetches tracks
- [ ] Loading state shows while fetching
- [ ] Error handling for failed track fetch
- [ ] Navigation to ActiveRunView works

**Active Run View:**
- [ ] Displays selected track information
- [ ] Heart rate simulation works
- [ ] Play/pause button responds instantly
- [ ] Next track button works
- [ ] Previous track button works
- [ ] Back to Home button works
- [ ] Music playback controls work

**Data Persistence:**
- [ ] Selected playlists persist after app restart
- [ ] Onboarding doesn't repeat after completion
- [ ] Playlist selections survive app updates

**Track Navigation & Playback:**
- [ ] Skip forward works correctly
- [ ] Skip backward works correctly
- [ ] Multiple rapid skip forwards (5+ times)
- [ ] Multiple rapid skip backwards (5+ times)
- [ ] Alternating skip forward/backward rapidly
- [ ] Skip backward at start of workout (no previous track)
- [ ] Skip forward at end of playlist
- [ ] Track history maintains correct order
- [ ] `tracksPlayed` array doesn't grow unbounded
- [ ] `playedTrackIds` set updates correctly
- [ ] No duplicate tracks in history
- [ ] UI updates correctly after each skip

**Edge Cases:**
- [ ] No playlists selected
- [ ] No tracks in selected playlists
- [ ] Network errors during playlist fetch
- [ ] MusicKit authorization denied
- [ ] HealthKit authorization denied
- [ ] App backgrounding during workout

Based on the code, the bugs are probably caused by:

Race conditions - Multiple rapid taps trigger async operations that overlap
Array manipulation issues - skipToPreviousTrack() removes items from tracksPlayed which can cause index errors
State inconsistency - currentTrack, tracksPlayed, and playedTrackIds get out of sync
Recommended Fix Approach
When you write tests, you'll likely need to:

Add debouncing - Prevent rapid button taps from triggering multiple operations
Add guards - Check array bounds before removing items
Synchronize state - Ensure all three data structures update atomically
Add logging - Track state changes for debugging

### Testing Tools & Frameworks

**Recommended:**
- XCTest (built-in)
- Quick/Nimble (BDD-style testing)
- Mockingbird or SwiftyMocky (mocking framework)
- SnapshotTesting (UI regression testing)

### Success Criteria

Before moving to Phase 2, ensure:
- [/] 80%+ code coverage for critical paths (Currently: ~65% estimated - improving!)
- [x] All unit tests passing (66/66 tests passing ✅)
- [x] Critical integration tests passing (3/3 tests passing ✅)
- [ ] All UI tests passing (0 UI tests created yet)
- [ ] Manual testing checklist 100% complete (Not started)
- [x] No critical bugs (Track navigation + BPM algorithm validated ✅)
- [/] Performance is acceptable (BPM selection fast, monitoring in progress)

**Current Progress:** 66 tests passing | ~70% Phase 1.4 complete | BPM matching algorithm fully tested ✅

---

## **Phase 2: Backend Infrastructure** (2-3 weeks)

### 2.1 FastAPI Backend Setup

#### Project Structure
```
backend/
├── alembic/                    # Database migrations
│   ├── versions/
│   └── env.py
├── app/
│   ├── __pycache__/
│   ├── core/                   # Core configuration
│   │   ├── __init__.py
│   │   ├── config.py          # Settings and environment variables
│   │   └── security.py        # JWT and auth utilities
│   ├── crud/                   # CRUD operations
│   │   ├── __init__.py
│   │   ├── crud_track.py
│   │   ├── crud_run.py
│   │   ├── crud_user.py
│   │   └── crud_playlist.py
│   ├── db/                     # Database setup
│   │   ├── __init__.py
│   │   ├── base.py            # Import all models for Alembic
│   │   └── session.py         # Database session management
│   ├── models/                 # SQLAlchemy models
│   │   ├── __init__.py
│   │   ├── track.py
│   │   ├── run.py
│   │   ├── user.py
│   │   └── playlist.py
│   ├── routers/                # API route handlers
│   │   ├── __init__.py
│   │   ├── tracks.py
│   │   ├── runs.py
│   │   ├── bpm.py
│   │   ├── users.py
│   │   └── coach.py
│   ├── schemas/                # Pydantic schemas (request/response)
│   │   ├── __init__.py
│   │   ├── track.py
│   │   ├── run.py
│   │   ├── user.py
│   │   └── playlist.py
│   ├── __init__.py
│   ├── deps.py                 # Dependency injection
│   └── main.py                 # FastAPI app entry point
├── scripts/                    # Utility scripts
│   ├── seed_data.py
│   └── test_bpm_api.py
├── tests/                      # Test suite
│   ├── __init__.py
│   ├── test_tracks.py
│   ├── test_runs.py
│   ├── test_bpm.py
│   └── test_auth.py
├── venv/                       # Virtual environment (gitignored)
├── .env                        # Environment variables (gitignored)
├── .env.example                # Example environment variables
├── alembic.ini                 # Alembic configuration
├── pytest.ini                  # Pytest configuration
├── requirements.txt            # Python dependencies
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### 2.2 Database Schema

**Key Tables:**
- `users` - User accounts and Apple Music IDs
- `tracks` - Track metadata with BPM and confidence scores
- `playlists` - User playlists
- `playlist_tracks` - Many-to-many relationship
- `runs` - Run session summaries
- `run_tracks` - Tracks played during runs with HR data
- `heart_rate_samples` - Detailed HR data for analytics

### 2.3 BPM Service

#### Endpoints
- `POST /api/tracks/register` - Register tracks from Apple Music
- `GET /api/bpm/{track_id}` - Get BPM for a track
- `POST /api/bpm/batch` - Get BPM for multiple tracks

#### BPM Pipeline
1. Check local database cache
2. Query getSongBPM API
3. Query alternative APIs (Spotify, MusicBrainz)
4. Audio analysis fallback (librosa/Essentia)
5. Store results with confidence scores

**Implementation:**
- Exponential backoff for API failures
- Rate limiting for external APIs
- Cache successful results indefinitely
- Background job queue for bulk lookups

### 2.4 Run Analytics

#### Endpoints
- `POST /api/runs` - Save run summary with tracks and HR data
- `GET /api/runs/{user_id}` - Get user's run history
- `GET /api/runs/{run_id}/details` - Get detailed run data
- `GET /api/users/{user_id}/stats` - Get aggregate statistics

### 2.5 Authentication & Account Management

#### Capabilities
- User registration / Sign in with Apple token exchange
- Session issuance (JWT + refresh tokens)
- Secure storage of Apple Music user identifiers and consent timestamps
- Endpoint for validating an existing session during app launch

#### iOS Integration Points
- `AccountCreationView` posts sign-in credentials to FastAPI and stores the returned tokens in Keychain
- `OnboardingCoordinator` checks session validity before advancing to permission steps
- `APIService` refreshes tokens and injects Authorization headers for subsequent requests

---

## **Phase 3: Integration & Refinement** (2 weeks)

### 3.1 iOS-Backend Integration

#### Networking Layer
- Create `APIService` class for backend communication
- Implement JWT authentication
- Handle offline scenarios with local caching
- Sync run data when connection available

**Files to create:**
- `PulseTempo/Services/APIService.swift`
- `PulseTempo/Services/NetworkManager.swift`
- `PulseTempo/Models/API/` - Request/response models

### 3.2 BPM Matching Algorithm

#### Queue-Based Smart Selection Logic

**Core Behavior:**
- **Initial Track**: Random or user-selected track at run start (user not warmed up yet)
- **Continuous Monitoring**: Constantly monitor HR and update next queued track
- **Non-Disruptive**: Only queue next track
- **Transition Points**: Apply BPM-matched track when:
  - Current song ends naturally
  - User manually skips forward
  - User manually skips backward (goes to previous track)

**Smart Selection Logic:**
- Implement track history to avoid repetition
- Add energy/intensity scoring beyond just BPM
- Consider song transitions (avoid jarring changes)
- Update queue in real-time as HR changes during current song

**Scoring Components:**
- BPM Match (60% weight) - Closer to current HR = higher score
- Variety (20% weight) - Penalize recently played tracks
- Energy (20% weight) - Match HR zone to appropriate BPM range

**Files to create:**
- `PulseTempo/Services/TrackSelectionService.swift`

### 3.3 Data Persistence

#### Local Storage
- Use CoreData or SwiftData for offline run history
- Cache track BPM data locally
- Implement sync mechanism with backend

**Files to create:**
- `PulseTempo/Persistence/PersistenceController.swift`
- `PulseTempo/Persistence/PulseTempo.xcdatamodeld`

### 3.4 Settings & Preferences

#### Settings Screen
- BPM matching tolerance adjustment
- Preferred run modes
- Playlist management
- Data sync preferences
- Privacy controls

**Files to create:**
- `PulseTempo/Views/SettingsView.swift`
- `PulseTempo/ViewModels/SettingsViewModel.swift`

---

## **Phase 4: Apple Watch Companion** (2-3 weeks)

### 4.1 watchOS App

#### Watch App Features
- Simplified run view with large HR display
- Current track info
- Basic playback controls
- Run start/stop/pause

**Files to create:**
```
PulseTempoWatch/
├── PulseTempoWatchApp.swift
├── Views/
│   ├── RunView.swift
│   ├── PreRunView.swift
│   └── PostRunView.swift
└── Services/
    └── WatchConnectivityService.swift
```

### 4.2 Watch-iPhone Communication

#### WatchConnectivity
- Real-time HR streaming to iPhone
- Sync run state between devices
- Handle handoff scenarios
- Optimize battery usage

**Files to create:**
- `PulseTempo/Services/WatchConnectivityManager.swift` (iOS)
- `PulseTempoWatch/Services/WatchConnectivityManager.swift` (watchOS)

---

## **Phase 5: AI DJ Feature** (2 weeks)

### 5.1 Backend AI Integration

#### Coach Message Service
- `POST /api/coach/message` - Generate motivational prompts
- Integrate OpenAI API or similar
- Context-aware messages (HR zone, time elapsed, pace)
- Personalization based on user history

**Message Types:**
- Motivation
- Coaching tips
- Milestone celebrations
- Transition prompts
- Recovery reminders

### 5.2 Text-to-Speech

#### iOS Implementation
- Use AVSpeechSynthesizer for voice prompts
- Implement audio ducking (lower music during speech)
- Configurable frequency and style
- Option to disable feature

**Files to create:**
- `PulseTempo/Services/CoachVoiceService.swift`
- `PulseTempo/Services/CoachMessageService.swift`

---

## **Phase 6: Polish & Launch Prep** (2-3 weeks)

### 6.1 Testing

#### Unit Tests
- Service layer tests
- ViewModel logic tests
- BPM matching algorithm tests
- Backend API tests

**Target Coverage:** 70%+ for critical paths

#### Integration Tests
- End-to-end run session flow
- Backend API tests
- Watch-iPhone communication tests

#### UI Tests
- Critical user flows
- Permission handling
- Error scenarios

### 6.2 Performance Optimization

#### Battery Optimization
- Efficient HealthKit queries
- Minimize background processing
- Optimize network calls

**Target:** <10% battery drain per hour

#### Responsiveness
- 60 FPS animations
- Fast track switching (<500ms)
- Minimal latency in HR updates (<2s)
- Backend API response time <200ms (p95)

### 6.3 App Store Preparation

#### Assets & Metadata
- App icon (1024x1024 + all sizes)
- Screenshots (all required device sizes)
- App preview video (30 seconds)
- App Store description and keywords
- Privacy policy
- Terms of service

#### Compliance
- HealthKit usage description
- MusicKit entitlements
- Background modes configuration
- TestFlight beta testing

**Info.plist Requirements:**
```xml
<key>NSHealthShareUsageDescription</key>
<string>PulseTempo needs access to your heart rate data to match music to your workout intensity.</string>

<key>NSAppleMusicUsageDescription</key>
<string>PulseTempo needs access to Apple Music to play and control your workout music.</string>
```

---

## **Phase 7: Post-Launch** (Ongoing)

### 7.1 Analytics & Monitoring
- Track user engagement metrics
- Monitor backend performance
- Crash reporting and error tracking

### 7.2 Feature Enhancements

#### Cadence Matching Mode (Priority #1)
**Timeline:** 2-3 weeks post-launch
**Implementation:**
- Add cadence tracking via Apple Watch pedometer data
- Create `CadenceService` to monitor steps per minute
- Extend BPM matching algorithm to work with cadence instead of HR
- Add settings toggle: "Match music to: Heart Rate / Cadence / Hybrid"
- Update `RunSessionViewModel` to support multiple matching modes
- Test cadence accuracy across different running speeds
**User Flow:**
- Settings screen: Choose matching mode (HR, Cadence, or Hybrid)
- During run: App matches track BPM to current cadence (e.g., 180 SPM → 180 BPM track)
- Same queue-based approach: never interrupt current song
- Display both HR and cadence metrics on run screen
**Files to create:**
- `PulseTempo/Services/CadenceService.swift`
- `PulseTempo/Models/MatchingMode.swift`
- Update `RunSessionViewModel` with mode switching logic
**Success Metrics:**
- Cadence tracking accuracy within ±2 SPM
- Smooth mode switching without disrupting playback
- User preference data (which mode is most popular)

#### Other Enhancements
- Spotify integration
- Social features (share runs)
- Custom workout programs
- Advanced analytics dashboard
- Integration with other fitness apps

### 7.3 Community & Feedback
- User feedback collection
- Bug fixes and improvements
- Regular updates

---

## Technical Priorities by Phase

| Phase | iOS Focus | Backend Focus | Priority |
|-------|-----------|---------------|----------|
| 1 | HealthKit + MusicKit | — | Critical |
| 2 | API integration prep | FastAPI + DB + BPM service | Critical |
| 3 | Full integration | Run analytics | Critical |
| 4 | watchOS app | — | High |
| 5 | TTS integration | AI DJ service | Medium |
| 6 | Testing & polish | Performance tuning | Critical |
| 7 | New features | Scaling | Ongoing |

---

## Immediate Next Steps

1. ✅ **HeartRateService** - Core differentiator (COMPLETED)
2. ✅ **Integrate MusicKit** - Essential for actual music control (COMPLETED)
3. 🔄 **Add Demo Mode to HeartRateService** - Enable development without Apple Watch (IN PROGRESS)
4. **Integrate services with RunSessionViewModel** - Connect HR and Music services
5. **Build playlist selection UI** - Users need to choose music sources
6. **Set up FastAPI backend skeleton** - Get infrastructure ready early
7. **Implement BPM lookup** - Critical for matching algorithm

---

## External Dependencies

### APIs & Services
- **Apple HealthKit** - Heart rate monitoring
- **Apple MusicKit** - Music playback and library access
- **getSongBPM API** - BPM lookup service
- **OpenAI API** - AI DJ voice prompts (Phase 5)
- **PostgreSQL** - Backend database
- **Redis** - Caching layer (optional but recommended)

### Development Tools
- **Xcode** - iOS/watchOS development
- **Docker** - Backend containerization
- **Alembic** - Database migrations
- **pytest** - Backend testing
- **XCTest** - iOS testing

---

## Success Metrics

### Phase 1-3 (MVP)
- ✅ Real heart rate monitoring working
- ✅ Music playback controlled by app
- ✅ BPM matching algorithm functional
- ✅ Run sessions saved and viewable

### Phase 4-6 (Full Launch)
- ✅ Apple Watch app working seamlessly
- ✅ AI DJ prompts enhancing experience
- ✅ App Store approved and live
- ✅ <5% crash rate
- ✅ 4+ star rating

### Post-Launch
- 1,000+ downloads in first month
- 60%+ user retention after 7 days
- 40%+ user retention after 30 days
- Positive user reviews highlighting BPM matching

---

## Demo Mode Strategy (No Apple Watch)

**Context:** Development is proceeding without Apple Watch hardware (arriving in a few weeks).

### Implementation Approach

**Phase 1A: Demo Mode Development** (Current)
- Enhance HeartRateService with realistic HR simulation
- Implement workout pattern simulation:
  - Warm-up phase: 100-120 BPM (gradual increase)
  - Steady state: 140-150 BPM (slight variations)
  - Intense intervals: 160-175 BPM (peaks)
  - Cool-down: 120-100 BPM (gradual decrease)
- Add settings toggle for Demo Mode vs. Apple Watch Mode
- Build and test entire app with simulated data

**Phase 1B: Apple Watch Integration** (When hardware arrives)
- Test real HealthKit integration
- Validate HR accuracy and responsiveness
- Compare demo patterns vs. real workout data
- Fine-tune BPM matching algorithm with real data
- Keep demo mode for users without Watch

### Benefits of This Approach

✅ **Continue Development** - No blocked work while waiting for Watch
✅ **Test BPM Matching** - Validate track selection algorithm
✅ **Build Complete UI** - All screens and flows can be implemented
✅ **Demo Ready** - Show app to users/investors without Watch
✅ **Future-Proof** - Easy toggle when Watch arrives
✅ **Broader Audience** - Support users without Watch (with manual input)

### Demo Mode Features

1. **Realistic Simulation**
   - Time-based HR progression
   - Natural variation (±3-5 BPM)
   - Workout phase detection
   
2. **Manual Override**
   - User can adjust simulated HR
   - Useful for testing specific BPM ranges
   
3. **Settings Integration**
   - Clear indicator when in Demo Mode
   - Easy switch to Watch mode
   - Persist user preference

---

## Notes

- **Start small**: Focus on core BPM matching before adding AI DJ
- **Test early**: Get real runners testing as soon as Phase 3 is complete
- **Battery matters**: Optimize for battery life throughout development
- **Privacy first**: Be transparent about data collection and usage
- **Iterate quickly**: Use TestFlight feedback to prioritize features
- **Demo Mode**: Enables full development without Apple Watch hardware

---

**Last Updated:** December 4, 2024  
**Version:** 1.3 - Phase 1.4 testing progress: 66 tests passing, BPM matching algorithm fully tested (23 new tests), service layer tests complete
