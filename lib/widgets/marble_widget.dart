import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/board_themes.dart';

class MarbleWidget extends StatefulWidget {
  final Player player;
  final double size;
  final bool isSelected;
  final bool isHint;
  final bool isPushTarget;
  final BoardTheme theme;
  final double animationSpeed;

  const MarbleWidget({
    super.key,
    required this.player,
    required this.size,
    required this.theme,
    this.isSelected = false,
    this.isHint = false,
    this.isPushTarget = false,
    this.animationSpeed = 1.0,
  });

  @override
  State<MarbleWidget> createState() => _MarbleWidgetState();
}

class _MarbleWidgetState extends State<MarbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: (1000 / widget.animationSpeed).round()),
    );
    _checkPulse();
  }

  @override
  void didUpdateWidget(MarbleWidget old) {
    super.didUpdateWidget(old);

    if (old.animationSpeed != widget.animationSpeed) {
      _pulse.duration = Duration(
        milliseconds: (1000 / widget.animationSpeed).round(),
      );
    }

    _checkPulse();
  }

  void _checkPulse() {
    final need =
        widget.isHint || widget.isPushTarget || widget.isSelected;
    if (need && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!need && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final t = widget.theme;
    final slotD = s * 0.80;
    final marbleD = s * 0.74;

    final selectionDuration = Duration(
      milliseconds: (180 / widget.animationSpeed).round(),
    );

    return SizedBox(
      width: s,
      height: s,
      child: Center(
        child: SizedBox(
          width: slotD + 4,
          height: slotD + 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Deep hole / slot ──
              Container(
                width: slotD,
                height: slotD,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.15),
                    radius: 0.8,
                    colors: t.slotColors,
                  ),
                ),
              ),

              // ── Slot rim ──
              Container(
                width: slotD,
                height: slotD,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: CustomPaint(
                  painter: _SlotRimPainter(
                    rimLightColor: t.slotRimColor,
                    rimShadowColor: t.slotShadowColor,
                  ),
                ),
              ),

              // ── Hint dot ──
              if (widget.isHint && widget.player == Player.none)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: 0.7 + 0.4 * _pulse.value,
                      child: Container(
                        width: s * 0.24,
                        height: s * 0.24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.hintColor.withOpacity(
                            0.5 + 0.4 * _pulse.value,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.hintGlow,
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // ── Push target ring ──
              if (widget.isPushTarget && widget.player != Player.none)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return Container(
                      width: marbleD + 6,
                      height: marbleD + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.pushTargetColor.withOpacity(
                            0.5 + 0.4 * _pulse.value,
                          ),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.pushTargetColor.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // ── The marble ──
              if (widget.player != Player.none)
                AnimatedScale(
                  scale: widget.isSelected ? 1.08 : 1.0,
                  duration: selectionDuration,
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: marbleD,
                    height: marbleD,
                    child: CustomPaint(
                      painter: _MarblePainter(
                        isBlack: widget.player == Player.black,
                        theme: t,
                        isSelected: widget.isSelected,
                      ),
                    ),
                  ),
                ),

              // ── Selection ring ──
              if (widget.isSelected && widget.player != Player.none)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final isPulsing =
                        widget.isHint || widget.isPushTarget;
                    final glowIntensity =
                        isPulsing ? 0.4 + 0.3 * _pulse.value : 0.4;
                    final ringWidth =
                        isPulsing ? 2.5 + 1.0 * _pulse.value : 2.5;

                    return Container(
                      width: marbleD + 5,
                      height: marbleD + 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.selectionRing.withOpacity(0.85),
                          width: ringWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: t.selectionGlow
                                .withOpacity(glowIntensity),
                            blurRadius: isPulsing ? 14 : 10,
                            spreadRadius: isPulsing ? 4 : 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRimPainter extends CustomPainter {
  final Color rimLightColor;
  final Color rimShadowColor;

  _SlotRimPainter({
    required this.rimLightColor,
    required this.rimShadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final topArc = Paint()
      ..color = rimLightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 0.5),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      topArc,
    );

    final bottomArc = Paint()
      ..color = rimShadowColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 0.5),
      math.pi * 0.1,
      math.pi * 0.8,
      false,
      bottomArc,
    );
  }

  @override
  bool shouldRepaint(covariant _SlotRimPainter old) => false;
}

class _MarblePainter extends CustomPainter {
  final bool isBlack;
  final BoardTheme theme;
  final bool isSelected;

  _MarblePainter({
    required this.isBlack,
    required this.theme,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final colors =
        isBlack ? theme.blackMarbleColors : theme.whiteMarbleColors;
    final stops =
        isBlack ? theme.blackMarbleStops : theme.whiteMarbleStops;
    final shadow =
        isBlack ? theme.blackMarbleShadow : theme.whiteMarbleShadow;

    canvas.drawCircle(
      Offset(center.dx + 1.5, center.dy + 3),
      radius * 0.92,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.5),
          radius: 0.8,
          colors: [
            Colors.transparent,
            Colors.transparent,
            (isBlack
                    ? theme.blackHighlightColor
                    : theme.whiteHighlightColor)
                .withOpacity(isBlack ? 0.03 : 0.08),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    final highlightCenter = Offset(
      center.dx - radius * 0.25,
      center.dy - radius * 0.3,
    );
    final highlightW = radius * 0.65;
    final highlightH = radius * 0.4;
    final highlightRect = Rect.fromCenter(
      center: highlightCenter,
      width: highlightW,
      height: highlightH,
    );

    canvas.save();
    canvas.clipRect(rect);

    canvas.drawOval(
      highlightRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            (isBlack
                    ? theme.blackHighlightColor
                    : theme.whiteHighlightColor)
                .withOpacity(
              isBlack
                  ? theme.blackHighlightOpacity
                  : theme.whiteHighlightOpacity,
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(highlightRect),
    );

    final dotCenter = Offset(
      center.dx - radius * 0.2,
      center.dy - radius * 0.22,
    );
    final dotRadius = radius * 0.12;

    canvas.drawCircle(
      dotCenter,
      dotRadius,
      Paint()
        ..color = Colors.white.withOpacity(
          isBlack
              ? theme.blackHighlightOpacity * 0.9
              : theme.whiteHighlightOpacity * 0.95,
        ),
    );

    canvas.drawCircle(
      Offset(
        dotCenter.dx + dotRadius * 0.3,
        dotCenter.dy + dotRadius * 0.3,
      ),
      dotRadius * 0.4,
      Paint()..color = Colors.white.withOpacity(isBlack ? 0.4 : 0.7),
    );

    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withOpacity(isBlack ? 0.06 : 0.12),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.08),
            Colors.transparent,
            Colors.white.withOpacity(isBlack ? 0.06 : 0.12),
          ],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (isSelected) {
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = theme.selectionGlow.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarblePainter old) {
    return old.isBlack != isBlack ||
        old.theme.type != theme.type ||
        old.isSelected != isSelected;
  }
}