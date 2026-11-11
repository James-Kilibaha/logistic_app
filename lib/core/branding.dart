import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/company.dart';
import '../data/repositories.dart';
import 'session.dart';
import 'web/web_branding.dart';
import 'theme/app_theme.dart';

/// Kampuni ambayo app inaitumikia sasa: jina, logo, rangi na hali ya subscription.
///
/// - Web kwenye domain ya kampuni (mf. ymg.co.tz au ymg.<platform>) : server inaitambua yenyewe.
/// - App ya simu / web kwenye domain ya mfumo : mtumiaji anaandika "code ya kampuni" mara moja
///   (inahifadhiwa na kutumwa kama `X-Company` kwenye kila ombi).
class BrandingController extends GetxController {
  static BrandingController get to => Get.find<BrandingController>();

  final Rx<Branding> current = Branding.none.obs;
  final Rxn<SubscriptionState> subscription = Rxn<SubscriptionState>();

  bool get hasCompany => current.value.resolved;

  @override
  void onInit() {
    super.onInit();
    final cached = Session.brandingJson;
    if (cached != null) current.value = Branding.fromJson(cached);
    // web: favicon, rangi ya browser na title vifuate kampuni (sasa na kila branding ikibadilika)
    ever<Branding>(current, (_) => syncWeb());
    syncWeb();
  }

  /// Web: logo kama favicon, rangi ya kampuni kwenye browser, jina kwenye title na splash.
  void syncWeb() {
    final b = current.value;
    final c = b.primary;
    applyWebBranding(
      name: b.displayName,
      logoUrl: logoUrl,
      primaryHex: c == null
          ? null
          : '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    );
  }

  /// Inapakua branding (inatumia iliyohifadhiwa kama server haipatikani).
  Future<void> load() async {
    try {
      final json = await CompanyRepo.brandingJson(slug: Session.companySlug.isEmpty ? null : Session.companySlug)
          .timeout(const Duration(seconds: 6));
      final b = Branding.fromJson(json);
      if (b.resolved) {
        await _apply(json, b);
      } else if (!Session.companyLocked) {
        // code iliyohifadhiwa haipo tena (au haijawekwa) - mtumiaji ataulizwa code
        current.value = b;
        await Session.saveBranding(null);
      }
    } catch (_) {
      // tunaendelea na iliyohifadhiwa
    }
  }

  /// Kuchagua kampuni kwa code yake. Inarudisha `false` kama code haipo.
  Future<bool> useCompany(String slug) async {
    final code = slug.trim().toLowerCase();
    if (code.isEmpty) return false;
    final json = await CompanyRepo.brandingJson(slug: code);
    final b = Branding.fromJson(json);
    if (!b.resolved) return false;
    await _apply(json, b);
    return true;
  }

  /// Kubadilisha kampuni (app ya simu): code inafutwa, mtumiaji ataandika nyingine.
  Future<void> forgetCompany() async {
    if (Session.companyLocked) return;
    await Session.saveCompany('');
    await Session.saveBranding(null);
    subscription.value = null;
    current.value = Branding(resolved: false, slug: '', name: current.value.platform.name,
        platform: current.value.platform);
  }

  Future<void> _apply(Map<String, dynamic> json, Branding b) async {
    current.value = b;
    await Session.saveBranding(json);
    if (b.slug.isNotEmpty && Session.companySlug != b.slug) await Session.saveCompany(b.slug);
  }

  /// Baada ya kuingia: branding ya hivi karibuni + hali ya subscription + moduli za mpango.
  Future<void> refreshCompany() async {
    try {
      final res = await CompanyRepo.me();
      final b = res['branding'];
      if (b is Map) await _apply(Map<String, dynamic>.from(b), Branding.fromJson(Map<String, dynamic>.from(b)));
      final s = res['subscription'];
      if (s is Map) subscription.value = SubscriptionState.fromJson(Map<String, dynamic>.from(s));
    } catch (_) {
      // si muhimu kuzuia kazi
    }
  }

  /// URL kamili ya logo (au `null` = tumia alama ya kawaida).
  String? get logoUrl {
    final url = current.value.logoUrl;
    return url == null ? null : Session.absoluteUrl(url);
  }

  ThemeData get lightTheme => AppTheme.light(primary: current.value.primary, accent: current.value.accent);

  ThemeData get darkTheme => AppTheme.dark(primary: current.value.primary, accent: current.value.accent);
}
