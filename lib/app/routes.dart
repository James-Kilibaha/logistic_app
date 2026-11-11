import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/session.dart';

import '../features/auth/change_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/company/company_page.dart';
import '../features/company/subscription_page.dart';
import '../features/company/whatsapp_page.dart';
import '../features/payments/online_pay.dart';
import '../features/shell/shell_page.dart';
import '../features/super_admin/super_admin_page.dart';
import '../features/track/track_page.dart';

abstract class Routes {
  static const login = '/login';
  static const home = '/';
  static const changePassword = '/change-password';

  /// Ukurasa wa umma wa kufuatilia mzigo (hauhitaji kuingia).
  static const track = '/track';

  /// Kampuni mpya inajisajili (majaribio ya bure). `/register` ni jina lingine la ukurasa huu.
  static const signup = '/signup';
  static const register = '/register';

  /// Njia isiyojulikana (mf. kuandika URL vibaya) - inaelekezwa kuingia au nyumbani.
  static const notFound = '/not-found';

  /// Wasifu wa kampuni: jina, logo, rangi na mipangilio ya biashara.
  static const company = '/company';

  /// Subscription: mpango, matumizi, kulipia.
  static const subscription = '/subscription';

  /// Kuunganisha WhatsApp Business ya kampuni (Meta Cloud API).
  static const whatsapp = '/company/whatsapp';

  /// Kuunganisha AzamPay (malipo ya simu: M-Pesa, Tigo, Airtel ...) ya kampuni.
  static const onlinePay = '/company/mobile-payments';

  /// Admin panel yako (super admin): kampuni zote, mipango, malipo. Web: https://domain/#/super-admin
  static const superAdmin = '/super-admin';
}

/// Kurasa za ndani: bila kuingia, mtumiaji anarudishwa kwenye ukurasa wa kuingia
/// (hata akiandika URL moja kwa moja, mf. /#/ au /#/company).
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) => Session.isLoggedIn ? null : const RouteSettings(name: Routes.login);
}

/// Njia isiyojulikana: aliyeingia -> nyumbani, asiyeingia -> kuingia.
class _NotFoundRedirect extends StatefulWidget {
  const _NotFoundRedirect();

  @override
  State<_NotFoundRedirect> createState() => _NotFoundRedirectState();
}

class _NotFoundRedirectState extends State<_NotFoundRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAllNamed(Session.isLoggedIn ? Routes.home : Routes.login);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

final GetPage<dynamic> unknownPage = GetPage(name: Routes.notFound, page: () => const _NotFoundRedirect());

final List<GetPage<dynamic>> appPages = [
  // umma (hazihitaji kuingia)
  GetPage(name: Routes.login, page: () => const LoginPage()),
  GetPage(name: Routes.track, page: () => const TrackPage()),
  GetPage(name: Routes.signup, page: () => const SignupPage()),
  GetPage(name: Routes.register, page: () => const SignupPage()),
  // admin panel yako ina kuingia kwake (akaunti ya super admin)
  GetPage(name: Routes.superAdmin, page: () => const SuperAdminPage()),
  // ndani: lazima mtumiaji wa kampuni awe ameingia
  GetPage(name: Routes.home, page: () => const ShellPage(), binding: ShellBinding(), middlewares: [AuthGuard()]),
  GetPage(name: Routes.changePassword, page: () => const ChangePasswordPage(forced: true), middlewares: [AuthGuard()]),
  GetPage(name: Routes.company, page: () => const CompanyPage(), middlewares: [AuthGuard()]),
  GetPage(name: Routes.subscription, page: () => const SubscriptionPage(), middlewares: [AuthGuard()]),
  GetPage(name: Routes.whatsapp, page: () => const WhatsappPage(), middlewares: [AuthGuard()]),
  GetPage(name: Routes.onlinePay, page: () => const OnlinePaySettingsPage(), middlewares: [AuthGuard()]),
  unknownPage,
];
