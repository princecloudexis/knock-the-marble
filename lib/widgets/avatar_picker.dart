import 'package:flutter/material.dart';
import '../models/avatar_data.dart';

class AvatarPicker extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AvatarPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  // Category filters
  static const List<_AvatarCategory> _categories = [
    _AvatarCategory('All', Icons.apps_rounded, null),
    _AvatarCategory('Men', Icons.man_rounded, _FilterType.men),
    _AvatarCategory('Women', Icons.woman_rounded, _FilterType.women),
    _AvatarCategory('Fun', Icons.emoji_emotions_rounded, _FilterType.fun),
  ];

  _FilterType? _activeFilter;

  List<AvatarData> get _filteredAvatars {
    switch (_activeFilter) {
      case _FilterType.men:
        return AvatarData.avatars
            .where((a) => _menIndices.contains(a.index))
            .toList();
      case _FilterType.women:
        return AvatarData.avatars
            .where((a) => _womenIndices.contains(a.index))
            .toList();
      case _FilterType.fun:
        return AvatarData.avatars
            .where((a) => _funIndices.contains(a.index))
            .toList();
      case null:
        return AvatarData.avatars;
    }
  }

  // Index groups
  static const _menIndices = {0, 1, 2, 3, 8, 9, 10, 11, 16, 17, 18, 19, 24, 25};
  static const _womenIndices = {4, 5, 6, 7, 12, 13, 14, 15, 20, 21, 22, 23};
  static const _funIndices = {24, 25, 26, 27, 28, 29, 30, 31};

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAvatars;

    return Column(
      children: [
        // ── Category Filter Chips ──
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isActive = _activeFilter == cat.filter;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _activeFilter = cat.filter;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isActive
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isActive
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 14,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 18),

        // ── Avatar Grid ──
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final avatar = filtered[index];
            final isSelected = avatar.index == widget.selectedIndex;

            return GestureDetector(
              onTap: () => widget.onSelect(avatar.index),
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Column(
                  children: [
                    // ── Avatar Circle ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: avatar.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.08),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      avatar.glowColor.withOpacity(0.55),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color:
                                      avatar.glowColor.withOpacity(0.25),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Emoji face
                          Text(
                            avatar.emoji,
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 26,
                            ),
                          ),

                          // Selected checkmark
                          if (isSelected)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 11,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // ── Name label ──
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                        fontSize: isSelected ? 9.5 : 9,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      child: Text(
                        avatar.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum _FilterType { men, women, fun }

class _AvatarCategory {
  final String label;
  final IconData icon;
  final _FilterType? filter;

  const _AvatarCategory(this.label, this.icon, this.filter);
}