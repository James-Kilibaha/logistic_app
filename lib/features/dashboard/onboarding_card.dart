import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';

/// Hatua za kwanza za kampuni mpya (logo, ofisi, bei, watumiaji, SMS, mteja na ankara ya kwanza ...).
/// Inaonekana kwa wenye ruhusa ya Mipangilio mpaka hatua zote za lazima zikamilike au waifiche.
class OnboardingCard extends StatefulWidget {
  const OnboardingCard({super.key});

  @override
  State<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<OnboardingCard> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    if (AppController.to.can(AppModule.setting, AppAction.select)) _load();
  }

  Future<void> _load() async {
    try {
      final d = await CompanyRepo.onboarding();
      if (mounted) setState(() => _d = d);
    } catch (_) {
      // si muhimu: dashboard inaendelea bila kadi hii
    }
  }

  void _go(String target) {
    switch (target) {
      case 'company':
        Get.toNamed(Routes.company)?.then((_) => _load());
      case 'whatsapp':
        Get.toNamed(Routes.whatsapp)?.then((_) => _load());
      case 'mobilePay':
        Get.toNamed(Routes.onlinePay)?.then((_) => _load());
      case 'users':
        ShellController.to.go(NavSection.users);
      case 'customers':
        ShellController.to.go(NavSection.customers);
      case 'invoices':
        ShellController.to.go(NavSection.invoices);
      default:
        ShellController.to.go(NavSection.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null || J.boolean(d['complete']) || J.boolean(d['hidden'])) return const SizedBox.shrink();
    final p = context.palette;
    final steps = (d['steps'] is List ? d['steps'] as List : const []).whereType<Map>().toList();
    final done = J.integer(d['done']);
    final total = J.integer(d['total'], 1);
    return SectionCard(
      title: 'obTitle'.tr,
      subtitle: 'obSub'.trParams({'done': '$done', 'total': '$total'}),
      icon: Icons.rocket_launch_outlined,
      trailing: TextButton(
        onPressed: () async {
          await CompanyRepo.hideOnboarding();
          if (mounted) setState(() => _d = {...?_d, 'hidden': true});
        },
        child: Text('obHide'.tr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in steps)
                ActionChip(
                  avatar: Icon(
                    J.boolean(s['done']) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: J.boolean(s['done']) ? p.success : (J.boolean(s['optional']) ? p.muted : p.warning),
                  ),
                  label: Text('ob_${J.str(s['key'])}'.tr + (J.boolean(s['optional']) ? ' (${'obOptional'.tr})' : '')),
                  onPressed: J.boolean(s['done']) ? null : () => _go(J.str(s['target'])),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
