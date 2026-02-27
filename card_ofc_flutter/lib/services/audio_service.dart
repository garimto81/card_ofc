import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  bool soundEnabled = true;
  bool hapticEnabled = true;

  void playCardPlace() {
    if (hapticEnabled) HapticFeedback.lightImpact();
  }

  void playCardFlip() {
    if (hapticEnabled) HapticFeedback.selectionClick();
  }

  void playConfirm() {
    if (hapticEnabled) HapticFeedback.mediumImpact();
  }

  void playFoul() {
    if (hapticEnabled) HapticFeedback.heavyImpact();
  }

  void playScoop() {
    if (hapticEnabled) HapticFeedback.heavyImpact();
  }

  void playGameOver() {
    if (hapticEnabled) HapticFeedback.heavyImpact();
  }

  void updateSettings({bool? sound, bool? haptic}) {
    if (sound != null) soundEnabled = sound;
    if (haptic != null) hapticEnabled = haptic;
  }
}
