import 'package:flutter/material.dart';

enum BoardThemeType {
  royalArena,
  woodClassic,
  oceanBreeze,
  emeraldStone,
  rosewood,
  arcticIce,
  midnightGold,
  volcanicAsh,
}

class BoardTheme {
  final String name;
  final String description;
  final BoardThemeType type;

  final List<Color> backgroundColors;
  final AlignmentGeometry bgBegin;
  final AlignmentGeometry bgEnd;
  final Color backgroundAccent;

  final List<Color> boardFillColors;
  final List<double> boardFillStops;
  final Color boardBorderColor;
  final double boardBorderWidth;
  final Color boardInnerBorderColor;
  final Color boardShadowColor;
  final Color boardRimLight;
  final Color boardRimShadow;
  final Color boardTextureColor;
  final double boardTextureOpacity;

  final List<Color> slotColors;
  final Color slotRimColor;
  final Color slotShadowColor;

  final List<Color> blackMarbleColors;
  final List<double> blackMarbleStops;
  final Color blackMarbleShadow;
  final double blackHighlightOpacity;
  final Color blackHighlightColor;

  final List<Color> whiteMarbleColors;
  final List<double> whiteMarbleStops;
  final Color whiteMarbleShadow;
  final double whiteHighlightOpacity;
  final Color whiteHighlightColor;

  final Color selectionGlow;
  final Color selectionRing;
  final Color hintColor;
  final Color hintGlow;
  final Color pushTargetColor;

  final Color accent;
  final Color accentLight;
  final Color surfaceColor;
  final Color surfaceBorder;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color scoreFilled;
  final Color scoreEmpty;

  const BoardTheme({
    required this.name,
    required this.description,
    required this.type,
    required this.backgroundColors,
    this.bgBegin = Alignment.topCenter,
    this.bgEnd = Alignment.bottomCenter,
    this.backgroundAccent = Colors.transparent,
    required this.boardFillColors,
    required this.boardFillStops,
    required this.boardBorderColor,
    this.boardBorderWidth = 3.0,
    required this.boardInnerBorderColor,
    required this.boardShadowColor,
    this.boardRimLight = const Color(0x30FFFFFF),
    this.boardRimShadow = const Color(0xFF3A2A18),
    this.boardTextureColor = const Color(0xFF000000),
    this.boardTextureOpacity = 0.06,
    required this.slotColors,
    this.slotRimColor = const Color(0x20FFFFFF),
    required this.slotShadowColor,
    required this.blackMarbleColors,
    required this.blackMarbleStops,
    this.blackMarbleShadow = const Color(0x90000000),
    required this.blackHighlightOpacity,
    this.blackHighlightColor = Colors.white,
    required this.whiteMarbleColors,
    required this.whiteMarbleStops,
    this.whiteMarbleShadow = const Color(0x70000000),
    required this.whiteHighlightOpacity,
    this.whiteHighlightColor = Colors.white,
    required this.selectionGlow,
    required this.selectionRing,
    required this.hintColor,
    this.hintGlow = const Color(0x50FFFFFF),
    required this.pushTargetColor,
    required this.accent,
    required this.accentLight,
    required this.surfaceColor,
    required this.surfaceBorder,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.scoreFilled,
    required this.scoreEmpty,
  });

  LinearGradient get backgroundGradient =>
      LinearGradient(begin: bgBegin, end: bgEnd, colors: backgroundColors);
}

class BoardThemes {
  // ──────────────────────────────────────────
  // 0. ROYAL ARENA — NEW DEFAULT PREMIUM THEME
  // ──────────────────────────────────────────
  static const royalArena = BoardTheme(
    name: 'Royal Arena',
    description: 'Premium dark & gold',
    type: BoardThemeType.royalArena,

    // Deep navy background
    backgroundColors: [
      Color(0xFF0A1628),
      Color(0xFF0E1F3D),
      Color(0xFF081428),
      Color(0xFF060E1E),
    ],

    // Warm bronze board — pops on dark navy
    boardFillColors: [
      Color(0xFFD4A050),
      Color(0xFFBC8A3C),
      Color(0xFFA47830),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFE8B860),
    boardBorderWidth: 4.0,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x70000000),
    boardRimLight: Color(0x45FFFFFF),
    boardRimShadow: Color(0xFF6A5020),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.05,

    // Deep navy slots
    slotColors: [Color(0xFF0C1830), Color(0xFF142040)],
    slotRimColor: Color(0x20FFFFFF),
    slotShadowColor: Color(0x90000000),

    // Rich sapphire blue marbles
    blackMarbleColors: [
      Color(0xFF4488CC),
      Color(0xFF2260A8),
      Color(0xFF0C3878),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x88000000),
    blackHighlightOpacity: 0.6,
    blackHighlightColor: Color(0xFFB8DDFF),

    // Pearl ivory marbles
    whiteMarbleColors: [
      Color(0xFFFFF8EC),
      Color(0xFFE8D4B4),
      Color(0xFFD0B890),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x65000000),
    whiteHighlightOpacity: 0.85,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFFD700),
    selectionRing: Color(0xFFFFAA00),
    hintColor: Color(0xFFFFD700),
    hintGlow: Color(0x60FFD700),
    pushTargetColor: Color(0xFFFF4444),

    accent: Color(0xFFFFB300),
    accentLight: Color(0x25FFB300),
    surfaceColor: Color(0xFF111E35),
    surfaceBorder: Color(0x18FFFFFF),
    cardColor: Color(0xFF152240),
    textPrimary: Color(0xFFF0ECE0),
    textSecondary: Color(0xAAF0ECE0),
    scoreFilled: Color(0xFFFFB300),
    scoreEmpty: Color(0x15FFFFFF),
  );

  // ──────────────────────────────────────────
  // 1. WOOD CLASSIC
  // ──────────────────────────────────────────
  static const woodClassic = BoardTheme(
    name: 'Wood Classic',
    description: 'Sandy wood board',
    type: BoardThemeType.woodClassic,

    backgroundColors: [
      Color(0xFF2C5F6E),
      Color(0xFF224E5C),
      Color(0xFF1A404E),
    ],

    boardFillColors: [
      Color(0xFFD8B070),
      Color(0xFFC89A58),
      Color(0xFFB88848),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFE0C080),
    boardBorderWidth: 3.5,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x60000000),
    boardRimLight: Color(0x40FFFFFF),
    boardRimShadow: Color(0xFF8A6A40),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.06,

    slotColors: [Color(0xFF6B5030), Color(0xFF7A5E3A)],
    slotRimColor: Color(0x30FFFFFF),
    slotShadowColor: Color(0x80000000),

    blackMarbleColors: [
      Color(0xFF5A8AAA),
      Color(0xFF2A5878),
      Color(0xFF0E3050),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFC0E8FF),

    whiteMarbleColors: [
      Color(0xFFFFF8E8),
      Color(0xFFE8D8C0),
      Color(0xFFD0B898),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.8,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFFD700),
    selectionRing: Color(0xFFFFAA00),
    hintColor: Color(0xFFFFD700),
    hintGlow: Color(0x60FFD700),
    pushTargetColor: Color(0xFFFF4444),

    accent: Color(0xFFE8A020),
    accentLight: Color(0x25E8A020),
    surfaceColor: Color(0xFF224E5C),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF2A5868),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xAAF0F0F0),
    scoreFilled: Color(0xFFE8A020),
    scoreEmpty: Color(0x20FFFFFF),
  );

  // ──────────────────────────────────────────
  // 2. OCEAN BREEZE
  // ──────────────────────────────────────────
  static const oceanBreeze = BoardTheme(
    name: 'Ocean Breeze',
    description: 'Tropical coral & sea',
    type: BoardThemeType.oceanBreeze,

    backgroundColors: [
      Color(0xFF1A5068),
      Color(0xFF144058),
      Color(0xFF0E3048),
    ],

    boardFillColors: [
      Color(0xFFD4A878),
      Color(0xFFC09468),
      Color(0xFFAA8058),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFE0B888),
    boardBorderWidth: 3.5,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x55000000),
    boardRimLight: Color(0x40FFFFFF),
    boardRimShadow: Color(0xFF7A6040),
    boardTextureOpacity: 0.05,

    slotColors: [Color(0xFF1A3858), Color(0xFF284868)],
    slotRimColor: Color(0x25FFFFFF),
    slotShadowColor: Color(0x88000000),

    blackMarbleColors: [
      Color(0xFF8858B0),
      Color(0xFF5A3088),
      Color(0xFF381868),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFD8B8FF),

    whiteMarbleColors: [
      Color(0xFFF0FFFA),
      Color(0xFFD0F0E8),
      Color(0xFFB0D8CC),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.85,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFF00E5FF),
    selectionRing: Color(0xFF00B8D4),
    hintColor: Color(0xFF00E5FF),
    hintGlow: Color(0x5000E5FF),
    pushTargetColor: Color(0xFFFF5252),

    accent: Color(0xFF00BCD4),
    accentLight: Color(0x2500BCD4),
    surfaceColor: Color(0xFF144058),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF1C4868),
    textPrimary: Color(0xFFF0F5F5),
    textSecondary: Color(0xAAF0F5F5),
    scoreFilled: Color(0xFF00BCD4),
    scoreEmpty: Color(0x20FFFFFF),
  );

  // ──────────────────────────────────────────
  // 3. EMERALD GOLD
  // ──────────────────────────────────────────
  static const emeraldStone = BoardTheme(
    name: 'Emerald Gold',
    description: 'Green felt & gold board',
    type: BoardThemeType.emeraldStone,

    backgroundColors: [
      Color(0xFF0E8858),
      Color(0xFF0A7048),
      Color(0xFF065A38),
    ],

    boardFillColors: [
      Color(0xFFECC030),
      Color(0xFFD8A820),
      Color(0xFFC09018),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFF4D040),
    boardBorderWidth: 4.0,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x60000000),
    boardRimLight: Color(0x40FFFFFF),
    boardRimShadow: Color(0xFF8A6A10),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.05,

    slotColors: [Color(0xFF1A5030), Color(0xFF246038)],
    slotRimColor: Color(0x22FFFFFF),
    slotShadowColor: Color(0x88000000),

    blackMarbleColors: [
      Color(0xFFE04888),
      Color(0xFFC02868),
      Color(0xFF880848),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFFFB8D8),

    whiteMarbleColors: [
      Color(0xFFFFF0E8),
      Color(0xFFEEC8B8),
      Color(0xFFDDA898),
    ],
    whiteMarbleStops: [0.0, 0.4, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.75,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFFEB3B),
    selectionRing: Color(0xFFFFC107),
    hintColor: Color(0xFFFFEB3B),
    hintGlow: Color(0x60FFEB3B),
    pushTargetColor: Color(0xFFFF1744),

    accent: Color(0xFFFFC107),
    accentLight: Color(0x25FFC107),
    surfaceColor: Color(0xFF0A7048),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF0C7850),
    textPrimary: Color(0xFFF5F5F0),
    textSecondary: Color(0xAAF5F5F0),
    scoreFilled: Color(0xFFFFC107),
    scoreEmpty: Color(0x20FFFFFF),
  );

  // ──────────────────────────────────────────
  // 4. ROSEWOOD
  // ──────────────────────────────────────────
  static const rosewood = BoardTheme(
    name: 'Rosewood',
    description: 'Mahogany & cobalt',
    type: BoardThemeType.rosewood,

    backgroundColors: [
      Color(0xFF3A1830),
      Color(0xFF2C1028),
      Color(0xFF200A20),
    ],

    boardFillColors: [
      Color(0xFFC06848),
      Color(0xFFA85838),
      Color(0xFF904830),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFD87858),
    boardBorderWidth: 3.5,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x55000000),
    boardRimLight: Color(0x35FFFFFF),
    boardRimShadow: Color(0xFF603020),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.05,

    slotColors: [Color(0xFF4A1820), Color(0xFF582028)],
    slotRimColor: Color(0x20FFFFFF),
    slotShadowColor: Color(0x90000000),

    blackMarbleColors: [
      Color(0xFF4878C8),
      Color(0xFF2850A0),
      Color(0xFF103878),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFB8D8FF),

    whiteMarbleColors: [
      Color(0xFFFFF0EA),
      Color(0xFFF0D0C4),
      Color(0xFFDDB8A8),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.80,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFF8A65),
    selectionRing: Color(0xFFFF7043),
    hintColor: Color(0xFFFF8A65),
    hintGlow: Color(0x55FF8A65),
    pushTargetColor: Color(0xFFFFD740),

    accent: Color(0xFFFF7043),
    accentLight: Color(0x25FF7043),
    surfaceColor: Color(0xFF2C1028),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF3A1830),
    textPrimary: Color(0xFFF5E8E8),
    textSecondary: Color(0xAAF5E8E8),
    scoreFilled: Color(0xFFFF7043),
    scoreEmpty: Color(0x20FFFFFF),
  );

  // ──────────────────────────────────────────
  // 5. ARCTIC ICE
  // ──────────────────────────────────────────
  static const arcticIce = BoardTheme(
    name: 'Arctic Ice',
    description: 'Crystal frost',
    type: BoardThemeType.arcticIce,

    backgroundColors: [
      Color(0xFFB8D0E0),
      Color(0xFFA0C0D4),
      Color(0xFF88B0C8),
    ],

    boardFillColors: [
      Color(0xFF8898A8),
      Color(0xFF748898),
      Color(0xFF607888),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFA0B0C0),
    boardBorderWidth: 3.0,
    boardInnerBorderColor: Color(0x30FFFFFF),
    boardShadowColor: Color(0x40000000),
    boardRimLight: Color(0x40FFFFFF),
    boardRimShadow: Color(0xFF485868),
    boardTextureOpacity: 0.03,

    slotColors: [Color(0xFF384450), Color(0xFF445060)],
    slotRimColor: Color(0x25FFFFFF),
    slotShadowColor: Color(0x70000000),

    blackMarbleColors: [
      Color(0xFF2898A0),
      Color(0xFF186878),
      Color(0xFF084050),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFC0F8FF),

    whiteMarbleColors: [
      Color(0xFFFFFFFF),
      Color(0xFFECF4FA),
      Color(0xFFD4E4F0),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x50000000),
    whiteHighlightOpacity: 0.90,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFF448AFF),
    selectionRing: Color(0xFF2962FF),
    hintColor: Color(0xFF448AFF),
    hintGlow: Color(0x50448AFF),
    pushTargetColor: Color(0xFFFF5252),

    accent: Color(0xFF2979FF),
    accentLight: Color(0x252979FF),
    surfaceColor: Color(0xFF3A5060),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF445868),
    textPrimary: Color(0xFFF0F4F8),
    textSecondary: Color(0xAAF0F4F8),
    scoreFilled: Color(0xFF2979FF),
    scoreEmpty: Color(0x18000044),
  );

  // ──────────────────────────────────────────
  // 6. MIDNIGHT GOLD
  // ──────────────────────────────────────────
  static const midnightGold = BoardTheme(
    name: 'Midnight Gold',
    description: 'Bronze & emerald luxury',
    type: BoardThemeType.midnightGold,

    backgroundColors: [
      Color(0xFF141830),
      Color(0xFF0E1228),
      Color(0xFF080C20),
    ],

    boardFillColors: [
      Color(0xFFC89858),
      Color(0xFFB08048),
      Color(0xFF987038),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFFD8A868),
    boardBorderWidth: 3.5,
    boardInnerBorderColor: Color(0x30000000),
    boardShadowColor: Color(0x60000000),
    boardRimLight: Color(0x40FFFFFF),
    boardRimShadow: Color(0xFF685028),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.05,

    slotColors: [Color(0xFF182040), Color(0xFF202850)],
    slotRimColor: Color(0x22FFFFFF),
    slotShadowColor: Color(0x88000000),

    blackMarbleColors: [
      Color(0xFF30A868),
      Color(0xFF187848),
      Color(0xFF085030),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.55,
    blackHighlightColor: Color(0xFFB0FFD8),

    whiteMarbleColors: [
      Color(0xFFFFF8E0),
      Color(0xFFECDCB8),
      Color(0xFFD8C498),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.80,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFFD740),
    selectionRing: Color(0xFFFFC400),
    hintColor: Color(0xFFFFD740),
    hintGlow: Color(0x60FFD740),
    pushTargetColor: Color(0xFFFF5252),

    accent: Color(0xFFFFB300),
    accentLight: Color(0x25FFB300),
    surfaceColor: Color(0xFF0E1228),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF181C38),
    textPrimary: Color(0xFFF0ECE0),
    textSecondary: Color(0xAAF0ECE0),
    scoreFilled: Color(0xFFFFB300),
    scoreEmpty: Color(0x20FFFFFF),
  );

  // ──────────────────────────────────────────
  // 7. VOLCANIC ASH
  // ──────────────────────────────────────────
  static const volcanicAsh = BoardTheme(
    name: 'Volcanic Ash',
    description: 'Dark stone & ember',
    type: BoardThemeType.volcanicAsh,

    backgroundColors: [
      Color(0xFF2A2428),
      Color(0xFF201A1E),
      Color(0xFF181218),
    ],

    boardFillColors: [
      Color(0xFF807068),
      Color(0xFF6A5C54),
      Color(0xFF584C44),
    ],
    boardFillStops: [0.0, 0.5, 1.0],
    boardBorderColor: Color(0xFF988478),
    boardBorderWidth: 3.0,
    boardInnerBorderColor: Color(0x25FFFFFF),
    boardShadowColor: Color(0x55000000),
    boardRimLight: Color(0x30FFFFFF),
    boardRimShadow: Color(0xFF383028),
    boardTextureColor: Color(0xFF000000),
    boardTextureOpacity: 0.06,

    slotColors: [Color(0xFF2C2420), Color(0xFF382E28)],
    slotRimColor: Color(0x18FFFFFF),
    slotShadowColor: Color(0x90000000),

    blackMarbleColors: [
      Color(0xFFE88830),
      Color(0xFFC86818),
      Color(0xFFA04808),
    ],
    blackMarbleStops: [0.0, 0.45, 1.0],
    blackMarbleShadow: Color(0x80000000),
    blackHighlightOpacity: 0.60,
    blackHighlightColor: Color(0xFFFFD8A0),

    whiteMarbleColors: [
      Color(0xFFF0F0F4),
      Color(0xFFD0D0D8),
      Color(0xFFB4B4BC),
    ],
    whiteMarbleStops: [0.0, 0.45, 1.0],
    whiteMarbleShadow: Color(0x60000000),
    whiteHighlightOpacity: 0.85,
    whiteHighlightColor: Color(0xFFFFFFFF),

    selectionGlow: Color(0xFFFF9100),
    selectionRing: Color(0xFFFF6D00),
    hintColor: Color(0xFFFF9100),
    hintGlow: Color(0x55FF9100),
    pushTargetColor: Color(0xFFFF1744),

    accent: Color(0xFFFF9100),
    accentLight: Color(0x25FF9100),
    surfaceColor: Color(0xFF201A1E),
    surfaceBorder: Color(0x20FFFFFF),
    cardColor: Color(0xFF2A2428),
    textPrimary: Color(0xFFF0ECE8),
    textSecondary: Color(0xAAF0ECE8),
    scoreFilled: Color(0xFFFF9100),
    scoreEmpty: Color(0x20FFFFFF),
  );

  static const List<BoardTheme> all = [
    royalArena,
    woodClassic,
    oceanBreeze,
    emeraldStone,
    rosewood,
    arcticIce,
    midnightGold,
    volcanicAsh,
  ];

  static BoardTheme fromType(BoardThemeType type) {
    return all.firstWhere((t) => t.type == type);
  }
}