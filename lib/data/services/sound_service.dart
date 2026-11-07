import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  static const Map<String, String> _celebrationAssets = {
    'default': 'sounds/task_complete.mp3',
    'arcade': 'sounds/arcade_chime.mp3',
    'nature': 'sounds/nature_chime.mp3',
    'magic': 'sounds/magic_chime.mp3',
  };

  @visibleForTesting
  static String celebrationAssetFor(String soundId) {
    return _celebrationAssets[soundId] ?? _celebrationAssets['default']!;
  }

  bool get _soundEnabled {
    try {
      final box = Hive.box('settings');
      return box.get('soundEnabled', defaultValue: true);
    } catch (e) {
      return true;
    }
  }

  bool get _celebrationSoundEnabled {
    try {
      final box = Hive.box('settings');
      return box.get('celebrationSoundEnabled', defaultValue: true);
    } catch (e) {
      return true;
    }
  }

  Future<void> playStepComplete() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/step_complete.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> playTaskComplete({String soundId = 'default'}) async {
    if (!_soundEnabled || !_celebrationSoundEnabled) return;
    try {
      await _player.play(AssetSource(celebrationAssetFor(soundId)));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> playTimerEnd() async {
    if (!_soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/timer_end.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Play a gentle nudge sound for time blindness alerts
  Future<void> playTimeWarning() async {
    if (!_soundEnabled) return;
    try {
      // Use step_complete as a gentle nudge (softer than timer_end)
      await _player.play(AssetSource('sounds/step_complete.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
