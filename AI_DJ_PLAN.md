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
- **Speech Synthesis:** Implement an `AVSpeechSynthesizer` manager (`DJVoiceManager`) to generate on-device audio.
- **Audio Ducking:** Automatically lower the music volume (ducking) while the DJ is speaking, then ramp it back up.
- **Contextual Prompts:**
  - *"Great job, you just hit the tempo zone! Heart rate is currently 155. Here’s a high-energy track to keep you locked in: [Next Song Title]."*
  - *"You've been pushing hard, time to catch your breath. Queuing up a recovery track."*
- **Frequency Controls:** Allow the user to set how often the DJ interrupts (e.g., Every 1 Mile, Every Zone Change, or Smart/Adaptive).

## 🎛️ Phase 3: Seamless Audio Transitions
Ensure the music never stops abruptly.
- **Crossfading:** Investigate if `ApplicationMusicPlayer` supports crossfade overrides, or build a custom crossfader if we use a lower-level `AVQueuePlayer` (Noting that Apple Music DRM tracks have limitations here).
- **Gapless Playback:** Ensure the selected tracks load fast enough to provide a fluid, gapless transition when the DJ finishes speaking.

## 🎨 Phase 4: UI & Onboarding Integration
- **DJ Settings Panel:** Add a toggle in settings to enable/disable the AI DJ, choose voice types (Male/Female/Robotic), and select interruption frequency.
- **Visual DJ Indicator:** Add a small animated visualizer or "DJ Active" badge in the `ActiveRunView` and Live Activity so the user knows the queue is being automatically curated.

---

### Technical Prerequisites & Next Steps
1. **Define the Prompt Engine:** Build a Swift service that generates the text strings the DJ will say based on incoming `WorkoutManager` metrics.
2. **Audio Ducking Test:** Validate that `AVAudioSession` can successfully duck the `ApplicationMusicPlayer` without pausing the workout context.
3. **Queue Injection Test:** Confirm that modifying the music queue mid-song via `MusicKit` is completely seamless.
