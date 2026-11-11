import 'package:flutter/material.dart';

import '../../data/models/company.dart';
import '../session.dart';
import 'brand_logo.dart';

/// Skrini ya kwanza ya app (simu/desktop/web): logo na jina la kampuni (vilivyohifadhiwa) wakati app inajiandaa.
///
/// Splash ya mfumo wa simu (Android/iOS - kabla Flutter haijaanza) ni picha moja iliyojengwa ndani ya app,
/// kwa hiyo haiwezi kubadilika kwa kila kampuni; hii inafuata mara moja baada yake.
class BrandSplash extends StatelessWidget {
  final Branding branding;

  const BrandSplash({super.key, required this.branding});

  /// App ndogo ya kuonyesha splash kabla ya app kamili (main.dart).
  static Widget app() {
    final cached = Session.brandingJson;
    final b = cached != null ? Branding.fromJson(cached) : Branding.none;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: b.displayName,
      home: BrandSplash(branding: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = branding;
    final primary = b.primary ?? const Color(0xFF1F4FD8);
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final logo = b.logoUrl == null ? null : Session.absoluteUrl(b.logoUrl!);
    final name = b.displayName;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.substring(0, 1).toUpperCase())
        .join();
    final fallback = Center(
      child: Text(initials.isEmpty ? 'L' : initials,
          style: TextStyle(color: primary, fontSize: 40, fontWeight: FontWeight.w800)),
    );
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .9, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: logo == null
                    ? fallback
                    : brandImage(logo, fallback),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? Colors.white : primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: primary,
                  backgroundColor: primary.withValues(alpha: .15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
