# MusicKit Setup Guide for PulseTempo

This guide walks you through configuring MusicKit for the PulseTempo app.

## Files Created

✅ **Services/MusicKitManager.swift** - Manages MusicKit authorization and subscription status
✅ **Services/MusicService.swift** - Controls music playback, queue management, and playlist access

## Required Xcode Configuration

### 1. Add MusicKit Framework

**Note:** MusicKit is NOT a capability - it's a framework you link to your project.

1. Open `PulseTempo.xcodeproj` in Xcode
2. Select the **PulseTempo** target
3. Go to the **General** tab
4. Scroll to **Frameworks, Libraries, and Embedded Content**
5. Click the **+** button
6. Search for `MusicKit.framework`
7. Add it (set to "Do Not Embed")

### 2. Add Privacy Usage Description

1. Select the **PulseTempo** target
2. Go to the **Info** tab
3. Add the following key-value pair:
   - **Key:** `Privacy - Media Library Usage Description` (or `NSAppleMusicUsageDescription`)
   - **Value:** `PulseTempo needs access to Apple Music to play and control your workout music.`

Alternatively, if you have an Info.plist file, add this:

```xml
<key>NSAppleMusicUsageDescription</key>
<string>PulseTempo needs access to Apple Music to play and control your workout music.</string>
```

### 3. That's It! 🎉

You're done with the basic setup. No entitlements file or Developer Portal configuration needed for development.

**Note:** Developer Portal configuration is only required when:
- Publishing to the App Store
- Using server-side MusicKit API
- Accessing advanced MusicKit features

For local development and testing, the framework + privacy description is all you need.

## Architecture Overview

### MusicKitManager

**Purpose:** Handles authorization and subscription management

**Key Methods:**
- `requestAuthorization()` - Request user permission to access Apple Music
- `authorizationStatus` - Check current authorization status
- `checkSubscriptionStatus()` - Verify if user has active Apple Music subscription
- `presentSubscriptionOffer()` - Show subscription offer to non-subscribers

**Usage Example:**
```swift
// Request authorization
await MusicKitManager.shared.requestAuthorization { status in
    if status == .authorized {
        print("User authorized Apple Music access")
    }
}

// Check subscription
let hasSubscription = await MusicKitManager.shared.checkSubscriptionStatus()
```

### MusicService

**Purpose:** Manages all music playback and library operations

**Published Properties:**
- `currentTrack: Track?` - Currently playing track
- `playbackState: PlaybackState` - Current playback state (.playing, .paused, .stopped)
- `currentPlaybackTime: TimeInterval` - Current position in track
- `userPlaylists: [MusicPlaylist]` - User's Apple Music playlists
- `isLoading: Bool` - Loading state for async operations
- `error: Error?` - Any errors that occurred

**Key Methods:**

#### Playback Control
- `play(track:)` - Play a single track
- `playQueue(tracks:startIndex:)` - Play a queue of tracks
- `pause()` - Pause playback
- `resume()` - Resume playback
- `stop()` - Stop playback completely
- `skipToNext()` - Skip to next track
- `skipToPrevious()` - Skip to previous track
- `seek(to:)` - Seek to specific time

#### Queue Management
- `addToQueue(track:)` - Add track to end of queue
- `playNext(track:)` - Insert track to play next
- `clearQueue()` - Clear the playback queue

#### Library Access
- `fetchUserPlaylists()` - Get user's playlists
- `fetchTracksFromPlaylist(playlistId:)` - Get tracks from a playlist

## Usage Examples

### 1. Request Authorization

```swift
import SwiftUI

struct OnboardingView: View {
    @State private var authStatus: String = "Not Requested"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Apple Music Access")
                .font(.title)
            
            Text(authStatus)
                .foregroundColor(.secondary)
            
            Button("Request Authorization") {
                Task {
                    await MusicKitManager.shared.requestAuthorization { status in
                        switch status {
                        case .authorized:
                            authStatus = "Authorized ✓"
                        case .denied:
                            authStatus = "Denied ✗"
                        case .notDetermined:
                            authStatus = "Not Determined"
                        case .restricted:
                            authStatus = "Restricted"
                        @unknown default:
                            authStatus = "Unknown"
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

### 2. Play Music

```swift
import SwiftUI

struct MusicPlayerView: View {
    @StateObject private var musicService = MusicService()
    
    var body: some View {
        VStack(spacing: 20) {
            // Current track display
            if let track = musicService.currentTrack {
                VStack {
                    Text(track.title)
                        .font(.title2)
                        .bold()
                    
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No track playing")
                    .foregroundColor(.secondary)
            }
            
            // Playback controls
            HStack(spacing: 30) {
                Button(action: { musicService.skipToPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                
                Button(action: {
                    if musicService.playbackState == .playing {
                        musicService.pause()
                    } else {
                        musicService.resume()
                    }
                }) {
                    Image(systemName: musicService.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                
                Button(action: { musicService.skipToNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            
            // Play a sample track
            Button("Play Sample Track") {
                let sampleTrack = Track(
                    id: "sample",
                    title: "Eye of the Tiger",
                    artist: "Survivor",
                    durationSeconds: 245,
                    bpm: 109
                )
                
                musicService.play(track: sampleTrack) { result in
                    switch result {
                    case .success:
                        print("Playback started")
                    case .failure(let error):
                        print("Playback failed: \(error)")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
```

### 3. Fetch and Display Playlists

```swift
import SwiftUI

struct PlaylistSelectionView: View {
    @StateObject private var musicService = MusicService()
    
    var body: some View {
        NavigationView {
            Group {
                if musicService.isLoading {
                    ProgressView("Loading playlists...")
                } else if musicService.userPlaylists.isEmpty {
                    VStack {
                        Text("No playlists found")
                            .foregroundColor(.secondary)
                        
                        Button("Fetch Playlists") {
                            fetchPlaylists()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(musicService.userPlaylists) { playlist in
                        HStack {
                            // Playlist artwork
                            if let artwork = playlist.artwork {
                                ArtworkImage(artwork, width: 50, height: 50)
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                    .font(.headline)
                                
                                Text("\(playlist.trackCount) tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Playlists")
            .onAppear {
                if musicService.userPlaylists.isEmpty {
                    fetchPlaylists()
                }
            }
        }
    }
    
    private func fetchPlaylists() {
        musicService.fetchUserPlaylists { result in
            switch result {
            case .success(let playlists):
                print("Fetched \(playlists.count) playlists")
            case .failure(let error):
                print("Failed to fetch playlists: \(error)")
            }
        }
    }
}
```

### 4. Integration with RunSessionViewModel

```swift
import SwiftUI
import Combine

final class RunSessionViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTrack: Track?
    
    // Services
    private let heartRateService = HeartRateService()
    private let musicService = MusicService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe music service current track
        musicService.$currentTrack
            .assign(to: &$currentTrack)
        
        // Observe music playback state
        musicService.$playbackState
            .map { $0 == .playing }
            .assign(to: &$isPlaying)
        
        // Observe heart rate changes and select appropriate music
        heartRateService.$currentHeartRate
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] heartRate in
                self?.selectTrackForHeartRate(heartRate)
            }
            .store(in: &cancellables)
    }
    
    func startRun() {
        // Start heart rate monitoring
        heartRateService.startMonitoring { result in
            switch result {
            case .success:
                print("Heart rate monitoring started")
            case .failure(let error):
                print("Failed to start monitoring: \(error)")
            }
        }
        
        // Start music playback
        // (You'd select tracks based on BPM here)
    }
    
    func stopRun() {
        heartRateService.stopMonitoring()
        musicService.stop()
    }
    
    private func selectTrackForHeartRate(_ heartRate: Int) {
        // Logic to select track based on heart rate
        // This will be enhanced with BPM matching algorithm
        print("Heart rate: \(heartRate) BPM")
    }
}
```

## Testing

### Simulator Testing

MusicKit works in the iOS Simulator, but you need:

1. **Apple Music Subscription** - You need an active subscription
2. **Signed in to Apple ID** - Sign in via Settings app in simulator
3. **Music Library** - Add some songs to your library via the Music app

For testing without a subscription, use the `simulatePlayback()` debug method:

```swift
#if DEBUG
musicService.simulatePlayback(track: sampleTrack)
#endif
```

### Real Device Testing

1. Ensure your device is signed in with an Apple ID
2. Have an active Apple Music subscription
3. Have some playlists in your library
4. Run the app and grant permissions

## Important Notes

### Subscription Requirements

- **Full Playback:** Requires active Apple Music subscription
- **30-Second Previews:** Available without subscription
- **Library Access:** Requires subscription

Always check subscription status before attempting full playback:

```swift
let hasSubscription = await MusicKitManager.shared.checkSubscriptionStatus()
if !hasSubscription {
    // Show subscription offer
    await MusicKitManager.shared.presentSubscriptionOffer()
}
```

### Search Limitations

The current implementation searches for tracks by title and artist. This works well but has limitations:

- **Exact Matches:** May not find exact track if title/artist don't match perfectly
- **Multiple Versions:** May return different version than expected (live, remix, etc.)

**Future Enhancement:** Store Apple Music track IDs when fetching playlists to enable direct playback without search.

### Background Playback

To enable music playback in the background:

1. Go to **Signing & Capabilities**
2. Add **Background Modes** capability
3. Enable **Audio, AirPlay, and Picture in Picture**

### Rate Limiting

Apple Music API has rate limits. For production:

- Cache playlist data locally
- Implement retry logic with exponential backoff
- Handle rate limit errors gracefully

## Troubleshooting

### "Authorization Denied"
- User needs to grant permission in Settings → Privacy → Media & Apple Music
- Guide users to enable permissions if initially denied

### "No Subscription"
- User needs an active Apple Music subscription for full playback
- Present subscription offer using `presentSubscriptionOffer()`

### "Track Not Found"
- The search couldn't find the track in Apple Music catalog
- Verify track title and artist are correct
- Consider using Apple Music track IDs instead of search

### Build Errors
- Ensure MusicKit capability is added in Xcode
- Verify capability is enabled in Apple Developer Portal
- Check that privacy usage description is added
- Make sure you're using iOS 15.0+ (MusicKit minimum version)

## API Reference

### MusicKitManager

```swift
class MusicKitManager {
    static let shared: MusicKitManager
    
    func requestAuthorization(completion: @escaping (MusicAuthorization.Status) -> Void)
    var authorizationStatus: MusicAuthorization.Status { get }
    var isAuthorized: Bool { get }
    func checkSubscriptionStatus() async -> Bool
    func presentSubscriptionOffer(options: MusicSubscriptionOffer.Options) async
}
```

### MusicService

```swift
class MusicService: ObservableObject {
    @Published var currentTrack: Track?
    @Published var playbackState: PlaybackState
    @Published var currentPlaybackTime: TimeInterval
    @Published var error: Error?
    @Published var userPlaylists: [MusicPlaylist]
    @Published var isLoading: Bool
    
    // Playback Control
    func play(track: Track, completion: @escaping (Result<Void, Error>) -> Void)
    func playQueue(tracks: [Track], startIndex: Int, completion: @escaping (Result<Void, Error>) -> Void)
    func pause()
    func resume()
    func stop()
    func skipToNext()
    func skipToPrevious()
    func seek(to time: TimeInterval)
    
    // Queue Management
    func addToQueue(track: Track)
    func playNext(track: Track)
    func clearQueue()
    
    // Library Access
    func fetchUserPlaylists(completion: @escaping (Result<[MusicPlaylist], Error>) -> Void)
    func fetchTracksFromPlaylist(playlistId: String, completion: @escaping (Result<[Track], Error>) -> Void)
}
```

## Next Steps

1. **Configure Xcode** - Add MusicKit capability and privacy descriptions
2. **Configure Developer Portal** - Enable MusicKit for your app identifier
3. **Test Authorization** - Verify authorization flow works
4. **Test Playback** - Play a track and verify it works
5. **Integrate with RunSessionViewModel** - Connect music service to your workout logic
6. **Implement BPM Matching** - Add logic to select tracks based on heart rate

## Resources

- [Apple MusicKit Documentation](https://developer.apple.com/documentation/musickit)
- [MusicKit Authorization](https://developer.apple.com/documentation/musickit/musicauthorization)
- [ApplicationMusicPlayer](https://developer.apple.com/documentation/musickit/applicationmusicplayer)
- [MusicKit Best Practices](https://developer.apple.com/documentation/musickit/integrating_musickit_into_your_app)
