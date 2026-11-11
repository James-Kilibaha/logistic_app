import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';

/// Super admin anaangalia kampuni (kusoma tu): mstari juu ya kila ukurasa + kitufe cha kutoka.
class ViewAsBanner extends StatelessWidget {
  const ViewAsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final app = AppController.to;
      if (!app.isViewOnly) return const SizedBox.shrink();
      final company = BrandingController.to.current.value.displayName;
      final user = app.user.value?.username ?? '';
      return Material(
        color: p.text,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(Icons.visibility_rounded, color: p.surface, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'viewAsBanner'.trParams({'company': company, 'user': user}),
                    style: TextStyle(color: p.surface, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => app.logout(),
                  style: TextButton.styleFrom(foregroundColor: p.surface),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text('viewAsExit'.tr),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
