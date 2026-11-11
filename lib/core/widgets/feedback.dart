import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Ufunguo wa ScaffoldMessenger ya app nzima (unawekwa kwenye GetMaterialApp).
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

enum _ToastKind { success, error, warning, info }

/// Ujumbe mfupi unaojitokeza chini (simu) au chini kulia (kompyuta).
class Toast {
  Toast._();

  static void success(String message, {String? title}) => _show(_ToastKind.success, title ?? 'done'.tr, message);

  static void info(String message, {String? title}) => _show(_ToastKind.info, title ?? 'info'.tr, message);

  static void warning(String message, {String? title}) => _show(_ToastKind.warning, title ?? 'attention'.tr, message);

  /// Inakubali [ApiException], String au kosa lolote.
  static void error(Object error, {String? title}) {
    if (error is ApiException) {
      if (error.isUnauthorized) return; // app inarudi Login yenyewe
      final t = title ??
          (error.isForbidden
              ? 'noPermission'.tr
              : error.isNetwork
                  ? 'noConnection'.tr
                  : 'failed'.tr);
      _show(error.isForbidden ? _ToastKind.warning : _ToastKind.error, t, error.message);
      return;
    }
    _show(_ToastKind.error, title ?? 'failed'.tr, error.toString().replaceFirst('Exception: ', ''));
  }

  static void _show(_ToastKind kind, String title, String message) {
    final messenger = messengerKey.currentState;
    final ctx = messengerKey.currentContext;
    if (messenger == null || ctx == null) return;

    final p = Theme.of(ctx).extension<AppPalette>() ?? AppPalette.light;
    final (Color color, IconData icon) = switch (kind) {
      _ToastKind.success => (p.success, Icons.check_circle_rounded),
      _ToastKind.error => (p.danger, Icons.error_rounded),
      _ToastKind.warning => (p.warning, Icons.lock_outline_rounded),
      _ToastKind.info => (p.info, Icons.info_rounded),
    };
    final bool wide = MediaQuery.sizeOf(ctx).width >= Breakpoints.medium;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          width: wide ? 420 : null,
          padding: EdgeInsets.zero,
          duration: Duration(seconds: kind == _ToastKind.error ? 5 : 3),
          content: _ToastCard(color: color, icon: icon, title: title, message: message, palette: p),
        ),
      );
  }
}

class _ToastCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final AppPalette palette;

  const _ToastCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.w700, color: palette.text, fontSize: 14.5),
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(message, style: TextStyle(color: palette.muted, fontSize: 13.5, height: 1.35)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dirisha la kuthibitisha kitendo. Linarudisha `true` mtumiaji akikubali.
Future<bool> confirmAction({
  required String title,
  required String message,
  String? confirmText,
  IconData icon = Icons.help_outline_rounded,
  bool danger = false,
}) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return false;
  final result = await showDialog<bool>(
    context: ctx,
    builder: (context) {
      final p = context.palette;
      final Color color = danger ? p.danger : p.primary;
      return AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: Text('cancel'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText ?? 'yes'.tr),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Inaendesha kazi ya async huku ikionyesha kosa (kama lipo). Inarudisha `true` ikifanikiwa.
Future<bool> runGuarded(Future<void> Function() task, {String? success}) async {
  try {
    await task();
    if (success != null) Toast.success(success);
    return true;
  } catch (e) {
    Toast.error(e);
    return false;
  }
}
