import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_spacing.dart';

/// The hand-drawn illustration set, in Frigo's own muted palette.
///
/// Each scene is a full-bleed colour block with the character cropped by the
/// frame, the way editorial illustration is composed — not a small figure
/// floating on white. A tiled grain is composited over the top, because
/// `flutter_svg` cannot render SVG filters and flat vector without texture
/// reads as clip art.
enum FrigoArt {
  emptyKitchen('empty_kitchen'),
  emptyShopping('empty_shopping'),
  emptyRecipes('empty_recipes'),
  scanSuccess('scan_success'),
  offline('offline'),
  onboardingScan('onboarding_scan'),
  onboardingTrack('onboarding_track'),
  onboardingCook('onboarding_cook');

  const FrigoArt(this.file);
  final String file;

  String get path => 'assets/illustrations/$file.svg';
}

class FrigoIllustration extends StatelessWidget {
  const FrigoIllustration(
    this.art, {
    this.height = 200,
    this.width,
    this.radius = AppRadii.cardLg,
    this.semanticLabel,
    super.key,
  });

  final FrigoArt art;
  final double height;
  final double? width;
  final BorderRadius radius;
  final String? semanticLabel;

  /// Tileable 128px noise. Kept subtle on purpose — grain you notice is too
  /// much grain.
  static const _grain = 'assets/illustrations/grain.png';
  static const _grainOpacity = 0.55;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.asset(
              art.path,
              fit: BoxFit.cover,
              semanticsLabel: semanticLabel,
              // Decorative: the surrounding copy carries the meaning.
              excludeFromSemantics: semanticLabel == null,
            ),
            // The grain never changes, so keep it off the parent's repaint
            // path - it would otherwise re-composite behind every animation.
            RepaintBoundary(
              child: IgnorePointer(
                child: Opacity(
                  opacity: _grainOpacity,
                  child: Image.asset(
                    _grain,
                    repeat: ImageRepeat.repeat,
                    fit: BoxFit.none,
                    alignment: Alignment.topLeft,
                    // Nearest-neighbour keeps the speckles crisp instead of
                    // smearing them into a flat haze when the tile is scaled.
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
