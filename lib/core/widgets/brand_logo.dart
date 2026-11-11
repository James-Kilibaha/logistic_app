import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../branding.dart';
import '../theme/app_theme.dart';

/// Logo ya kampuni (kutoka kwa server), au herufi za kwanza za jina lake kama haina logo.
class BrandLogo extends StatelessWidget {
  final double size;

  /// Kisanduku cheupe chenye kivuli (Login) au mpaka mwembamba (menyu).
  final bool elevated;

  const BrandLogo({super.key, this.size = 40, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final brand = BrandingController.to;
      final url = brand.logoUrl;
      final name = brand.current.value.displayName;
      final initials = name
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w.substring(0, 1).toUpperCase())
          .join();

      final Widget fallback = Center(
        child: Text(
          initials.isEmpty ? 'L' : initials,
          style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: size * .36, letterSpacing: .5),
        ),
      );

      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * (elevated ? .26 : .28)),
          border: elevated ? null : Border.all(color: p.border),
          boxShadow: elevated
              ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))]
              : null,
        ),
        child: url == null
            ? fallback
            : brandImage(url, fallback),
      );
    });
  }
}

/// Picha ya logo: web -> Image.network (CachedNetworkImage kwenye web inaweza kuonyesha kisanduku cheusi);
/// simu/desktop -> CachedNetworkImage (inahifadhiwa, haipakuliwi kila mara).
Widget brandImage(String url, Widget fallback) {
  if (kIsWeb) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.contain,
    fadeInDuration: const Duration(milliseconds: 150),
    placeholder: (_, _) => fallback,
    errorWidget: (_, _, _) => fallback,
  );
}
