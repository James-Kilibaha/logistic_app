import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/app_controller.dart';
import 'app/routes.dart';
import 'app/translations.dart';
import 'core/activity_tracker.dart';
import 'core/client_info.dart';
import 'core/api/api_client.dart';
import 'core/branding.dart';
import 'core/session.dart';
import 'core/widgets/brand_splash.dart';
import 'core/widgets/feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.init();
  // Splash yenye logo na jina la kampuni (vilivyohifadhiwa) wakati app inajiandaa
  runApp(BrandSplash.app());
  final shown = DateTime.now();
  await ClientInfo.init();

  // Kampuni (jina, logo, rangi): iliyohifadhiwa inaonyeshwa papo hapo, mpya inapakuliwa.
  final branding = Get.put(BrandingController(), permanent: true);
  await branding.load();
  // simu: splash ionekane angalau kidogo (isimulike tu)
  if (!kIsWeb) {
    final left = const Duration(milliseconds: 700) - DateTime.now().difference(shown);
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  final app = Get.put(AppController(), permanent: true);
  Api.onUnauthorized = () => app.logout(expired: true);
  Api.onPasswordChangeRequired = app.requirePasswordChange;
  Api.onPaymentRequired = app.paymentRequired;
  Api.onCompanySuspended = app.companySuspended;

  runApp(const LogisticApp());
}

class LogisticApp extends StatelessWidget {
  const LogisticApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rangi na jina vinabadilika kampuni ikibadilisha branding yake.
    return Obx(() {
      final brand = BrandingController.to;
      return _app(brand.current.value.displayName, brand.lightTheme, brand.darkTheme);
    });
  }

  Widget _app(String title, ThemeData light, ThemeData dark) {
    return GetMaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      routingCallback: (routing) => ActivityTracker.route(routing?.current),
      theme: light,
      darkTheme: dark,
      themeMode: Session.themeMode,
      translations: AppTranslations(),
      locale: Session.locale,
      fallbackLocale: const Locale('sw', 'TZ'),
      scaffoldMessengerKey: messengerKey,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
      initialRoute: !Session.isLoggedIn
          ? Routes.login
          : ((Session.user?.mustChangePassword ?? false) ? Routes.changePassword : Routes.home),
      getPages: appPages,
      unknownRoute: unknownPage, // URL isiyojulikana haionyeshi kurasa za ndani
      builder: (context, child) {
        // Maandishi yasikuzwe kupita kiasi kwenye simu zenye "font kubwa".
        final mq = MediaQuery.of(context);
        final scaler = mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
        return MediaQuery(data: mq.copyWith(textScaler: scaler), child: child ?? const SizedBox.shrink());
      },
    );
  }
}
