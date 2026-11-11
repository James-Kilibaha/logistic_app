import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../data/models/user.dart';

/// Mstari juu ya kurasa: majaribio/subscription inakaribia kuisha, muda wa neema, au mfumo ni wa kusoma tu.
class SubscriptionBanner extends StatefulWidget {
  const SubscriptionBanner({super.key});

  @override
  State<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<SubscriptionBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final st = BrandingController.to.subscription.value;
      if (st == null || !st.needsAttention || (_hidden && !st.readOnly)) return const SizedBox.shrink();

      final days = st.daysLeft ?? 0;
      final (Color color, IconData icon, String text) = st.readOnly
          ? (p.danger, Icons.lock_clock_outlined, 'bannerReadOnly'.tr)
          : st.status == 'GRACE'
              ? (p.warning, Icons.warning_amber_rounded,
                  'bannerGrace'.trParams({'date': Fmt.date(st.graceEndsAt)}))
              : (st.isTrial ? p.info : p.warning, Icons.hourglass_bottom_rounded,
                  (st.isTrial ? 'bannerTrialEnds' : 'bannerSubEnds').trParams({'n': '$days'}));
      final canPay = AppController.to.can(AppModule.setting, AppAction.update);

      return Material(
        color: color.withValues(alpha: .10),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(canPay ? text : '$text ${'subAskAdmin'.tr}',
                      style: TextStyle(color: p.text, fontSize: 13.5, height: 1.3)),
                ),
                if (canPay)
                  TextButton(onPressed: () => Get.toNamed(Routes.subscription), child: Text('subPayNow'.tr)),
                if (!st.readOnly)
                  IconButton(
                    tooltip: 'close'.tr,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _hidden = true),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
