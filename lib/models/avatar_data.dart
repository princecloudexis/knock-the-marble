import 'package:flutter/material.dart';

class AvatarData {
  final int index;
  final String name;
  final String emoji;
  final List<Color> gradientColors;
  final Color glowColor;

  const AvatarData({
    required this.index,
    required this.name,
    required this.emoji,
    required this.gradientColors,
    required this.glowColor,
  });

  static const List<AvatarData> avatars = [
    // ══════════════════════════════
    // ROW 1 — MEN FACES
    // ══════════════════════════════
    AvatarData(
      index: 0,
      name: 'James',
      emoji: '👨',
      gradientColors: [Color(0xFF6366F1), Color(0xFF3730A3)],
      glowColor: Color(0xFF6366F1),
    ),
    AvatarData(
      index: 1,
      name: 'Marcus',
      emoji: '👨🏿',
      gradientColors: [Color(0xFFEF4444), Color(0xFF991B1B)],
      glowColor: Color(0xFFEF4444),
    ),
    AvatarData(
      index: 2,
      name: 'Carlos',
      emoji: '👨🏽',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFB45309)],
      glowColor: Color(0xFFF59E0B),
    ),
    AvatarData(
      index: 3,
      name: 'Ravi',
      emoji: '👨🏾',
      gradientColors: [Color(0xFF06B6D4), Color(0xFF155E75)],
      glowColor: Color(0xFF06B6D4),
    ),

    // ══════════════════════════════
    // ROW 2 — WOMEN FACES
    // ══════════════════════════════
    AvatarData(
      index: 4,
      name: 'Sophie',
      emoji: '👩',
      gradientColors: [Color(0xFFA855F7), Color(0xFF6B21A8)],
      glowColor: Color(0xFFA855F7),
    ),
    AvatarData(
      index: 5,
      name: 'Amara',
      emoji: '👩🏿',
      gradientColors: [Color(0xFFF97316), Color(0xFFC2410C)],
      glowColor: Color(0xFFF97316),
    ),
    AvatarData(
      index: 6,
      name: 'Maria',
      emoji: '👩🏽',
      gradientColors: [Color(0xFF10B981), Color(0xFF064E3B)],
      glowColor: Color(0xFF10B981),
    ),
    AvatarData(
      index: 7,
      name: 'Priya',
      emoji: '👩🏾',
      gradientColors: [Color(0xFFEC4899), Color(0xFF831843)],
      glowColor: Color(0xFFEC4899),
    ),

    // ══════════════════════════════
    // ROW 3 — STYLED MEN
    // ══════════════════════════════
    AvatarData(
      index: 8,
      name: 'Blondie',
      emoji: '👱‍♂️',
      gradientColors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
      glowColor: Color(0xFF3B82F6),
    ),
    AvatarData(
      index: 9,
      name: 'Curly',
      emoji: '👨🏻‍🦱',
      gradientColors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
      glowColor: Color(0xFF8B5CF6),
    ),
    AvatarData(
      index: 10,
      name: 'Silver',
      emoji: '👨🏻‍🦳',
      gradientColors: [Color(0xFF64748B), Color(0xFF1E293B)],
      glowColor: Color(0xFF64748B),
    ),
    AvatarData(
      index: 11,
      name: 'Beardo',
      emoji: '🧔',
      gradientColors: [Color(0xFF14B8A6), Color(0xFF134E4A)],
      glowColor: Color(0xFF14B8A6),
    ),

    // ══════════════════════════════
    // ROW 4 — STYLED WOMEN
    // ══════════════════════════════
    AvatarData(
      index: 12,
      name: 'Goldie',
      emoji: '👱‍♀️',
      gradientColors: [Color(0xFFF59E0B), Color(0xFF92400E)],
      glowColor: Color(0xFFF59E0B),
    ),
    AvatarData(
      index: 13,
      name: 'Curls',
      emoji: '👩🏻‍🦱',
      gradientColors: [Color(0xFFE11D48), Color(0xFF881337)],
      glowColor: Color(0xFFE11D48),
    ),
    AvatarData(
      index: 14,
      name: 'Redhead',
      emoji: '👩‍🦰',
      gradientColors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
      glowColor: Color(0xFFEF4444),
    ),
    AvatarData(
      index: 15,
      name: 'Hijabi',
      emoji: '🧕',
      gradientColors: [Color(0xFF7C3AED), Color(0xFF2E1065)],
      glowColor: Color(0xFF7C3AED),
    ),

    // ══════════════════════════════
    // ROW 5 — MORE DIVERSE MEN
    // ══════════════════════════════
    AvatarData(
      index: 16,
      name: 'Bald',
      emoji: '👨‍🦲',
      gradientColors: [Color(0xFF84CC16), Color(0xFF3F6212)],
      glowColor: Color(0xFF84CC16),
    ),
    AvatarData(
      index: 17,
      name: 'Mustache',
      emoji: '👨🏽‍🦳',
      gradientColors: [Color(0xFF374151), Color(0xFF111827)],
      glowColor: Color(0xFF6B7280),
    ),
    AvatarData(
      index: 18,
      name: 'Elder',
      emoji: '👴',
      gradientColors: [Color(0xFF78716C), Color(0xFF44403C)],
      glowColor: Color(0xFF78716C),
    ),

    // ══════════════════════════════
    // ROW 6 — MORE DIVERSE WOMEN
    // ══════════════════════════════
    AvatarData(
      index: 20,
      name: 'Queen',
      emoji: '👸',
      gradientColors: [Color(0xFFD946EF), Color(0xFF86198F)],
      glowColor: Color(0xFFD946EF),
    ),
    AvatarData(
      index: 21,
      name: 'Granny',
      emoji: '👵',
      gradientColors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      glowColor: Color(0xFFFB923C),
    ),
    AvatarData(
      index: 22,
      name: 'Bun',
      emoji: '👩🏻',
      gradientColors: [Color(0xFFF472B6), Color(0xFFBE185D)],
      glowColor: Color(0xFFF472B6),
    ),
    AvatarData(
      index: 23,
      name: 'Afro',
      emoji: '👩🏿‍🦱',
      gradientColors: [Color(0xFF34D399), Color(0xFF059669)],
      glowColor: Color(0xFF34D399),
    ),

    // ══════════════════════════════
    // ROW 7 — FUN / SPECIAL
    // ══════════════════════════════
    AvatarData(
      index: 24,
      name: 'King',
      emoji: '🤴',
      gradientColors: [Color(0xFFEAB308), Color(0xFFA16207)],
      glowColor: Color(0xFFEAB308),
    ),

    // ══════════════════════════════
    // ROW 8 — EXPRESSIVE FACES
    // ══════════════════════════════
    AvatarData(
      index: 28,
      name: 'Cool',
      emoji: '😎',
      gradientColors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
      glowColor: Color(0xFF6D28D9),
    ),
    AvatarData(
      index: 29,
      name: 'Wink',
      emoji: '😜',
      gradientColors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
      glowColor: Color(0xFFF43F5E),
    ),
    AvatarData(
      index: 30,
      name: 'Nerd',
      emoji: '🤓',
      gradientColors: [Color(0xFF059669), Color(0xFF065F46)],
      glowColor: Color(0xFF059669),
    ),
    AvatarData(
      index: 31,
      name: 'Monocle',
      emoji: '🧐',
      gradientColors: [Color(0xFFB45309), Color(0xFF78350F)],
      glowColor: Color(0xFFB45309),
    ),
  ];

  static AvatarData getAvatar(int index) {
    if (index < 0 || index >= avatars.length) return avatars[0];
    return avatars[index];
  }
}