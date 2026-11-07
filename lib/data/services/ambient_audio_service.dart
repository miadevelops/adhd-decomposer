import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Ambient sound options for Body Double mode
enum AmbientSound {
  none,
  cafe,
  rain,
  whiteNoise,
  nature,
  fireplace,
}

/// Helper extension for free/premium sound categorization
extension AmbientSoundExtension on AmbientSound {
  /// Café is the free sound, others require Pro
  bool get isFree => this == AmbientSound.none || this == AmbientSound.cafe;
  
  /// All sounds except none and cafe are premium
  bool get isPremium => !isFree && this != AmbientSound.none;
  
  /// Display name for UI
  String get displayName {
    switch (this) {
      case AmbientSound.none:
        return 'None';
      case AmbientSound.cafe:
        return 'Café';
      case AmbientSound.rain:
        return 'Rain';
      case AmbientSound.whiteNoise:
        return 'White Noise';
      case AmbientSound.nature:
        return 'Nature';
      case AmbientSound.fireplace:
        return 'Fireplace';
    }
  }
}

/// Service for playing ambient background sounds during focus sessions.
/// 
/// Supports looping playback of ambient sounds at system-controlled volume.
class AmbientAudioService {
  static final AmbientAudioService _instance = AmbientAudioService._internal();
  factory AmbientAudioService() => _instance;
  AmbientAudioService._internal();

  AudioPlayer? _audioPlayer;
  // Recreated lazily so the service still works after dispose().
  AudioPlayer get _player => _audioPlayer ??= AudioPlayer();
  AmbientSound _currentSound = AmbientSound.none;
  bool _isInitialized = false;
  Future<void> _pendingOperation = Future.value();

  /// Current ambient sound being played
  AmbientSound get currentSound => _currentSound;
  
  /// Whether a sound is currently selected (not none)
  bool get isPlaying => _currentSound != AmbientSound.none;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _player.setReleaseMode(ReleaseMode.loop);
    _isInitialized = true;
  }

  /// Play an ambient sound
  /// 
  /// If the same sound is already playing, this is a no-op.
  /// Pass [AmbientSound.none] to stop playback.
  Future<void> play(AmbientSound sound) async {
    _pendingOperation = _pendingOperation.then((_) => _play(sound));
    await _pendingOperation;
  }

  Future<void> _play(AmbientSound sound) async {
    try {
      await initialize();

      if (sound == _currentSound) return;

      if (sound == AmbientSound.none) {
        await _stopPlayer();
        return;
      }

      final assetPath = _getAssetPath(sound);
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(AssetSource(assetPath));
      _currentSound = sound;
    } catch (e) {
      debugPrint('Error playing ambient sound: $e');
      _currentSound = AmbientSound.none;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    _currentSound = AmbientSound.none;
    _pendingOperation = _pendingOperation.then((_) => _stopPlayer());
    await _pendingOperation;
  }

  Future<void> _stopPlayer() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping ambient sound: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    final player = _audioPlayer;
    _audioPlayer = null;
    _currentSound = AmbientSound.none;
    _isInitialized = false;
    if (player == null) return;
    await player.stop();
    await player.dispose();
  }

  /// Get asset path for a sound
  String _getAssetPath(AmbientSound sound) {
    switch (sound) {
      case AmbientSound.cafe:
        return 'audio/ambient/cafe_ambient.mp3';
      case AmbientSound.rain:
        return 'audio/ambient/rain.mp3';
      case AmbientSound.whiteNoise:
        return 'audio/ambient/white_noise.mp3';
      case AmbientSound.nature:
        return 'audio/ambient/nature.mp3';
      case AmbientSound.fireplace:
        return 'audio/ambient/fireplace.mp3';
      case AmbientSound.none:
        return '';
    }
  }

  /// Get display label for a sound
  static String getLabel(AmbientSound sound) {
    switch (sound) {
      case AmbientSound.none:
        return 'Off';
      case AmbientSound.cafe:
        return 'Café';
      case AmbientSound.rain:
        return 'Rain';
      case AmbientSound.whiteNoise:
        return 'Noise';
      case AmbientSound.nature:
        return 'Nature';
      case AmbientSound.fireplace:
        return 'Fire';
    }
  }

  /// Get icon for a sound
  static String getIconName(AmbientSound sound) {
    switch (sound) {
      case AmbientSound.none:
        return 'volume_off';
      case AmbientSound.cafe:
        return 'coffee';
      case AmbientSound.rain:
        return 'water_drop';
      case AmbientSound.whiteNoise:
        return 'waves';
      case AmbientSound.nature:
        return 'park';
      case AmbientSound.fireplace:
        return 'local_fire_department';
    }
  }
}
