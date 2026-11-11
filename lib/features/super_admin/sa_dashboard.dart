import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';
import 'sa_security.dart';

/// Takwimu za mfumo mzima: kampuni, subscription, mapato, zinazokaribia kuisha.
class SaDashboard extends StatelessWidget {
  final ValueChanged<String> onOpenCompany;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenPending;
  final VoidCallback? onOpenSupport;

  const SaDashboard(
      {super.key, required this.onOpenCompany, required this.onOpenPayments, required this.onOpenPending,
      this.onOpenSupport});

  @override
  Widget build(BuildContext context) {
    return SaLoader<Map<String, dynamic>>(
      load: () async => Map<String, dynamic>.from((await PlatformApi.get('dashboard')) as Map),
      builder: (context, d, reload) {
        final p = context.palette;
        final c = J.map(d['companies']) ?? const {};
        int n(String k) => J.integer(c[k]);
        final revenue = (d['revenueThisMonth'] is List ? d['revenueThisMonth'] as List : const [])
            .whereType<Map>()
            .map((r) => money(J.str(r['currency'], 'TZS'), J.dbl(r['amount'])))
            .join(' + ');
        final expiring = (d['expiring'] is List ? d['expiring'] as List : const []).whereType<Map>().toList();
        final pending = J.integer(d['pendingPayments']);
        // salio la akaunti yako ya FastHub (kampuni zinazoitumia hazilioni)
        final sms = J.map(d['platformSmsBalance']) ?? const {};
        final double? smsBalance = sms['balance'] == null ? null : J.dbl(sms['balance']);
        final awaiting = (d['awaitingApproval'] is List ? d['awaitingApproval'] as List : const [])
            .whereType<Map>()
            .toList();

        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(title: 'navDashboard'.tr, subtitle: 'saDashboardSub'.tr),
            if (Session.platformAdmin?['totpEnabled'] != true)
              SectionCard(
                title: 'sa2faNudge'.tr,
                subtitle: 'sa2faNudgeSub'.tr,
                icon: Icons.gpp_maybe_outlined,
                trailing: FilledButton.icon(
                  onPressed: () => SaSecurityPage.open().then((_) => reload()),
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text('sa2faEnable'.tr),
                ),
                child: const SizedBox.shrink(),
              ),
            ResponsiveGrid(
              minItemWidth: 220,
              children: [
                StatCard(label: 'saCompaniesTotal'.tr, value: '${n('total')}', icon: Icons.apartment_rounded,
                    color: p.primary, hint: 'saNew30d'.trParams({'n': '${J.integer(d['newCompanies30d'])}'})),
                StatCard(label: 'saPaying'.tr, value: '${n('paying')}', icon: Icons.verified_rounded, color: p.success),
                StatCard(label: 'subTrial'.tr, value: '${n('trial')}', icon: Icons.hourglass_top_rounded, color: p.info),
                StatCard(label: 'saGraceExpired'.tr, value: '${n('grace')} / ${n('expired') + n('none')}',
                    icon: Icons.lock_clock_outlined, color: p.warning),
                StatCard(label: 'saAwaitingApproval'.tr, value: '${n('pending')}', icon: Icons.how_to_reg_outlined,
                    color: n('pending') > 0 ? p.warning : p.muted, onTap: onOpenPending),
                StatCard(label: 'saSuspended'.tr, value: '${n('suspended')}', icon: Icons.block_rounded, color: p.danger),
                StatCard(label: 'saPendingPayments'.tr, value: '$pending', icon: Icons.pending_actions_rounded,
                    color: pending > 0 ? p.warning : p.muted, onTap: onOpenPayments),
                StatCard(label: 'saMrr'.tr, value: money('TZS', J.dbl(d['mrrTzs'])), icon: Icons.trending_up_rounded,
                    color: p.success, hint: 'saMrrHint'.tr),
                StatCard(label: 'saRevenueMonth'.tr, value: revenue.isEmpty ? 'TZS 0' : revenue,
                    icon: Icons.account_balance_wallet_outlined, color: p.primary),
                StatCard(
                  label: 'tkOpenTickets'.tr,
                  value: '${J.integer(J.map(d['tickets'])?['open'])}',
                  hint: J.integer(J.map(d['tickets'])?['unread']) > 0
                      ? 'tkUnreadN'.trParams({'n': '${J.integer(J.map(d['tickets'])?['unread'])}'})
                      : null,
                  icon: Icons.support_agent_rounded,
                  color: J.integer(J.map(d['tickets'])?['unread']) > 0 ? p.warning : p.muted,
                  onTap: onOpenSupport,
                ),
                if (smsBalance != null)
                  StatCard(
                    label: 'saSmsBalance'.tr,
                    value: Fmt.number(smsBalance),
                    icon: Icons.sms_outlined,
                    color: smsBalance < J.dbl(sms['lowAt']) ? p.danger : p.info,
                    hint: 'saSmsBalanceHint'.trParams({'t': Fmt.dateTime(J.date(sms['seenAt']))}),
                  ),
              ],
            ),
            if (awaiting.isNotEmpty)
              SectionCard(
                title: 'saAwaitingApproval'.tr,
                subtitle: 'saAwaitingApprovalSub'.tr,
                icon: Icons.how_to_reg_outlined,
                trailing: Pill('${awaiting.length}', color: p.warning, dense: true),
                child: Column(
                  children: [
                    for (final a in awaiting)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.hourglass_top_rounded, color: p.warning),
                        title: Text('${J.str(a['name'])} (${J.str(a['slug'])})'),
                        subtitle: Text([
                          if (J.strOrNull(a['ownerName']) != null) J.str(a['ownerName']),
                          if (J.strOrNull(a['phone']) != null) J.str(a['phone']),
                          Fmt.dateTime(J.date(a['created_at'])),
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => onOpenCompany(J.str(a['id'])),
                      ),
                  ],
                ),
              ),
            SectionCard(
              title: 'saExpiring'.tr,
              subtitle: 'saExpiringSub'.tr,
              icon: Icons.event_busy_outlined,
              trailing: TextButton.icon(
                onPressed: () => _remindNow(),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text('saRemindNow'.tr),
              ),
              child: expiring.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('saNoExpiring'.tr, style: TextStyle(color: p.muted)),
                    )
                  : Column(
                      children: [
                        for (final e in expiring)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.apartment_rounded, color: p.muted),
                            title: Text('${J.str(e['name'])} (${J.str(e['slug'])})'),
                            subtitle: Text('${J.str(e['status'])} · ${Fmt.date(J.date(e['endsAt']))}'),
                            trailing: Text('saDaysN'.trParams({'n': '${J.integer(e['daysLeft'])}'}),
                                style: TextStyle(color: p.warning, fontWeight: FontWeight.w700)),
                            onTap: () => onOpenCompany(J.str(e['id'])),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Vikumbusho vya subscription sasa hivi (kawaida vinatumwa vyenyewe kila siku saa 3:20 asubuhi).
/// Kila kampuni inapata kikumbusho kimoja tu kwa kila hatua - kubonyeza tena hakurudii.
Future<void> _remindNow() async {
  final ok = await confirmAction(
    title: 'saRemindNow'.tr,
    message: 'saRemindNowMsg'.tr,
    icon: Icons.notifications_active_outlined,
  );
  if (!ok) return;
  try {
    final body = await PlatformApi.post('subscriptions/remind-now');
    final m = body is Map ? body : const {};
    final companies = (m['companies'] is List ? m['companies'] as List : const []).whereType<Map>().toList();
    if (companies.isEmpty) {
      Toast.info('saRemindNone'.tr);
    } else {
      Toast.success(
        companies.map((c) => '${J.str(c['name'])}: ${J.str(c['message'])}').join('\n'),
        title: 'saRemindSent'.trParams({
          'n': '${companies.length}',
          'sms': '${J.integer(m['sms'])}',
          'email': '${J.integer(m['email'])}',
        }),
      );
    }
  } catch (e) {
    Toast.error(e);
  }
}
