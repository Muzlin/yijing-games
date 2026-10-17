import 'package:flutter/services.dart';

import '../game/models.dart';

class AppSound {
  static bool enabled = true;

  static Future<void> load() async {
    enabled = await GameStorage.loadSound();
  }

  static void select() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  static void move() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void capture() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void check() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }
}
