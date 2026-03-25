import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/board_themes.dart';
import '../providers/settings_provider.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(settingsProvider.select((s) => s.boardTheme));

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: BoardThemes.all.length,
        itemBuilder: (context, index) {
          final theme = BoardThemes.all[index];
          final selected = theme.type == current;

          return GestureDetector(
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setBoardTheme(theme.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 105,
              margin: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? theme.accent
                      : theme.surfaceBorder,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? theme.accent.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: selected ? 12 : 4,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Background
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: theme.backgroundColors,
                          ),
                        ),
                      ),
                    ),

                    // Mini board preview
                    Positioned(
                      left: 18,
                      top: 12,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: theme.boardFillColors,
                            stops: theme.boardFillStops,
                          ),
                          border: Border.all(
                            color: theme.boardBorderColor
                                .withOpacity(0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Black marble
                            Positioned(
                              left: 12,
                              top: 14,
                              child: _miniMarble(
                                16,
                                theme.blackMarbleColors,
                                theme.blackMarbleStops,
                              ),
                            ),
                            // Slot
                            Positioned(
                              left: 28,
                              top: 28,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: theme.slotColors,
                                  ),
                                ),
                              ),
                            ),
                            // White marble
                            Positioned(
                              right: 12,
                              bottom: 14,
                              child: _miniMarble(
                                16,
                                theme.whiteMarbleColors,
                                theme.whiteMarbleStops,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Label
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.45),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              theme.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white
                                        .withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              theme.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.5),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Check badge
                    if (selected)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accent,
                            boxShadow: [
                              BoxShadow(
                                color: theme.accent
                                    .withOpacity(0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.check,
                              size: 13, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniMarble(
      double size, List<Color> colors, List<double> stops) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: colors,
          stops: stops,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.4, -0.4),
        child: Container(
          width: size * 0.3,
          height: size * 0.18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}