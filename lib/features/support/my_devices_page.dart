import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../../data/repositories.dart';

/// Vifaa (simu, kompyuta, browser) ulivyoingia navyo - na kutoka kwenye vingine vyote ukibaki hapa.
class MyDevicesPage extends StatefulWidget {
  const MyDevicesPage({super.key});

  static Future<void> open() async {
    await Get.to(() => const MyDevicesPage());
  }

  @override
  State<MyDevicesPage> createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends State<MyDevicesPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await SupportRepo.mySessions();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _logoutOthers() async {
    final ok = await confirmAction(
      title: 'devLogoutOthers'.tr,
      message: 'devLogoutOthersMsg'.tr,
      icon: Icons.devices_other_rounded,
      danger: true,
    );
    if (!ok) return;
    await runGuarded(() async {
      final res = await SupportRepo.logoutOthers();
      await Session.saveTokens(J.str(res['access_token']), J.str(res['refresh_token']));
    }, success: 'devLoggedOutOthers'.tr);
  }

  IconData _icon(Map<String, dynamic> s) {
    final d = '${J.str(s['client'])} ${J.str(s['device'])}'.toLowerCase();
    if (d.contains('android') || d.contains('iphone') || d.contains('ios')) return Icons.phone_android_rounded;
    if (d.contains('web') || d.contains('chrome') || d.contains('firefox') || d.contains('safari') || d.contains('edge')) {
      return Icons.language_rounded;
    }
    return Icons.computer_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = _items;
    return AppPage(
      title: 'devTitle'.tr,
      subtitle: 'devSub'.tr,
      showBack: true,
      body: items == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const LoadingList(rows: 4))
          : PageScroll(
              onRefresh: _load,
              children: [
                SectionCard(
                  title: 'devRecent'.tr,
                  icon: Icons.devices_rounded,
                  child: items.isEmpty
                      ? Text('devNone'.tr, style: TextStyle(color: p.muted))
                      : Column(
                          children: [
                            for (final (i, s) in items.indexed)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_icon(s), color: i == 0 ? p.success : p.muted),
                                title: Text(J.strOrNull(s['device']) ?? J.str(s['client'], '-')),
                                subtitle: Text([
                                  if (J.strOrNull(s['client']) != null) J.str(s['client']),
                                  if (J.strOrNull(s['ip']) != null) 'IP ${J.str(s['ip'])}',
                                  Fmt.dateTime(J.date(s['at'])),
                                ].join(' · ')),
                                trailing: i == 0 ? Pill('devLatest'.tr, color: p.success, dense: true) : null,
                              ),
                          ],
                        ),
                ),
                SectionCard(
                  title: 'devLogoutOthers'.tr,
                  subtitle: 'devLogoutOthersSub'.tr,
                  icon: Icons.gpp_maybe_outlined,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: p.danger),
                      onPressed: _logoutOthers,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text('devLogoutOthers'.tr),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
