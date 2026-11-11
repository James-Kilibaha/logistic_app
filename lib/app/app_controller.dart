import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/branding.dart';
import '../core/session.dart';
import '../core/widgets/feedback.dart';
import '../data/lookups.dart';
import '../data/models/user.dart';
import '../data/repositories.dart';
import 'routes.dart';

/// Hali ya app nzima: mtumiaji aliyeingia, ruhusa zake, mandhari na lugha.
class AppController extends GetxController {
  static AppController get to => Get.find<AppController>();

  final Rx<ThemeMode> themeMode = Session.themeMode.obs;
  final Rxn<AppUser> user = Rxn<AppUser>(Session.user);
  final RxList<Permission> permissions = <Permission>[].obs;

  /// Inaongezeka kila data inapobadilika (orodha zinajipakia upya zikiiona).
  final RxInt changes = 0.obs;

  bool _loggingOut = false;

  @override
  void onInit() {
    super.onInit();
    _applyPermissions(Session.permissionsJson);
  }

  void _applyPermissions(List<dynamic> json) {
    permissions.assignAll(
      json.whereType<Map>().map((e) => Permission.fromJson(Map<String, dynamic>.from(e))),
    );
  }

  /// Moduli za ziada zinazotegemea mpango wa subscription (sawa na backend: saas/plan/service.py).
  static const Set<String> planModules = {
    'WHATSAPP', 'BROADCAST', 'QUOTE', 'CLAIM', 'CASHUP', 'PROFIT', 'IMPORT', 'AUDIT', 'ACCOUNTING', 'PAYROLL',
  };

  /// Moduli hii iko kwenye mpango wa kampuni?
  bool inPlan(AppModule module) {
    if (module == AppModule.backup) return false; // backup sasa ni ya mtoa huduma (admin panel)
    if (!planModules.contains(module.code)) return true;
    final sub = BrandingController.to.subscription.value;
    return sub == null || sub.modules.contains(module.code);
  }

  /// Ruhusa ya kufanya [action] kwenye [module]. Kama ruhusa bado hazijapakuliwa,
  /// tunaruhusu (backend itakataa yenyewe ikiwa hairuhusiwi).
  bool can(AppModule module, [AppAction action = AppAction.select]) {
    // super admin akiangalia kampuni: anaona kila ukurasa (kubadilisha kunazuiwa na server)
    if (isViewOnly && action == AppAction.select && module != AppModule.backup) return true;
    if (!inPlan(module)) return false;
    if (permissions.isEmpty) return true;
    for (final p in permissions) {
      if (p.module == module) return p.allows(action);
    }
    return false;
  }

  void notifyChanged() => changes.value++;

  Future<void> refreshPermissions() async {
    try {
      final json = await UserRepo.myPermissionsJson();
      await Session.savePermissions(json);
      _applyPermissions(json);
    } catch (_) {
      // tunaendelea na zilizohifadhiwa
    }
  }

  /// Inarudisha `null` ikiwa ameingia; au taarifa za hatua ya pili (2FA) `{otpToken, phoneHint, ...}`.
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final res = await AuthRepo.login(username, password);
    if (res['otpRequired'] == true) return res;
    await _finishLogin(res);
    return null;
  }

  /// Hatua ya pili ya kuingia: code ya SMS.
  Future<void> verifyOtp(String otpToken, String code) async {
    final res = await AuthRepo.verifyOtp(otpToken, code);
    await _finishLogin(res);
  }

  Future<void> _finishLogin(Map<String, dynamic> res) async {
    await applyAuthResponse(res);
    _loggingOut = false;
    await Future.wait([refreshPermissions(), BrandingController.to.refreshCompany()]);
  }

  DateTime? _paymentNoticeAt;

  /// Server imejibu 402: subscription imeisha au huduma haipo kwenye mpango.
  void paymentRequired(String message, String? code) {
    BrandingController.to.refreshCompany();
    final now = DateTime.now();
    if (_paymentNoticeAt != null && now.difference(_paymentNoticeAt!) < const Duration(seconds: 8)) return;
    _paymentNoticeAt = now;
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) {
      Toast.warning(message, title: 'subscription'.tr);
      return;
    }
    final canPay = can(AppModule.setting, AppAction.update);
    showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_outlined, size: 36),
        title: Text(code == 'SUBSCRIPTION_EXPIRED' ? 'subExpiredTitle'.tr : 'subUpgradeTitle'.tr,
            textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(canPay ? message : '$message\n\n${'subAskAdmin'.tr}', textAlign: TextAlign.center),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr)),
          if (canPay)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Get.toNamed(Routes.subscription);
              },
              child: Text('subPayNow'.tr),
            ),
        ],
      ),
    );
  }

  /// Akaunti ya kampuni imesimamishwa na mtoa huduma (403 COMPANY_SUSPENDED).
  Future<void> companySuspended(String message) async {
    if (Session.isLoggedIn) await logout();
    Toast.warning(message, title: 'companySuspended'.tr);
  }

  /// Inahifadhi token + mtumiaji kutoka /login, /auth/refresh au /auth/password.
  Future<void> applyAuthResponse(Map<String, dynamic> res) async {
    final token = (res['access_token'] ?? '').toString();
    final userJson = Map<String, dynamic>.from((res['user'] as Map?) ?? const {});
    await Session.saveLogin(token, userJson, refreshToken: (res['refresh_token'] ?? '').toString());
    user.value = AppUser.fromJson(userJson);
  }

  /// Ukurasa wa kwenda baada ya kuingia.
  String get homeRoute => (user.value?.mustChangePassword ?? false) ? Routes.changePassword : Routes.home;

  /// Server imesema lazima abadilishe nywila (428).
  void requirePasswordChange() {
    if (Get.currentRoute == Routes.changePassword) return;
    Get.offAllNamed(Routes.changePassword);
  }

  /// Super admin anaangalia kampuni (kusoma tu) - jina lake, au '' kwa mtumiaji wa kawaida.
  final RxString viewingAs = Session.viewAs.obs;

  bool get isViewOnly => viewingAs.value.isNotEmpty;

  /// Super admin anafungua app ya kampuni kama mtumiaji wake - KUANGALIA TU (kutoka /super-admin).
  Future<void> startViewAs(Map<String, dynamic> res) async {
    final company = res['company'];
    final slug = company is Map ? (company['slug'] ?? '').toString() : '';
    if (slug.isNotEmpty) await BrandingController.to.useCompany(slug);
    final userJson = Map<String, dynamic>.from((res['user'] as Map?) ?? const {});
    await Session.saveViewAsLogin((res['access_token'] ?? '').toString(), userJson, (res['viewer'] ?? '').toString());
    user.value = AppUser.fromJson(userJson.map((k, v) => MapEntry(k, k == 'mustChangePassword' ? false : v)));
    viewingAs.value = Session.viewAs.isEmpty ? 'super admin' : Session.viewAs;
    _loggingOut = false;
    await Future.wait([refreshPermissions(), BrandingController.to.refreshCompany()]);
    Get.offAllNamed(Routes.home);
  }

  Future<void> logout({bool expired = false}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    final wasViewing = isViewOnly;
    await Session.clearLogin();
    user.value = null;
    permissions.clear();
    viewingAs.value = '';
    if (Get.isRegistered<Lookups>()) Lookups.to.clear();
    if (wasViewing) {
      // kumaliza kuangalia kampuni: rudi kwenye admin panel (si ukurasa wa kuingia wa kampuni)
      await BrandingController.to.forgetCompany();
      Get.offAllNamed(Routes.superAdmin);
      if (expired) Toast.warning('viewAsExpired'.tr, title: 'sessionExpired'.tr);
      return;
    }
    Get.offAllNamed(Routes.login);
    if (expired) Toast.warning('sessionExpiredMsg'.tr, title: 'sessionExpired'.tr);
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await Session.saveThemeMode(mode);
  }

  Future<void> setLocale(Locale locale) async {
    await Session.saveLocale(locale);
    await Get.updateLocale(locale);
  }
}
