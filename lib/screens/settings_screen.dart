import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../widgets/theme_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final t = ref.watch(boardThemeProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.surfaceColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.surfaceBorder),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            size: 16, color: t.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Settings',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Theme selector ──
                    _sectionLabel('Board Theme', t),
                    const SizedBox(height: 8),
                    const ThemeSelector(),
                    const SizedBox(height: 24),

                    // ── Gameplay ──
                    _section('Gameplay', [
                      _toggle(
                        'Show Move Hints',
                        'Highlight valid moves when selecting',
                        Icons.lightbulb_outline,
                        settings.showMoveHints,
                        (_) {
                          notifier.toggleHints();
                          HapticService.selectionClick();
                        },
                        t,
                      ),
                    ], t),
                    const SizedBox(height: 24),

                    // ── Audio ──
                    _section('Audio & Haptics', [
                      _toggle(
                        'Sound Effects',
                        'Play sounds on moves and actions',
                        Icons.volume_up_rounded,
                        settings.soundEnabled,
                        (_) {
                          notifier.toggleSound();
                          // Update service immediately
                          SoundService.setEnabled(!settings.soundEnabled);
                          if (!settings.soundEnabled) {
                            SoundService.playTap();
                          }
                        },
                        t,
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: t.surfaceBorder.withOpacity(0.5),
                      ),
                      _toggle(
                        'Haptic Feedback',
                        'Vibrate on tap, move and push',
                        Icons.vibration,
                        settings.hapticEnabled,
                        (_) {
                          notifier.toggleHaptic();
                          // Update service immediately
                          HapticService.setEnabled(!settings.hapticEnabled);
                          if (!settings.hapticEnabled) {
                            HapticService.mediumImpact();
                          }
                        },
                        t,
                      ),
                    ], t),
                    const SizedBox(height: 24),

                    // ── Display ──
                    _section('Display', [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.speed,
                                    color: t.accent, size: 22),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Animation Speed',
                                          style: TextStyle(
                                              color: t.textPrimary,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _speedLabel(
                                            settings.animationSpeed),
                                        style: TextStyle(
                                            color: t.textSecondary,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: t.accent.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${settings.animationSpeed.toStringAsFixed(1)}x',
                                    style: TextStyle(
                                      color: t.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: t.accent,
                                thumbColor: t.accent,
                                inactiveTrackColor: t.scoreEmpty,
                                overlayColor:
                                    t.accent.withOpacity(0.1),
                                trackHeight: 4,
                                thumbShape:
                                    const RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: settings.animationSpeed,
                                min: 0.5,
                                max: 2.0,
                                divisions: 6,
                                onChanged: (v) {
                                  notifier.setAnimationSpeed(v);
                                  HapticService.selectionClick();
                                },
                              ),
                            ),
                            // Speed labels
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Slow',
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 9)),
                                  Text('Normal',
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 9)),
                                  Text('Fast',
                                      style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], t),
                    const SizedBox(height: 40),

                    Center(
                      child: TextButton(
                        onPressed: () {
                          notifier.resetDefaults();
                          HapticService.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings reset to defaults'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Text('Reset to Defaults',
                            style: TextStyle(color: Color(0xB3FF4757))),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _speedLabel(double speed) {
    if (speed <= 0.5) return 'Very slow — see every detail';
    if (speed <= 0.75) return 'Slow — relaxed pace';
    if (speed <= 1.0) return 'Normal speed';
    if (speed <= 1.25) return 'Slightly faster';
    if (speed <= 1.5) return 'Fast — quick moves';
    if (speed <= 1.75) return 'Very fast';
    return 'Maximum speed';
  }

  Widget _sectionLabel(String title, dynamic t) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: t.accent.withOpacity(0.7))),
    );
  }

  Widget _section(String title, List<Widget> children, dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(title, t),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: t.surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.surfaceBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _toggle(String title, String sub, IconData icon, bool value,
      ValueChanged<bool> onChanged, dynamic t) {
    return ListTile(
      leading: Icon(icon, color: t.accent, size: 22),
      title:
          Text(title, style: TextStyle(fontSize: 15, color: t.textPrimary)),
      subtitle:
          Text(sub, style: TextStyle(fontSize: 12, color: t.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: t.accent,
      ),
    );
  }
}