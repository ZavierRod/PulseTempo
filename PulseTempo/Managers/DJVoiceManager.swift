import Foundation
import AVFoundation
import Combine

/// Handles speech synthesis and audio playback for the AI DJ features.
class DJVoiceManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    /// Global shared instance.
    static let shared = DJVoiceManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isSpeaking: Bool = false
    
    override private init() {
        super.init()
        setupAudioSession()
    }
    
    /// Configures the audio session so speech doesn't permanently pause music
    /// and instead gracefully ducks the volume.
    private func setupAudioSession() {
        do {
            // We set the category to playback with the `.duckOthers` option.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [DJVoiceManager] Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    /// Generates speech from text using ElevenLabs and plays it back.
    func speak(text: String) {
        // Cancel any ongoing speech so phrases don't stack up randomly.
        stop()
        
        print("🎙️ [DJVoiceManager] Requesting TTS from ElevenLabs for: \"\(text)\"")
        
        Task { @MainActor in
            self.isSpeaking = true
            
            do {
                let audioData = try await ElevenLabsService.shared.generateSpeech(for: text)
                
                // Initialize the AVAudioPlayer with the downloaded MP3 data
                self.audioPlayer = try AVAudioPlayer(data: audioData)
                self.audioPlayer?.delegate = self
                
                // AVAudioPlayer volume caps at 1.0 natively. 
                // To make the DJ sound much louder and more punchy over the ducked music,
                // we enable rate and pitch adjustments to force the internal mixer to process the audio,
                // then we enable reverb/EQ if needed, but the easiest trick is applying an audio session ducking heavily.
                // We'll also tell the player to prepare to play to reduce latency.
                self.audioPlayer?.volume = 1.0
                self.audioPlayer?.prepareToPlay()
                
                // Play the audio (this will automatically duck Apple Music thanks to our audio session options)
                self.audioPlayer?.play()
                
            } catch {
                print("❌ [DJVoiceManager] Failed to generate or play ElevenLabs Audio: \(error.localizedDescription)")
                self.isSpeaking = false
                self.restoreAudioSession()
            }
        }
    }
    
    /// Stops the current speech immediately.
    func stop() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            self.audioPlayer = nil
            
            DispatchQueue.main.async {
                self.isSpeaking = false
            }
            restoreAudioSession()
        }
    }
    
    // MARK: - AVAudioPlayerDelegate Methods
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎙️ [DJVoiceManager] Finished playback. Restoring background music volume.")
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
        restoreAudioSession()
    }
    
    private func restoreAudioSession() {
        // Ensure audio session returns to normal to restore background music full volume
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ [DJVoiceManager] Failed to deactivate audio session context: \(error.localizedDescription)")
        }
    }
}
