
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/customer.dart';
import '../../data/models/finance.dart';
import '../../data/models/json.dart';
import '../../data/models/ops.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../boxes/box_flows.dart';
import '../customers/customer_flows.dart';
import '../invoices/invoice_flows.dart';

/// Ripoti zenye pesa zinahitaji FINANCE, faida inahitaji PROFIT; za kazi (mizigo, stoo, makabidhiano) REPORT tu.
/// (Sawa na MONEY_KINDS / PROFIT_KINDS za seva.)
const Set<String> moneyReportKinds = {
  'range', 'debt', 'income', 'expenditure', 'summary', 'customers', 'aging', 'statement', 'invoices', 'payments', 'expenses',
};
const Set<String> profitReportKinds = {'boxes', 'profit'};

bool reportAllowed(String kind) {
  final can = AppController.to.can;
  if (profitReportKinds.contains(kind)) return can(AppModule.profit);
  if (moneyReportKinds.contains(kind)) return can(AppModule.finance);
  return true;
}

/// Kuhifadhi faili la Excel (web: linapakuliwa; simu: linahifadhiwa / kushirikiwa).
Future<void> saveExcel(Future<Uint8List> Function() load, String name) async {
  try {
    final bytes = await load();
    final path = await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
    Toast.success(kIsWeb ? '$name.xlsx' : path, title: 'savedTo'.tr);
  } catch (e) {
    Toast.error(e);
  }
}

/// Kipindi (tarehe kuanzia - hadi) chenye vitufe vya haraka.
class PeriodBar extends StatelessWidget {
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  const PeriodBar({super.key, required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InputChip(
          avatar: const Icon(Icons.date_range_rounded, size: 18),
          label: Text('${Fmt.date(range.start)} – ${Fmt.date(range.end)}'),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: now.add(const Duration(days: 1)),
              initialDateRange: range,
            );
            if (picked != null) onChanged(picked);
          },
        ),
        ActionChip(
          label: Text('thisMonth'.tr),
          onPressed: () => onChanged(DateTimeRange(start: DateTime(now.year, now.month, 1), end: now)),
        ),
        ActionChip(
          label: Text('last3Months'.tr),
          onPressed: () => onChanged(DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: now)),
        ),
        ActionChip(
          label: Text('thisYear'.tr),
          onPressed: () => onChanged(DateTimeRange(start: DateTime(now.year, 1, 1), end: now)),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- muhtasari wa biashara

/// Muhtasari wa biashara kwa kipindi: takwimu, chati za mwezi, pie na wateja bora.
class SummaryTab extends StatefulWidget {
  const SummaryTab({super.key});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> with AutomaticKeepAliveClientMixin {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, 1, 1), end: DateTime.now());
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _top = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final results = await Future.wait([
        ReportRepo.summary(from: _range.start, to: _range.end),
        ReportRepo.topCustomers(from: _range.start, to: _range.end),
      ]);
      if (!mounted) return;
      final top = results[1]['items'];
      setState(() {
        _data = results[0];
        _top = top is List ? [for (final x in top.whereType<Map>()) Map<String, dynamic>.from(x)] : const [];
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Map<String, double> _map(dynamic v) =>
      v is Map ? {for (final e in v.entries) e.key.toString(): J.dbl(e.value)} : const {};

  Future<void> _pdf() async {
    try {
      final bytes = await ReportRepo.pdf(ReportKind.summary, from: _range.start, to: _range.end);
      await PdfViewerPage.open(title: 'repSummary'.tr, bytes: bytes, fileName: 'muhtasari_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final d = _data;
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: d == null,
      onRetry: _load,
      empty: EmptyState(icon: Icons.insights_rounded, title: 'noData'.tr),
      builder: () {
        final t = _map(d!['totals']);
        final monthly = [for (final m in (d['monthly'] as List? ?? const []).whereType<Map>()) Map<String, dynamic>.from(m)];
        final carriers = d['byCarrier'] is Map ? Map<String, dynamic>.from(d['byCarrier'] as Map) : <String, dynamic>{};
        return PageScroll(
          onRefresh: _load,
          children: [
            Row(
              children: [
                Expanded(
                  child: PeriodBar(
                    range: _range,
                    onChanged: (r) {
                      setState(() => _range = r);
                      _load();
                    },
                  ),
                ),
                IconButton(tooltip: 'generateReport'.tr, onPressed: _pdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
              ],
            ),
            ResponsiveGrid(
              minItemWidth: 200,
              children: [
                StatCard(label: 'billedTotal'.tr, value: Fmt.tsh(t['billed']), icon: Icons.request_quote_outlined, color: p.primary,
                    hint: '${Fmt.number(t['invoices'])} ${'invoicesShort'.tr}'),
                StatCard(label: 'collected'.tr, value: Fmt.tsh(t['collected']), icon: Icons.payments_outlined, color: p.success,
                    hint: '${'incomeStorage'.tr}: ${Fmt.compact(t['storage'])}'),
                StatCard(label: 'navExpenses'.tr, value: Fmt.tsh(t['expenses']), icon: Icons.account_balance_wallet_outlined,
                    color: p.warning),
                StatCard(label: 'netThisMonth'.tr, value: Fmt.tsh(t['net']), icon: Icons.trending_up_rounded,
                    color: (t['net'] ?? 0) >= 0 ? p.info : p.danger, hint: 'netHint'.tr),
                StatCard(label: 'navCustomers'.tr, value: Fmt.number(t['customers']), icon: Icons.people_alt_outlined,
                    color: const Color(0xFFDB2777)),
                StatCard(label: 'weight'.tr, value: Fmt.kg(t['kg']), icon: Icons.scale_outlined, color: const Color(0xFF7C3AED),
                    hint: '${Fmt.number(t['cartons'])} ${'ctn'.tr}'),
                StatCard(label: 'boxesShipped'.tr, value: Fmt.number(t['boxes']), icon: Icons.local_shipping_outlined,
                    color: const Color(0xFF0891B2),
                    hint: AppController.to.can(AppModule.profit) ? '${'profit'.tr}: ${Fmt.compact(t['boxProfit'])}' : null),
              ],
            ),
            SectionCard(
              title: 'businessByMonth'.tr,
              icon: Icons.bar_chart_rounded,
              child: GroupedBarChart(
                labels: [for (final m in monthly) J.str(m['month'])],
                series: [
                  BarSeries('billedTotal'.tr, [for (final m in monthly) J.dbl(m['billed'])], p.primary),
                  BarSeries('collected'.tr, [for (final m in monthly) J.dbl(m['collected'])], p.success),
                  BarSeries('navExpenses'.tr, [for (final m in monthly) J.dbl(m['expenses'])], p.warning),
                ],
              ),
            ),
            ResponsiveGrid(
              minItemWidth: 340,
              maxColumns: 3,
              children: [
                PieChartCard(
                  title: 'pieCarrierKg'.tr,
                  icon: Icons.flight_takeoff_rounded,
                  slices: [
                    for (final e in carriers.entries)
                      ChartSlice(e.key == 'SEA' ? 'sea'.tr : 'air'.tr, J.dbl((J.map(e.value) ?? const {})['kg']),
                          e.key == 'SEA' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED)),
                  ],
                  format: (v) => Fmt.kg(v),
                ),
                PieChartCard(title: 'piePaymentMethods'.tr, icon: Icons.account_balance_outlined, slices: slicesFrom(_map(d['byInstitute']))),
                PieChartCard(title: 'pieExpensesOffice'.tr, icon: Icons.store_mall_directory_outlined,
                    slices: slicesFrom(_map(d['expensesByOffice']))),
                PieChartCard(
                  title: 'pieTopCustomers'.tr,
                  icon: Icons.emoji_events_outlined,
                  slices: slicesFrom({for (final c in _top) J.str(c['name']): J.dbl(c['billed'])}),
                ),
              ],
            ),
            SectionCard(
              title: 'repCustomers'.tr,
              subtitle: 'topCustomersSub'.tr,
              icon: Icons.emoji_events_outlined,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: _top.isEmpty
                  ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('noData'.tr, style: TextStyle(color: p.muted))))
                  : Column(
                      children: [
                        for (final (i, c) in _top.take(20).indexed)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 15, backgroundColor: p.primarySoft,
                                child: Text('${i + 1}', style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 12))),
                            title: Text(J.str(c['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${Fmt.number(J.dbl(c['invoices']))} ${'invoicesShort'.tr} · ${Fmt.kg(J.dbl(c['kg']))}'
                                ' · ${'balanceDue'.tr}: ${Fmt.compact(J.dbl(c['balance']))}'),
                            trailing: Text(Fmt.tsh(J.dbl(c['billed'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                            onTap: () => CustomerFlows.open(Customer(
                              id: J.str(c['customerId']),
                              name: J.str(c['name']),
                              phoneNumber: J.str(c['phone']),
                            )),
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

// ------------------------------------------------------------------ faida

class ProfitTab extends StatefulWidget {
  const ProfitTab({super.key});

  @override
  State<ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<ProfitTab> with AutomaticKeepAliveClientMixin {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month - 2, 1), end: DateTime.now());
  ProfitReport? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final data = await ShipmentRepo.report(from: _range.start, to: _range.end);
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final data = _data;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PeriodBar(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  _load();
                },
              ),
            ),
            IconButton(
              tooltip: 'downloadExcel'.tr,
              onPressed: () => saveExcel(() => AnalyticsRepo.excel('profit', from: _range.start, to: _range.end),
                  'faida_${DateTime.now().millisecondsSinceEpoch}'),
              icon: const Icon(Icons.grid_on_rounded),
            ),
          ],
        ),
        if (data != null) ...[
          const SizedBox(height: 12),
          ResponsiveGrid(
            minItemWidth: 180,
            children: [
              StatCard(label: 'revenue'.tr, value: Fmt.tsh(data.revenue), icon: Icons.payments_outlined, color: p.primary),
              StatCard(label: 'costs'.tr, value: Fmt.tsh(data.costs), icon: Icons.request_quote_outlined, color: p.warning),
              StatCard(
                label: 'profit'.tr,
                value: Fmt.tsh(data.profit),
                icon: Icons.trending_up_rounded,
                color: data.profit >= 0 ? p.success : p.danger,
                hint: '${data.margin.toStringAsFixed(1)}%',
              ),
              StatCard(label: 'boxesShipped'.tr, value: '${data.rows.length}', icon: Icons.inventory_2_outlined, color: p.info),
            ],
          ),
          if (data.rows.any((r) => r.costs == 0))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('boxesWithoutCosts'.trParams({'n': '${data.rows.where((r) => r.costs == 0).length}'}),
                  style: TextStyle(color: p.warning, fontWeight: FontWeight.w600)),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: data == null,
      onRetry: _load,
      empty: EmptyState(icon: Icons.trending_up_rounded, title: 'noData'.tr),
      builder: () => DataList<BoxProfit>(
        items: data!.rows,
        onRefresh: _load,
        header: header,
        onTap: (r) async {
          try {
            final boxes = await BoxRepo.all();
            for (final box in boxes) {
              if (box.id == r.packageId) {
                await BoxFlows.open(box);
                break;
              }
            }
          } catch (e) {
            Toast.error(e);
          }
        },
        columns: [
          ColumnSpec('box'.tr, flex: 3),
          ColumnSpec('weight'.tr, flex: 2, align: TextAlign.end),
          ColumnSpec('revenue'.tr, flex: 3, align: TextAlign.end),
          ColumnSpec('costs'.tr, flex: 3, align: TextAlign.end),
          ColumnSpec('profit'.tr, flex: 3, align: TextAlign.end),
        ],
        cells: (context, r) => [
          CellText(r.boxId, sub: '${r.isSea ? 'sea'.tr : 'air'.tr} · ${Fmt.date(r.closedAt)}', bold: true),
          CellText(Fmt.kg(r.kg), align: TextAlign.end, sub: r.cbm > 0 ? '${r.cbm.toStringAsFixed(2)} CBM' : null),
          CellText(Fmt.money(r.income), align: TextAlign.end, sub: '${r.items} ${'items'.tr}'),
          CellText(Fmt.money(r.costs), align: TextAlign.end, color: r.costs == 0 ? p.warning : null,
              sub: r.costs == 0 ? 'noCostsYet'.tr : '${Fmt.money(r.costPerKg)}/kg'),
          CellText(Fmt.money(r.profit), align: TextAlign.end, bold: true, color: r.profit >= 0 ? p.success : p.danger,
              sub: '${r.margin.toStringAsFixed(1)}%'),
        ],
        card: (context, r) => ListTile(
          title: Text('Box ${r.boxId}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${Fmt.date(r.closedAt)} · ${Fmt.kg(r.kg)} · ${'costs'.tr} ${Fmt.money(r.costs)}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(r.profit), style: TextStyle(fontWeight: FontWeight.w800, color: r.profit >= 0 ? p.success : p.danger)),
              Text('${r.margin.toStringAsFixed(1)}%', style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- mapato (usafirishaji + stoo)

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> with AutomaticKeepAliveClientMixin {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  IncomeBreakdown? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final data = await AnalyticsRepo.income(from: _range.start, to: _range.end);
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final data = _data;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PeriodBar(
                range: _range,
                onChanged: (r) {
                  setState(() => _range = r);
                  _load();
                },
              ),
            ),
            IconButton(
              tooltip: 'downloadExcel'.tr,
              onPressed: () => saveExcel(() => AnalyticsRepo.excel('storage', from: _range.start, to: _range.end),
                  'mapato_stoo_${DateTime.now().millisecondsSinceEpoch}'),
              icon: const Icon(Icons.grid_on_rounded),
            ),
          ],
        ),
        if (data != null) ...[
          const SizedBox(height: 12),
          ResponsiveGrid(
            minItemWidth: 180,
            children: [
              StatCard(label: 'incomeTotal'.tr, value: Fmt.tsh(data.total), icon: Icons.payments_outlined, color: p.primary),
              StatCard(
                label: 'incomeFreight'.tr,
                value: Fmt.tsh(data.freight),
                icon: Icons.local_shipping_outlined,
                color: p.info,
              ),
              StatCard(
                label: 'incomeStorage'.tr,
                value: Fmt.tsh(data.storage),
                icon: Icons.warehouse_outlined,
                color: const Color(0xFF0F766E),
                hint: data.total > 0 ? '${(data.storage / data.total * 100).toStringAsFixed(1)}%' : null,
              ),
              StatCard(
                label: 'storagePending'.tr,
                value: Fmt.tsh(data.pendingInStore),
                icon: Icons.hourglass_bottom_rounded,
                color: p.warning,
                hint: 'storagePendingHint'.tr,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('storageIncomeRows'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
        ],
        const SizedBox(height: 4),
      ],
    );
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: data == null,
      onRetry: _load,
      empty: EmptyState(icon: Icons.payments_outlined, title: 'noData'.tr),
      builder: () => DataList<StorageIncomeRow>(
        items: data!.items,
        onRefresh: _load,
        header: header,
        onTap: (r) => InvoiceFlows.open(r.invoiceId),
        columns: [
          ColumnSpec('invoice'.tr, flex: 2),
          ColumnSpec('customer'.tr, flex: 3),
          ColumnSpec('daysInStore'.tr, flex: 2, align: TextAlign.end),
          ColumnSpec('storageCharge'.tr, flex: 3, align: TextAlign.end),
          ColumnSpec('paidStorage'.tr, flex: 3, align: TextAlign.end),
        ],
        cells: (context, r) => [
          CellText(r.invoiceNumber, bold: true, sub: Fmt.date(r.paidAt)),
          CellText(r.customerName),
          CellText('${r.days}', align: TextAlign.end),
          CellText(Fmt.money(r.storageCharge), align: TextAlign.end),
          CellText(Fmt.money(r.collected), align: TextAlign.end, bold: true, color: p.success),
        ],
        card: (context, r) => ListTile(
          title: Text('${r.customerName} · ${r.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${'daysN'.trParams({'n': '${r.days}'})} · ${Fmt.date(r.paidAt)}'),
          trailing: Text(Fmt.money(r.collected), style: TextStyle(fontWeight: FontWeight.w800, color: p.success)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- madeni kwa umri

class AgingTab extends StatefulWidget {
  const AgingTab({super.key});

  @override
  State<AgingTab> createState() => _AgingTabState();
}

class _AgingTabState extends State<AgingTab> with AutomaticKeepAliveClientMixin {
  AgingReport? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _reminding = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AnalyticsRepo.aging();
      if (!mounted) return;
      setState(() {
        _data = data;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _remind() async {
    final ok = await confirmAction(
      title: 'sendRemindersNow'.tr,
      message: 'sendRemindersNowMsg'.tr,
      confirmText: 'send'.tr,
      icon: Icons.notifications_active_outlined,
    );
    if (!ok) return;
    setState(() => _reminding = true);
    try {
      final r = await AnalyticsRepo.runReminders();
      Toast.success('remindersSent'.trParams({'debts': '${r['debtReminders'] ?? 0}', 'store': '${r['storageWarnings'] ?? 0}'}));
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _reminding = false);
  }

  Color _bucketColor(AppPalette p, String b) => switch (b) {
        '0-7' => p.success,
        '8-30' => p.warning,
        '31-60' => const Color(0xFFEA580C),
        _ => p.danger,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final data = _data;
    return AsyncBody(
      status: _status,
      error: _error,
      isEmpty: data == null,
      onRetry: _load,
      empty: EmptyState(icon: Icons.check_circle_outline_rounded, title: 'noDebts'.tr),
      builder: () {
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (AppController.to.can(AppModule.broadcast, AppAction.insert))
                OutlinedButton.icon(
                  onPressed: _reminding ? null : _remind,
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: Text('sendRemindersNow'.tr),
                ),
                OutlinedButton.icon(
                  onPressed: () => saveExcel(() => AnalyticsRepo.excel('aging'), 'madeni_${DateTime.now().millisecondsSinceEpoch}'),
                  icon: const Icon(Icons.grid_on_rounded, size: 18),
                  label: Text('downloadExcel'.tr),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ResponsiveGrid(
              minItemWidth: 150,
              children: [
                for (final b in data!.buckets)
                  StatCard(
                    label: 'agingDays'.trParams({'b': b}),
                    value: Fmt.compact(data.totals[b] ?? 0),
                    icon: Icons.hourglass_bottom_rounded,
                    color: _bucketColor(p, b),
                    hint: Fmt.tsh(data.totals[b] ?? 0),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${'totalOwed'.tr}: ${Fmt.tsh(data.total)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: p.danger, fontSize: 16)),
            const SizedBox(height: 4),
          ],
        );
        return DataList<AgingCustomer>(
          items: data.customers,
          onRefresh: _load,
          header: header,
          columns: [
            ColumnSpec('customer'.tr, flex: 4),
            for (final b in data.buckets) ColumnSpec(b, flex: 2, align: TextAlign.end),
            ColumnSpec('total'.tr, flex: 3, align: TextAlign.end),
          ],
          cells: (context, c) => [
            CellText(c.name, sub: '${Fmt.phone(c.phone)} · ${c.invoices} ${'invoicesLower'.tr}', bold: true),
            for (final b in data.buckets)
              CellText(c.buckets[b] == 0 ? '—' : Fmt.money(c.buckets[b]), align: TextAlign.end,
                  color: c.buckets[b] == 0 ? p.muted : _bucketColor(p, b)),
            CellText(Fmt.money(c.total), align: TextAlign.end, bold: true, sub: 'daysOld'.trParams({'n': '${c.oldestDays}'})),
          ],
          card: (context, c) => ListTile(
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${Fmt.phone(c.phone)} · ${'daysOld'.trParams({'n': '${c.oldestDays}'})}'),
            trailing: Text(Fmt.money(c.total), style: TextStyle(fontWeight: FontWeight.w800, color: p.danger)),
            onTap: () => callPhone(c.phone),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- Excel

class ExcelTab extends StatefulWidget {
  const ExcelTab({super.key});

  @override
  State<ExcelTab> createState() => _ExcelTabState();
}

class _ExcelTabState extends State<ExcelTab> {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  String? _busy;

  static const _kinds = <(String, IconData, bool)>[
    ('invoices', Icons.receipt_long_outlined, true),
    ('payments', Icons.payments_outlined, true),
    ('expenses', Icons.account_balance_wallet_outlined, true),
    ('profit', Icons.trending_up_rounded, true),
    ('storage', Icons.warehouse_outlined, true),
    ('aging', Icons.hourglass_bottom_rounded, false),
    ('customers', Icons.people_alt_outlined, false),
  ];

  Future<void> _download(String kind, bool ranged) async {
    setState(() => _busy = kind);
    await saveExcel(
      () => AnalyticsRepo.excel(kind, from: ranged ? _range.start : null, to: ranged ? _range.end : null),
      '${kind}_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      children: [
        SectionCard(
          title: 'excelExports'.tr,
          subtitle: 'excelExportsSub'.tr,
          icon: Icons.grid_on_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PeriodBar(range: _range, onChanged: (r) => setState(() => _range = r)),
              const SizedBox(height: 12),
              for (final (kind, icon, ranged) in _kinds)
                if (reportAllowed(kind))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: p.primarySoft, child: Icon(icon, color: p.primary)),
                  title: Text('xl_$kind'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(ranged ? 'xlForPeriod'.tr : 'xlAllCurrent'.tr),
                  trailing: _busy == kind
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          tooltip: 'downloadExcel'.tr,
                          onPressed: _busy == null ? () => _download(kind, ranged) : null,
                          icon: const Icon(Icons.download_rounded),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
