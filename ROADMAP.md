# PulseTempo Development Roadmap

This document outlines the complete development plan for taking PulseTempo from prototype to production-ready iOS app.

---

## Overview

**Total Timeline:** 13-17 weeks
**Current Status:** Early prototype with simulated heart rate and fake playlist

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
- HealthKit permission request
- Apple Music authorization
- Apple Watch pairing check

**Files to create:**
- `PulseTempo/Views/Onboarding/WelcomeView.swift`
- `PulseTempo/Views/Onboarding/HealthKitPermissionView.swift`
- `PulseTempo/Views/Onboarding/MusicKitPermissionView.swift`
- `PulseTempo/Views/Onboarding/OnboardingCoordinator.swift`

#### Playlist Selection Screen
- Fetch and display user's Apple Music playlists
- Allow multi-playlist selection
- Show track count and estimated BPM range

**Files to create:**
- `PulseTempo/Views/PlaylistSelectionView.swift`

#### Run Mode Selection
- Choose between Steady Tempo, Progressive Build, Recovery
- Explain each mode's behavior

**Files to create:**
- `PulseTempo/Views/RunModeSelectionView.swift`

#### Run Summary Screen
- Display post-run statistics with charts
- Heart rate graph over time
- List of tracks played during run
- Save run history locally

**Files to create:**
- `PulseTempo/Views/RunSummaryView.swift`
- `PulseTempo/Views/Components/HeartRateChart.swift`

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

#### Smart Selection Logic
- Define BPM tolerance ranges based on run mode
- Implement track history to avoid repetition
- Add energy/intensity scoring beyond just BPM
- Consider song transitions (avoid jarring changes)

**Scoring Components:**
- BPM Match (60% weight)
- Variety (20% weight)
- Energy (20% weight)

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

**Last Updated:** November 5, 2025
**Version:** 1.1 - Added Demo Mode strategy for development without Apple Watch
