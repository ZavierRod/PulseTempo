# PulseTempo AI DJ Feature Plan

> **Goal:** Create an intelligent, context-aware "AI DJ" that manages the workout playlist dynamically based on user biometrics (heart rate, pace) and provides a highly engaging, continuous audio experience.

## 🎧 Phase 1: Biometric-Driven Queueing (The Brain) (Will do later after Phase 2)
The AI DJ needs to seamlessly pick the *next* track based on real-time data.
- **Heart Rate Analysis:** Continuously monitor the user's current HR vs. their target zone.
- **Dynamic Track Selection:** 
  - If HR is too low ➔ Queue a high-energy / faster BPM song.
  - If HR is too high ➔ Queue a recovery / slower BPM song.
  - If HR is perfect ➔ Queue a song that matches the current tempo.
- **Background Queueing:** Use MusicKit's `ApplicationMusicPlayer` queue manipulation to insert these tracks silently before the current song ends, so there is zero interruption.

## 🎙️ Phase 2: Dynamic Audio Voiceovers (The DJ Persona)
Bring the DJ to life by having them announce milestones and queue changes.

**Implementation Chunks for Phase 2:**
- [x] **Step 2.1: The DJ Audio Engine (`DJVoiceManager`)**
  - Singleton class that downloads and plays `.mp3` files via `AVAudioPlayer`.
  - Ducks Apple Music while the DJ speaks, restores volume when done.
- [x] **Step 2.2: Audio Ducking Setup (`AVAudioSession`)**
  - Configured `.duckOthers` + `.interruptSpokenAudioAndMixWithOthers` for aggressive ducking.
- [x] **Step 2.3: ElevenLabs TTS Networking Layer (`ElevenLabsService`)**
  - Secure network request to ElevenLabs API using `eleven_multilingual_v2` model.
  - Returns MP3 audio data played directly by `DJVoiceManager`.
- [x] **Step 2.4: Contextual Prompt Generation (`OpenAIPromptService`)**
  - Hits `gpt-4o-mini` with live workout context (runner name, HR, elapsed time, current song, next song).
  - Returns a unique, conversational 1-2 sentence DJ script every time.
  - Maintains a **rolling 50-script dialogue history cache** fed back into the prompt to prevent repetition.
  - Uses `triggerReason` to control whether to reference the next queued song (only during `song_transition`).
- [x] **Step 2.5: Automatic DJ Triggers (`DJTriggerManager`)**
  - Intelligent auto-trigger system with a 2-second evaluation timer.
  - **Song Position Context:** Passes current song elapsed time + total duration.
  - **Trigger Events:**
    - 🎵 **Song Transition:** ~15 seconds before the current song ends.
    - ⏱️ **Time-Based Check-ins:** Every ~5 minutes.
    - ❤️ **HR Zone Change:** When crossing into a new zone.
    - 🏃 **Workout Milestones:** Every 10 minutes.
  - **Cooldown Timer:** 90-second minimum gap.
  - **Smart Timing:** Only speaks mid-song (30s–end-10s buffer) unless song transition.
- [x] **Bug Fix: Repetitive Dialogue**
  - Added a 50-entry rolling dialogue cache in `OpenAIPromptService`.
  - Recent 10 scripts are fed into the system prompt with explicit "do NOT repeat" instructions.
  - Bumped temperature to 1.0 for maximum creativity.
- [x] **Bug Fix: Inaccurate Queued Song References**
  - Added `triggerReason` field to `DJContext`.
  - Next-song data is only passed during `song_transition` triggers.
  - Mid-song check-ins explicitly tell OpenAI "do NOT mention upcoming songs."

## 🎛️ Phase 3: Seamless Audio Transitions
Ensure the music never stops abruptly.
- **Crossfading:** Investigate if `ApplicationMusicPlayer` supports crossfade overrides, or build a custom crossfader if we use a lower-level `AVQueuePlayer` (Noting that Apple Music DRM tracks have limitations here).
- **Gapless Playback:** Ensure the selected tracks load fast enough to provide a fluid, gapless transition when the DJ finishes speaking.

## 🎨 Phase 4: UI & Onboarding Integration
- **DJ Settings Panel:** Add a toggle in settings to enable/disable the AI DJ, choose voice types (Male/Female/Robotic), and select interruption frequency.
- **Visual DJ Indicator:** Add a small animated visualizer or "DJ Active" badge in the `ActiveRunView` and Live Activity so the user knows the queue is being automatically curated.

---

### Technical Prerequisites & Next Steps
1. ~~Define the Prompt Engine~~ ✅ Done (`OpenAIPromptService`)
2. ~~Audio Ducking Test~~ ✅ Done (verified on physical device)
3. ~~Build `DJTriggerManager`~~ ✅ Done (all 4 trigger types + cooldown + smart timing)
4. ~~Fix repetitive dialogue~~ ✅ Done (50-entry history cache + anti-repetition prompt)
5. ~~Fix inaccurate queue references~~ ✅ Done (conditional next-song via `triggerReason`)
6. **Queue Injection Test:** Confirm that modifying the music queue mid-song via `MusicKit` is completely seamless.
