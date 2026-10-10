import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// The Frigo app mark — a fridge with a fresh sprout, rendered from the bundled
/// icon asset with a soft shadow.
class FrigoLogo extends StatelessWidget {
  const FrigoLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: AppColors.floatingShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/logo/frigo_logo_rounded.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.primary,
          alignment: Alignment.center,
          child: Icon(Icons.kitchen_rounded,
              color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Horizontal lockup: mark + "Frigo".
class FrigoWordmark extends StatelessWidget {
  const FrigoWordmark({super.key, this.markSize = 44});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FrigoLogo(size: markSize),
        SizedBox(width: markSize * 0.32),
        Text(
          'Frigo',
          style: GoogleFonts.inter(
            fontSize: markSize * 0.72,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
