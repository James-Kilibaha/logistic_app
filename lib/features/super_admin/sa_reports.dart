import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Biashara yako: mapato kwa mwezi, kampuni mpya na zilizoondoka, zinazolipa, na zilizo hatarini kuondoka.
class SaReports extends StatefulWidget {
  final ValueChanged<String> onOpenCompany;

  const SaReports({super.key, required this.onOpenCompany});

  @override
  State<SaReports> createState() => _SaReportsState();
}

class _SaReportsState extends State<SaReports> {
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    return SaLoader<Map<String, dynamic>>(
      key: ValueKey(_months),
      load: () async => Map<String, dynamic>.from(
          (await PlatformApi.get('reports/revenue', query: {'months': '$_months'})) as Map),
      builder: (context, d, reload) {
        final p = context.palette;
        final months = (d['months'] is List ? d['months'] as List : const []).whereType<Map>().toList();
        final totals = J.map(d['totals']) ?? const {};
        final top = (d['top'] is List ? d['top'] as List : const []).whereType<Map>().toList();
        final risk = (d['atRisk'] is List ? d['atRisk'] as List : const []).whereType<Map>().toList();
        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(
              title: 'saReports'.tr,
              subtitle: 'saReportsSub'.tr,
              actions: [
                SegmentedButton<int>(
                  segments: [
                    for (final m in const [6, 12, 24]) ButtonSegment(value: m, label: Text('saMonthsN'.trParams({'n': '$m'}))),
                  ],
                  selected: {_months},
                  onSelectionChanged: (v) => setState(() => _months = v.first),
                ),
              ],
            ),
            ResponsiveGrid(
              minItemWidth: 200,
              children: [
                StatCard(label: 'saRevenuePeriod'.tr, value: money('TZS', J.dbl(totals['revenueTzs'])),
                    icon: Icons.account_balance_wallet_outlined, color: p.success),
                StatCard(label: 'saPayingNow'.tr, value: '${J.integer(totals['payingNow'])}',
                    icon: Icons.verified_rounded, color: p.primary),
                StatCard(label: 'saNewCompanies'.tr, value: '${J.integer(totals['newCompanies'])}',
                    icon: Icons.add_business_outlined, color: p.info),
                StatCard(label: 'saChurned'.tr, value: '${J.integer(totals['churned'])}',
                    hint: 'saChurnRate'.trParams({'n': '${J.dbl(totals['churnRate'])}'}),
                    icon: Icons.trending_down_rounded, color: p.danger),
              ],
            ),
            SectionCard(
              title: 'saRevenueByMonth'.tr,
              icon: Icons.bar_chart_rounded,
              child: _Bars(months: months),
            ),
            SectionCard(
              title: 'saMonthTable'.tr,
              icon: Icons.table_rows_outlined,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  columns: [
                    DataColumn(label: Text('saMonth'.tr)),
                    DataColumn(label: Text('saRevenueTzs'.tr), numeric: true),
                    DataColumn(label: Text('saPaymentsN'.tr), numeric: true),
                    DataColumn(label: Text('saPayingNow'.tr), numeric: true),
                    DataColumn(label: Text('saNewCompanies'.tr), numeric: true),
                    DataColumn(label: Text('saChurned'.tr), numeric: true),
                  ],
                  rows: [
                    for (final m in months.reversed)
                      DataRow(cells: [
                        DataCell(Text(J.str(m['month']))),
                        DataCell(Text(Fmt.number(J.dbl(m['revenueTzs'])))),
                        DataCell(Text('${J.integer(m['payments'])}')),
                        DataCell(Text('${J.integer(m['paying'])}')),
                        DataCell(Text('${J.integer(m['newCompanies'])}')),
                        DataCell(Text('${J.integer(m['churned'])}',
                            style: TextStyle(color: J.integer(m['churned']) > 0 ? p.danger : null))),
                      ]),
                  ],
                ),
              ),
            ),
            SectionCard(
              title: 'saAtRisk'.tr,
              subtitle: 'saAtRiskSub'.tr,
              icon: Icons.warning_amber_rounded,
              trailing: Pill('${risk.length}', color: risk.isEmpty ? p.success : p.warning, dense: true),
              child: risk.isEmpty
                  ? Text('saAtRiskNone'.tr, style: TextStyle(color: p.muted))
                  : Column(
                      children: [
                        for (final r in risk)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.apartment_rounded, color: p.warning),
                            title: Text('${J.str(r['name'])} (${J.str(r['slug'])})'),
                            subtitle: Text([
                              J.str(r['status']),
                              if (r['daysLeft'] != null) 'saDaysN'.trParams({'n': '${J.integer(r['daysLeft'])}'}),
                              r['lastInvoiceAt'] == null
                                  ? 'saNoInvoicesYet'.tr
                                  : '${'saLastInvoice'.tr}: ${Fmt.date(J.date(r['lastInvoiceAt']))}',
                              if (J.strOrNull(r['phone']) != null) Fmt.phone(J.str(r['phone'])),
                            ].join(' · ')),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                for (final reason in (r['reasons'] as List? ?? const []))
                                  Pill('saRisk_$reason'.tr, color: p.warning, dense: true),
                              ],
                            ),
                            onTap: () => widget.onOpenCompany(J.str(r['companyId'])),
                          ),
                      ],
                    ),
            ),
            if (top.isNotEmpty)
              SectionCard(
                title: 'saTopCompanies'.tr,
                icon: Icons.emoji_events_outlined,
                child: Column(
                  children: [
                    for (final (i, t) in top.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                        title: Text('${J.str(t['name'])} (${J.str(t['slug'])})'),
                        trailing: Text(money('TZS', J.dbl(t['revenueTzs'])),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => widget.onOpenCompany(J.str(t['companyId'])),
                      ),
                  ],
                ),
              ),
            if (months.isEmpty) EmptyState(icon: Icons.bar_chart_rounded, title: 'saNoData'.tr),
          ],
        );
      },
    );
  }
}

/// Mihimili rahisi ya mapato (TZS) kwa kila mwezi - bila maktaba ya chati.
class _Bars extends StatelessWidget {
  final List<Map> months;

  const _Bars({required this.months});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = months.fold<double>(0, (a, m) => math.max(a, J.dbl(m['revenueTzs'])));
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Tooltip(
                message: '${J.str(m['month'])}: ${money('TZS', J.dbl(m['revenueTzs']))}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: maxValue <= 0 ? 0.02 : math.max(J.dbl(m['revenueTzs']) / maxValue, 0.02),
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.primary,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(J.str(m['month']).substring(math.max(J.str(m['month']).length - 2, 0)),
                          style: TextStyle(color: p.muted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
