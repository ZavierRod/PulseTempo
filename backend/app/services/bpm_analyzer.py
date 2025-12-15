import os
import tempfile
import requests
import librosa
import numpy as np
from fastapi import HTTPException


class BPMAnalyzer:
    @staticmethod
    def analyze_url(url: str) -> float:
        """
        Download audio from a URL and estimate its BPM using Librosa.

        Args:
            url: The URL of the audio file (e.g., Apple Music preview URL).

        Returns:
            float: The estimated BPM.

        Raises:
            HTTPException: If download fails or analysis fails.
        """
        temp_path = None
        try:
            # 1. Download the file
            response = requests.get(url, stream=True)
            response.raise_for_status()

            # Create a temp file
            # We use .m4a suffix because Apple Music previews are usually m4a
            with tempfile.NamedTemporaryFile(delete=False, suffix=".m4a") as temp_file:
                for chunk in response.iter_content(chunk_size=8192):
                    temp_file.write(chunk)
                temp_path = temp_file.name

            # 2. Load audio with Librosa
            # Load 30 seconds (standard preview length)
            # sr=None preserves native sampling rate, but we can let librosa resample to 22050 (default) for speed
            y, sr = librosa.load(temp_path, duration=30)

            # 3. Estimate Tempo
            onset_env = librosa.onset.onset_strength(y=y, sr=sr)
            tempo, _ = librosa.beat.beat_track(onset_envelope=onset_env, sr=sr)

            # Librosa beat_track returns a scalar or a 1-element array depending on version/input
            if isinstance(tempo, np.ndarray):
                tempo = tempo.item()

            return round(float(tempo), 1)

        except requests.RequestException as e:
            print(f"❌ Download failed: {str(e)}")
            raise HTTPException(
                status_code=400, detail=f"Failed to download audio: {str(e)}")
        except Exception as e:
            import traceback
            print(f"❌ BPM analysis failed: {str(e)}")
            print(f"❌ Full traceback:\n{traceback.format_exc()}")
            raise HTTPException(
                status_code=500, detail=f"BPM analysis failed: {str(e)}")
        finally:
            # 4. Cleanup
            if temp_path and os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except OSError:
                    pass
