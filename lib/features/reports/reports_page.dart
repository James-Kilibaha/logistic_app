import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/lookups.dart';
import '../../data/models/customer.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import 'analytics_tabs.dart';

class _ReportInfo {
  final ReportKind kind;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String descKey;
  final bool needsRange;
  final bool needsStatus;
  final bool needsOffice;
  final bool needsCustomer;
  final bool needsCarrier;

  const _ReportInfo(
    this.kind,
    this.icon,
    this.color,
    this.titleKey,
    this.descKey, {
    this.needsRange = true,
    this.needsStatus = false,
    this.needsOffice = false,
    this.needsCustomer = false,
    this.needsCarrier = false,
  });
}

const List<_ReportInfo> _reports = [
  _ReportInfo(ReportKind.summary, Icons.insights_rounded, Color(0xFF0F766E), 'repSummary', 'repSummaryDesc'),
  _ReportInfo(ReportKind.statement, Icons.person_search_rounded, Color(0xFF1F4FD8), 'repStatement', 'repStatementDesc',
      needsCustomer: true),
  _ReportInfo(ReportKind.customers, Icons.emoji_events_outlined, Color(0xFFDB2777), 'repCustomers', 'repCustomersDesc'),
  _ReportInfo(ReportKind.range, Icons.query_stats_rounded, Color(0xFF1F4FD8), 'repRevenue', 'repRevenueDesc', needsStatus: true),
  _ReportInfo(ReportKind.debt, Icons.account_balance_outlined, Color(0xFFDC2626), 'repDebt', 'repDebtDesc',
      needsRange: false),
  _ReportInfo(ReportKind.product, Icons.inventory_2_outlined, Color(0xFFD97706), 'repCargo', 'repCargoDesc',
      needsCarrier: true),
  _ReportInfo(ReportKind.boxes, Icons.local_shipping_outlined, Color(0xFF0891B2), 'repBoxes', 'repBoxesDesc',
      needsCarrier: true),
  _ReportInfo(ReportKind.handovers, Icons.handshake_outlined, Color(0xFF65A30D), 'repHandovers', 'repHandoversDesc',
      needsCarrier: true),
  _ReportInfo(ReportKind.storage, Icons.warehouse_outlined, Color(0xFFEA580C), 'repStorage', 'repStorageDesc'),
  _ReportInfo(ReportKind.income, Icons.savings_outlined, Color(0xFF15803D), 'repIncome', 'repIncomeDesc'),
  _ReportInfo(ReportKind.expenditure, Icons.account_balance_wallet_outlined, Color(0xFF7C3AED), 'repExpenses',
      'repExpensesDesc', needsOffice: true),
];

const List<String> _statuses = ['PAID', 'DEBT', 'OPEN'];

/// Ripoti ambazo mtumiaji ana ruhusa nazo: boxes (faida) = PROFIT, statement (pesa za mteja) = FINANCE.
List<_ReportInfo> get _allowedReports {
  return [
    for (final r in _reports)
      if (reportAllowed(r.kind.name)) r,
  ];
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  _ReportInfo _selected = _allowedReports.first;
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  String _status = 'PAID';
  Office? _office;
  Customer? _customer;
  String? _carrier;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Lookups.to.loadOffices().catchError((_) => <Office>[]);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _quick(int days) {
    final now = DateTime.now();
    setState(() => _range = DateTimeRange(start: now.subtract(Duration(days: days)), end: now));
  }

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = _selected;
    if (r.needsCustomer && _customer == null) {
      Toast.warning('chooseCustomerFirst'.tr);
      setState(() => _busy = false);
      return;
    }
    try {
      final bytes = await ReportRepo.pdf(
        r.kind,
        from: r.needsRange ? _range.start : null,
        to: r.needsRange ? _range.end : null,
        status: r.needsStatus ? _status : null,
        officeId: r.needsOffice ? _office?.id : null,
        customerId: r.needsCustomer ? _customer?.id : null,
        carrier: r.needsCarrier ? _carrier : null,
      );
      final stamp = r.needsRange ? '${Fmt.date(_range.start)} - ${Fmt.date(_range.end)}' : Fmt.date(DateTime.now());
      await PdfViewerPage.open(
        title: '${r.titleKey.tr} · $stamp',
        bytes: bytes,
        fileName: '${r.kind.name}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = _selected;

    final picker = ResponsiveGrid(
      minItemWidth: 220,
      maxColumns: 5,
      spacing: 12,
      children: [
        for (final info in _allowedReports)
          _ReportTile(info: info, selected: info == _selected, onTap: () => setState(() => _selected = info)),
      ],
    );

    final options = SectionCard(
      title: r.titleKey.tr,
      subtitle: r.descKey.tr,
      icon: r.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.needsRange) ...[
            FieldLabel('period'.tr),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickRange,
              child: InputDecorator(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.date_range_rounded, size: 20)),
                child: Text('${Fmt.date(_range.start)}  –  ${Fmt.date(_range.end)}'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(label: Text('last7'.tr), onPressed: () => _quick(6)),
                ActionChip(label: Text('last30'.tr), onPressed: () => _quick(29)),
                ActionChip(
                  label: Text('thisMonth'.tr),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() => _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now));
                  },
                ),
                ActionChip(
                  label: Text('thisYear'.tr),
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() => _range = DateTimeRange(start: DateTime(now.year, 1, 1), end: now));
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (r.needsStatus) ...[
            FieldLabel('paymentStatus'.tr),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final s in _statuses) ButtonSegment(value: s, label: Text('pay_$s'.tr))],
              selected: {_status},
              onSelectionChanged: (v) => setState(() => _status = v.first),
            ),
            const SizedBox(height: 18),
          ],
          if (r.needsCustomer) ...[
            FieldLabel('customer'.tr),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
              onPressed: () async {
                final c = await InvoiceFlows.pickCustomer();
                if (c != null) setState(() => _customer = c);
              },
              icon: const Icon(Icons.person_search_rounded),
              label: Text(_customer == null ? 'chooseCustomer'.tr : '${_customer!.name} · ${Fmt.phone(_customer!.phoneNumber)}'),
            ),
            const SizedBox(height: 18),
          ],
          if (r.needsCarrier) ...[
            FieldLabel('carrierType'.tr),
            SegmentedButton<String?>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: null, label: Text('allCarriers'.tr)),
                ButtonSegment(value: 'AIR', label: Text('air'.tr), icon: const Icon(Icons.flight_outlined)),
                ButtonSegment(value: 'SEA', label: Text('sea'.tr), icon: const Icon(Icons.directions_boat_outlined)),
              ],
              selected: {_carrier},
              onSelectionChanged: (v) => setState(() => _carrier = v.first),
            ),
            const SizedBox(height: 18),
          ],
          if (r.needsOffice) ...[
            Obx(() => AppDropdown<Office?>(
                  label: 'office'.tr,
                  value: _office,
                  required: false,
                  items: [null, ...Lookups.to.offices],
                  itemLabel: (o) => o?.label ?? 'allOffices'.tr,
                  icon: Icons.store_mall_directory_outlined,
                  onChanged: (v) => setState(() => _office = v),
                )),
            const SizedBox(height: 18),
          ],
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy ? const ButtonSpinner() : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_busy ? 'generating'.tr : 'generateReport'.tr),
            ),
          ),
          const SizedBox(height: 8),
          Text('reportPdfHint'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ],
      ),
    );

    final profit = AppController.to.can(AppModule.profit);
    final money = AppController.to.can(AppModule.finance);
    return DefaultTabController(
      length: 2 + (profit ? 1 : 0) + (money ? 3 : 0),
      child: AppPage(
        title: 'navReports'.tr,
        subtitle: 'hintReports'.tr,
        help: 'reports',
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            if (money) Tab(icon: const Icon(Icons.insights_rounded, size: 20), text: 'tabSummary'.tr),
            Tab(icon: const Icon(Icons.picture_as_pdf_outlined, size: 20), text: 'tabPdfReports'.tr),
            if (money) Tab(icon: const Icon(Icons.payments_outlined, size: 20), text: 'tabIncome'.tr),
            if (profit) Tab(icon: const Icon(Icons.trending_up_rounded, size: 20), text: 'tabProfit'.tr),
            if (money) Tab(icon: const Icon(Icons.hourglass_bottom_rounded, size: 20), text: 'tabAging'.tr),
            Tab(icon: const Icon(Icons.grid_on_rounded, size: 20), text: 'tabExcel'.tr),
          ],
        ),
        body: TabBarView(
          children: [
            if (money) const SummaryTab(),
            PageScroll(children: [picker, options]),
            if (money) const IncomeTab(),
            if (profit) const ProfitTab(),
            if (money) const AgingTab(),
            const ExcelTab(),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final _ReportInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _ReportTile({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: selected ? info.color.withValues(alpha: .08) : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? info.color : p.border, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: info.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(info.icon, color: info.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  info.titleKey.tr,
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: info.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
