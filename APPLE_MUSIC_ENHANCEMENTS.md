# Apple Music UX/UI Enhancements

> Last updated: March 1, 2026
> All features use MusicKit / Apple Music API and maintain core workout functionality.

---

## 🔥 High Priority

### 1. Animated Artwork
Some Apple Music tracks have animated/video artwork. Display a subtle looping animation behind the now-playing card in `ActiveRunView`, mirroring how Apple Music handles it.
- Check `artwork` for video/animated variants
- Use `AVPlayerLayer` looping behind the album art card

### ✅ 2. Dynamic Island / Live Activity (ActivityKit)
Live Activity on the Lock Screen and Dynamic Island during an active run. (Completed)
- Compact view: album art thumbnail + heart rate + current BPM
- Requires `ActivityKit` + `NSSupportsLiveActivities` in Info.plist
- Lock screen view: elapsed time, avg HR, current song title

### 3. BPM-Filtered Catalog Search
Add a **"Find songs near X BPM"** mode to the song search/add flow.
- Searches workout-friendly genres in the Apple Music catalog
- Results passed to backend to filter by matching BPM range
- Bridges Apple's discovery engine with PulseTempo's core matching algorithm

### 4. Recently Played / Heavy Rotation in Mid-Workout Add Sheet
Pre-populate the mid-workout **"Add Songs"** sheet with the user's most familiar tracks instead of starting with an empty search.
- `GET /v1/me/recent/played/tracks`
- `GET /v1/me/history/heavy-rotation`
- Shows as a "Your Favorites" row above the search bar

### 5. Full-Resolution Artwork
Bump all artwork fetches from `100–120px` to `600×600` for retina display quality.
- `ActiveRunView` album art (currently 200pt rendered)
- `PlaylistSelectionView`, `PlaylistSongsView`, `MusicSearchView`

### 6. Dynamic Album Art Color Theming
Make the `ActiveRunView` gradient dynamically match the current song's album artwork palette instead of always using red/pink — exactly how Apple Music behaves.
- `artwork.backgroundColor`, `artwork.primaryTextColor`, `artwork.secondaryTextColor`
- Animate the color transition when tracks change
- Falls back to the existing red gradient if no artwork color is available

---

## 🟢 Low Priority

### 7. Rich Song Metadata on Track Cards
Show genre tags and explicit content badges inline on `PlaylistSongsView` and `MusicSearchView` cards.
- MusicKit catalog tracks expose `genres`, `contentRating`, `editorialNotes`
- Small tag pills below the track title

### 8. Audio Preview on Long-Press
Long-press any song in `PlaylistSongsView` or `MusicSearchView` to play its 30-second Apple Music preview inline.
- `track.previews.first?.url` → `AVPlayer`
- Same pattern as App Store app previews
- Lets users verify a song fits their workout vibe before adding it

### 9. Related Artists / "More from this Artist"
A "More by this artist" section at the bottom of `PlaylistSongsView`.
- `GET /v1/catalog/{storefront}/artists/{id}/view/top-songs`
- Helps discovery without leaving the app

---

## Implementation Notes

- All catalog API calls require a valid MusicKit developer token and user authorization (already in place)
- Features 5 and 6 (artwork resolution + color theming) can be done in a single pass through the views
- Feature 2 (Dynamic Island) requires an `ActivityAttributes` struct and separate widget extension target
- Feature 3 (BPM search) will need a new filter UI component in `MusicSearchView` and a backend-side BPM range query
