import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Centralized service for haptic feedback and sound effects
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  // Setters
  void setSoundEnabled(bool enabled) => _soundEnabled = enabled;
  void setHapticsEnabled(bool enabled) => _hapticsEnabled = enabled;

  /// Light haptic feedback for button presses
  Future<void> lightTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Medium haptic feedback for selections
  Future<void> mediumTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Heavy haptic feedback for important actions
  Future<void> heavyTap() async {
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Selection change haptic
  Future<void> selectionClick() async {
    if (_hapticsEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  /// Success vibration pattern
  Future<void> success() async {
    if (_hapticsEnabled) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    }
  }

  /// Error vibration pattern
  Future<void> error() async {
    if (_hapticsEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play success sound
  Future<void> playSuccessSound() async {
    if (_soundEnabled) {
      try {
        await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      } catch (e) {
        // Sound file not found, ignore
      }
    }
  }

  /// Play click sound
  Future<void> playClickSound() async {
    if (_soundEnabled) {
      try {
        await _audioPlayer.play(AssetSource('sounds/click.mp3'));
      } catch (e) {
        // Sound file not found, ignore
      }
    }
  }

  /// Combined success feedback (haptic + sound)
  Future<void> successFeedback() async {
    await Future.wait([success(), playSuccessSound()]);
  }

  /// Combined tap feedback (haptic + sound)
  Future<void> tapFeedback() async {
    await Future.wait([lightTap(), playClickSound()]);
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
