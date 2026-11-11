import 'dart:async';

import '../app/app_controller.dart';
import 'api/api_client.dart';
import 'session.dart';

/// Inaripoti kurasa ambazo mtumiaji wa kampuni anafungua -> super admin anaziona kwenye "Shughuli".
/// Haizuii kazi: kosa lolote linapuuzwa. Haifanyi kazi super admin akiangalia kampuni (kusoma tu).
class ActivityTracker {
  ActivityTracker._();

  static String? _last;

  /// Njia ambazo si kurasa za kampuni (kuingia, admin panel, ukurasa wa umma ...).
  static const _skip = {'/login', '/signup', '/track', '/super-admin', '/change-password', '/'};

  static void page(String page, {String? title}) {
    if (!Session.isLoggedIn || AppController.to.isViewOnly) return;
    final clean = page.startsWith('/') ? page.substring(1) : page;
    if (clean.isEmpty || clean == _last) return;
    _last = clean;
    unawaited(Api.post('activity/view', {'page': clean, if (title != null) 'title': title}).then<void>((_) {},
        onError: (Object _) {}));
  }

  /// Kutoka `routingCallback` ya GetMaterialApp (kurasa zenye route yake mf. /company, /subscription).
  static void route(String? name) {
    if (name == null) return;
    final path = name.split('?').first;
    if (_skip.contains(path)) return;
    page(path);
  }

  static void reset() => _last = null;
}
