import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/enums.dart';
import '../../core/services/images/image_resolver.dart';
import '../../core/theme/app_colors.dart';

/// Rounded thumbnail for a food item.
///
/// Priority: a user photo ([photoPath]) → a stored URL ([imageUrl]) → a URL
/// resolved live from the name (curated CDN, then Wikipedia) → a tinted
/// category icon. Nothing here can break a layout.
class FoodImage extends StatefulWidget {
  const FoodImage({
    super.key,
    required this.name,
    required this.category,
    this.imageUrl,
    this.photoPath,
    this.size = 44,
    this.radius = 12,
  });

  final String name;
  final FoodCategory category;
  final String? imageUrl;
  final String? photoPath;
  final double size;
  final double radius;

  @override
  State<FoodImage> createState() => _FoodImageState();
}

class _FoodImageState extends State<FoodImage> {
  String? _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = widget.imageUrl ?? ImageResolver.instance.quick(widget.name);
    if (_resolved == null &&
        widget.photoPath == null &&
        AppConfig.networkImagesEnabled) {
      ImageResolver.instance.resolve(widget.name).then((url) {
        if (mounted && url != null) setState(() => _resolved = url);
      });
    }
  }

  @override
  void didUpdateWidget(FoodImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name || old.imageUrl != widget.imageUrl) {
      _resolved = widget.imageUrl ?? ImageResolver.instance.quick(widget.name);
      if (_resolved == null && AppConfig.networkImagesEnabled) {
        ImageResolver.instance.resolve(widget.name).then((url) {
          if (mounted && url != null) setState(() => _resolved = url);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(category: widget.category, size: widget.size);
    final borderRadius = BorderRadius.circular(widget.radius);
    final s = widget.size;

    Widget content;
    if (widget.photoPath != null && File(widget.photoPath!).existsSync()) {
      content = Image.file(File(widget.photoPath!), fit: BoxFit.cover);
    } else if (_resolved != null && AppConfig.networkImagesEnabled) {
      content = Padding(
        padding: EdgeInsets.all(s * 0.1),
        child: CachedNetworkImage(
          imageUrl: _resolved!,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 220),
          // Decode at the size actually drawn. Without this a 46px thumbnail
          // holds a full-resolution bitmap in memory, and a kitchen list of 20
          // items is enough to make a mid-range phone stutter.
          memCacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
              .round(),
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      );
    } else {
      content = fallback;
    }

    return Container(
      height: s,
      width: s,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.divider),
      ),
      child: content,
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.category, required this.size});
  final FoodCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(category.icon,
          size: size * 0.46, color: AppColors.textTertiary),
    );
  }
}
