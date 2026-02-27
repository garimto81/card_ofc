import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

class AppSettings {
  final bool soundEnabled;
  final bool hapticEnabled;
  final String playerName;
  final String theme;

  const AppSettings({
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.playerName = 'You',
    this.theme = 'dark',
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticEnabled,
    String? playerName,
    String? theme,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      playerName: playerName ?? this.playerName,
      theme: theme ?? this.theme,
    );
  }
}

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  AppSettings build() {
    return const AppSettings();
  }

  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
  }

  void toggleHaptic() {
    state = state.copyWith(hapticEnabled: !state.hapticEnabled);
  }

  void setPlayerName(String name) {
    state = state.copyWith(playerName: name);
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
  }
}
