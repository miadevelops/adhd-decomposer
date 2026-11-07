import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // One player per channel so a celebration doesn't cut off the step chime.
  // Created lazily, and again after dispose().
  final Map<String, AudioPlayer> _players = {};

  Future<void> _play(String channel, String asset) async {
    try {
      final player = _players.putIfAbsent(channel, AudioPlayer.new);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

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
    await _play('step', 'sounds/step_complete.mp3');
  }

  Future<void> playTaskComplete({String soundId = 'default'}) async {
    if (!_soundEnabled || !_celebrationSoundEnabled) return;
    await _play('celebration', celebrationAssetFor(soundId));
  }

  Future<void> playTimerEnd() async {
    if (!_soundEnabled) return;
    await _play('timer', 'sounds/timer_end.mp3');
  }

  /// Play a gentle nudge sound for time blindness alerts
  Future<void> playTimeWarning() async {
    if (!_soundEnabled) return;
    // Use step_complete as a gentle nudge (softer than timer_end)
    await _play('step', 'sounds/step_complete.mp3');
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
