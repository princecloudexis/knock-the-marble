import 'package:flutter/material.dart';
import '../models/avatar_data.dart';

class AvatarWidget extends StatelessWidget {
  final int avatarIndex;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const AvatarWidget({
    super.key,
    required this.avatarIndex,
    this.size = 40,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarData.getAvatar(avatarIndex);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: avatar.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: avatar.gradientColors[0].withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
}