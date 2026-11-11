import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/invoice.dart';
import '../../data/models/misc.dart';
import '../../data/models/user.dart';
import '../boxes/box_flows.dart';
import '../customers/customer_flows.dart';
import '../invoices/invoice_flows.dart';
import '../invoices/invoices_controller.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';
import '../store/overdue_page.dart';
import 'dashboard_controller.dart';
import 'onboarding_card.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'goodMorning'.tr;
    if (h < 16) return 'goodAfternoon'.tr;
    return 'goodEvening'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final user = AppController.to.user.value;
    return AppPage(
      title: '${_greeting()}, ${user?.firstName ?? ''}'.trim(),
      subtitle: '${'today'.tr} · ${Fmt.date(DateTime.now())}',
      help: 'dashboard',
      actions: [
        if (AppController.to.can(AppModule.customer))
          IconButton(
            tooltip: 'customerDashboard'.tr,
            onPressed: () async {
              final c = await InvoiceFlows.pickCustomer();
              if (c != null) await CustomerFlows.open(c);
            },
            icon: const Icon(Icons.person_search_rounded),
          ),
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: AppController.to.can(AppModule.invoice, AppAction.insert)
          ? PageAction(icon: Icons.add_rounded, label: 'newInvoice'.tr, onPressed: () => InvoiceFlows.newInvoice())
          : null,
      body: Obx(() {
        final status = controller.status.value;
        if (!controller.hasData) {
          if (status == LoadStatus.error) {
            return ErrorState(message: controller.error.value ?? '', onRetry: controller.load);
          }
          return const LoadingList(rows: 5);
        }
        final s = controller.summary.value;
        return PageScroll(
          onRefresh: controller.load,
          spacing: 20,
          children: [
            const OnboardingCard(),
            _Pipeline(summary: s),
            _Kpis(summary: s),
            _Pies(summary: s),
            LayoutBuilder(builder: (context, c) {
              final recent = _RecentInvoices(items: s.recentInvoices, money: s.finance);
              if (!s.finance) return recent;
              final chart = _IncomeChart(days: s.income7Days);
              if (c.maxWidth < 860) {
                return Column(children: [chart, const SizedBox(height: 20), recent]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: chart),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: recent),
                ],
              );
            }),
            const _QuickActions(),
          ],
        );
      }),
    );
  }
}

/// Hatua tano za mzigo na idadi ya invoice kwenye kila hatua.
class _Pipeline extends StatelessWidget {
  final DashboardSummary summary;

  const _Pipeline({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stages = InvoiceStatus.flow;

    void open(InvoiceStatus status) {
      if (Get.isRegistered<InvoicesController>()) Get.find<InvoicesController>().setFilter(status);
      ShellController.to.go(NavSection.invoices);
    }

    return SectionCard(
      title: 'cargoFlow'.tr,
      subtitle: 'cargoFlowSub'.tr,
      icon: Icons.route_rounded,
      child: LayoutBuilder(builder: (context, c) {
        final bool row = c.maxWidth >= 640;
        final tiles = [
          for (int i = 0; i < stages.length; i++)
            _StageTile(
              step: i + 1,
              status: stages[i],
              count: summary.count(stages[i].code),
              onTap: () => open(stages[i]),
            ),
        ];
        if (row) {
          return Row(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) Icon(Icons.chevron_right_rounded, color: p.border, size: 22),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: c.maxWidth >= 420 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: tiles,
        );
      }),
    );
  }
}

class _StageTile extends StatelessWidget {
  final int step;
  final InvoiceStatus status;
  final int count;
  final VoidCallback onTap;

  const _StageTile({required this.step, required this.status, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = StatusStyle.of(status);
    return Material(
      color: s.color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const Spacer(),
                  Text('$step', style: TextStyle(color: s.color.withValues(alpha: .7), fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Fmt.number(count),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.text, height: 1.1),
              ),
              Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  final DashboardSummary summary;

  const _Kpis({required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    final money = summary.finance;
    return ResponsiveGrid(
      minItemWidth: 230,
      children: [
        if (money) ...[
        StatCard(
          label: 'outstandingDebt'.tr,
          value: Fmt.tsh(summary.outstandingDebt),
          icon: Icons.account_balance_outlined,
          color: p.danger,
          hint: 'toCollect'.tr,
          onTap: can(AppModule.handover) ? () => ShellController.to.go(NavSection.delivery) : null,
        ),
        StatCard(
          label: 'paidToday'.tr,
          value: Fmt.tsh(summary.paidToday),
          icon: Icons.payments_outlined,
          color: p.success,
          hint: '${'thisMonth'.tr}: ${Fmt.compact(summary.paidThisMonth)}',
        ),
        StatCard(
          label: 'storageIncomeMonth'.tr,
          value: Fmt.tsh(summary.storageIncomeThisMonth),
          icon: Icons.warehouse_outlined,
          color: const Color(0xFF0F766E),
          hint: '${'storagePendingShort'.tr}: ${Fmt.compact(summary.storagePending)}',
        ),
        ],
        StatCard(
          label: 'overdueInStore'.tr,
          value: Fmt.number(summary.overdueInStore),
          icon: Icons.hourglass_bottom_rounded,
          color: summary.overdueInStore > 0 ? p.danger : p.success,
          hint: 'overdueHint'.tr,
          onTap: can(AppModule.store) ? OverduePage.open : null,
        ),
        if (money)
        StatCard(
          label: 'expensesThisMonth'.tr,
          value: Fmt.tsh(summary.expensesThisMonth),
          icon: Icons.account_balance_wallet_outlined,
          color: p.warning,
          onTap: can(AppModule.expenses) ? () => ShellController.to.go(NavSection.expenses) : null,
        ),
        StatCard(
          label: 'navCustomers'.tr,
          value: Fmt.number(summary.customers),
          icon: Icons.people_alt_outlined,
          color: p.primary,
          onTap: can(AppModule.customer) ? () => ShellController.to.go(NavSection.customers) : null,
        ),
        StatCard(
          label: 'boxesPacking'.tr,
          value: Fmt.number(summary.openBoxes),
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFFD97706),
          onTap: can(AppModule.package) ? () => ShellController.to.go(NavSection.boxes) : null,
        ),
        if (summary.lateBoxes > 0)
          StatCard(
            label: 'lateBoxes'.tr,
            value: Fmt.number(summary.lateBoxes),
            icon: Icons.schedule_rounded,
            color: p.danger,
            hint: 'lateBoxesHint'.tr,
            onTap: can(AppModule.store) ? () => ShellController.to.go(NavSection.store) : null,
          ),
        StatCard(
          label: 'boxesInTransit'.tr,
          value: Fmt.number(summary.boxesInTransit),
          icon: Icons.local_shipping_outlined,
          color: const Color(0xFF0284C7),
          onTap: can(AppModule.store) ? () => ShellController.to.go(NavSection.store) : null,
        ),
        StatCard(
          label: 'pendingSms'.tr,
          value: Fmt.number(summary.pendingSms),
          icon: Icons.sms_outlined,
          color: const Color(0xFF7C3AED),
          onTap: can(AppModule.sms) ? () => ShellController.to.go(NavSection.sms) : null,
        ),
        if (money)
        StatCard(
          label: 'netThisMonth'.tr,
          value: Fmt.tsh(summary.paidThisMonth - summary.expensesThisMonth),
          icon: Icons.trending_up_rounded,
          color: p.info,
          hint: 'netHint'.tr,
        ),
      ],
    );
  }
}

/// Pie charts za mwezi huu: hali za ankara, mapato (usafirishaji / stoo), usafiri, njia za malipo, madeni kwa umri.
class _Pies extends StatelessWidget {
  final DashboardSummary summary;

  const _Pies({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final can = AppController.to.can;
    final statuses = <String, double>{
      for (final st in InvoiceStatus.flow) StatusStyle.of(st).label: s.count(st.code).toDouble(),
      if (s.count('DELIVERED') > 0) 'stDelivered'.tr: s.count('DELIVERED').toDouble(),
    };
    final freight = s.paidThisMonth - s.storageIncomeThisMonth;
    return ResponsiveGrid(
      minItemWidth: 340,
      maxColumns: 3,
      children: [
        PieChartCard(
          title: 'pieInvoiceStatus'.tr,
          subtitle: 'pieInvoiceStatusSub'.tr,
          icon: Icons.donut_large_rounded,
          slices: [
            for (final (i, e) in statuses.entries.indexed) ChartSlice(e.key, e.value, chartPalette[i % chartPalette.length]),
          ],
          format: (v) => Fmt.number(v),
        ),
        if (s.finance)
        PieChartCard(
          title: 'pieIncomeMonth'.tr,
          subtitle: Fmt.tsh(s.paidThisMonth),
          icon: Icons.payments_outlined,
          slices: [
            ChartSlice('incomeFreight'.tr, freight > 0 ? freight : 0, chartPalette[0]),
            ChartSlice('incomeStorage'.tr, s.storageIncomeThisMonth, const Color(0xFF0F766E)),
          ],
        ),
        PieChartCard(
          title: 'pieCarrierKg'.tr,
          subtitle: 'thisMonth'.tr,
          icon: Icons.flight_takeoff_rounded,
          slices: [
            for (final e in s.carrierKg.entries)
              ChartSlice(e.key == 'SEA' ? 'sea'.tr : 'air'.tr, e.value,
                  e.key == 'SEA' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED)),
          ],
          format: (v) => Fmt.kg(v),
        ),
        if (s.finance) ...[
        PieChartCard(
          title: 'piePaymentMethods'.tr,
          subtitle: 'thisMonth'.tr,
          icon: Icons.account_balance_outlined,
          slices: slicesFrom(s.paymentsByMethod),
        ),
        PieChartCard(
          title: 'pieDebtAging'.tr,
          subtitle: Fmt.tsh(s.outstandingDebt),
          icon: Icons.hourglass_bottom_rounded,
          slices: [
            for (final (i, b) in const ['0-7', '8-30', '31-60', '60+'].indexed)
              ChartSlice('daysRange'.trParams({'r': b}), s.debtAging[b] ?? 0,
                  const [Color(0xFF16A34A), Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFFDC2626)][i]),
          ],
          onTap: can(AppModule.report) ? () => ShellController.to.go(NavSection.reports) : null,
        ),
        ],
      ],
    );
  }
}

/// Chati ya mapato ya siku 7 (bila package ya nje).
class _IncomeChart extends StatelessWidget {
  final List<DayAmount> days;

  const _IncomeChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final double max = days.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);
    final double total = days.fold<double>(0, (s, d) => s + d.amount);

    return SectionCard(
      title: 'income7Days'.tr,
      subtitle: '${'total'.tr}: ${Fmt.tsh(total)}',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 210,
        child: days.isEmpty
            ? Center(child: Text('noData'.tr, style: TextStyle(color: p.muted)))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Tooltip(
                        message: '${Fmt.date(d.date)}\n${Fmt.tsh(d.amount)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                d.amount > 0 ? Fmt.compact(d.amount) : '',
                                style: TextStyle(fontSize: 11, color: p.muted, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: max <= 0 ? 0.02 : (d.amount / max).clamp(0.02, 1.0).toDouble(),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [p.primary, p.primary.withValues(alpha: .65)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(Fmt.weekday(d.date), style: TextStyle(fontSize: 12, color: p.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RecentInvoices extends StatelessWidget {
  final List<RecentInvoice> items;
  final bool money;

  const _RecentInvoices({required this.items, this.money = true});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: 'recentInvoices'.tr,
      icon: Icons.receipt_long_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      trailing: TextButton(
        onPressed: () => ShellController.to.go(NavSection.invoices),
        child: Text('seeAll'.tr),
      ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('noInvoicesYet'.tr, style: TextStyle(color: p.muted))),
            )
          : Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(color: p.border, height: 1),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => InvoiceFlows.open(items[i].id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Initials(_initials(items[i].customerName ?? '?'), size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i].customerName ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                                ),
                                Text(
                                  '#${items[i].invoiceNumber} · ${Fmt.relative(items[i].createdAt)}',
                                  style: TextStyle(color: p.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (money) ...[
                                Text(Fmt.money(items[i].total), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                                const SizedBox(height: 3),
                              ],
                              StatusChip(InvoiceStatus.fromCode(items[i].status), dense: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    final actions = <(IconData, String, VoidCallback)>[
      if (can(AppModule.customer, AppAction.insert))
        (Icons.person_add_alt_1_outlined, 'newCustomer'.tr, () => CustomerFlows.edit()),
      if (can(AppModule.invoice, AppAction.insert))
        (Icons.note_add_outlined, 'newInvoice'.tr, () => InvoiceFlows.newInvoice()),
      if (can(AppModule.package, AppAction.insert))
        (Icons.add_box_outlined, 'newBox'.tr, () => BoxFlows.newBox()),
      if (can(AppModule.store))
        (Icons.qr_code_scanner_rounded, 'receiveBox'.tr, () => ShellController.to.go(NavSection.store)),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    final p = context.palette;

    return SectionCard(
      title: 'quickActions'.tr,
      icon: Icons.bolt_rounded,
      child: ResponsiveGrid(
        minItemWidth: 200,
        spacing: 12,
        children: [
          for (final (icon, label, onTap) in actions)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onTap,
              child: Row(
                children: [
                  Icon(icon, color: p.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
