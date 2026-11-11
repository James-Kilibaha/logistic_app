import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/finance.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../reports/analytics_tabs.dart';
import 'box_costs.dart';
import 'cost_payment.dart';

/// Gharama za mabox: zote (mhasibu / mwenye Faida) au [mine] = nilizojaza mimi.
class BoxCostsView extends StatefulWidget {
  final bool mine;

  const BoxCostsView({super.key, this.mine = false});

  @override
  State<BoxCostsView> createState() => _BoxCostsViewState();
}

class _BoxCostsViewState extends State<BoxCostsView> with AutomaticKeepAliveClientMixin {
  DateTimeRange _range = DateTimeRange(start: DateTime(DateTime.now().year, DateTime.now().month, 1), end: DateTime.now());
  String? _pay; // PAID | PARTIAL | CREDIT
  String? _category;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  List<BoxCost> _items = const [];
  double _total = 0, _paid = 0, _owed = 0;
  int _boxes = 0;
  Worker? _changes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _changes = ever<int>(AppController.to.changes, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _status = LoadStatus.loading);
    try {
      final r = await ShipmentRepo.allCosts(
        from: _range.start,
        to: _range.end,
        payStatus: _pay,
        category: _category,
        mine: widget.mine,
      );
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _total = r.total;
        _paid = r.paid;
        _owed = r.owed;
        _boxes = r.boxes;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = LoadStatus.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    final can = AppController.to.can;
    final canPay = can(AppModule.accounting, AppAction.insert) || can(AppModule.profit, AppAction.update);
    return PageScroll(
      onRefresh: _load,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PeriodBar(
              range: _range,
              onChanged: (r) {
                _range = r;
                _load();
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'costType'.tr,
              onSelected: (c) {
                _category = c.isEmpty ? null : c;
                _load();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: '', child: Text('all'.tr)),
                for (final c in costCategories) PopupMenuItem(value: c, child: Text(costLabel(c))),
              ],
              child: Chip(
                avatar: const Icon(Icons.category_outlined, size: 18),
                label: Text(_category == null ? 'costType'.tr : costLabel(_category!)),
              ),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in const [null, 'PAID', 'PARTIAL', 'CREDIT']) ...[
                ChoiceChip(
                  label: Text(s == null ? 'all'.tr : payStatusLabel(s)),
                  selected: _pay == s,
                  onSelected: (_) {
                    _pay = s;
                    _load();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        ResponsiveGrid(
          minItemWidth: 180,
          children: [
            StatCard(
              label: 'boxCostsTotal'.tr,
              value: Fmt.tsh(_total),
              icon: Icons.request_quote_outlined,
              color: p.primary,
              hint: '$_boxes ${'navBoxes'.tr.toLowerCase()}',
            ),
            StatCard(label: 'payPaid'.tr, value: Fmt.tsh(_paid), icon: Icons.check_circle_outline_rounded, color: p.success),
            StatCard(label: 'payOwed'.tr, value: Fmt.tsh(_owed), icon: Icons.local_shipping_outlined, color: p.danger),
          ],
        ),
        AsyncBody(
          status: _status,
          error: _error,
          isEmpty: _items.isEmpty,
          onRetry: _load,
          empty: EmptyState(icon: Icons.request_quote_outlined, title: 'noBoxCosts'.tr),
          builder: () => Card(
            child: Column(
              children: [
                for (final c in _items) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: payStatusColor(context, c.payStatus).withValues(alpha: .12),
                      child: Icon(Icons.inventory_2_outlined, color: payStatusColor(context, c.payStatus), size: 20),
                    ),
                    title: Text('Box ${c.boxId ?? '-'} · ${costLabel(c.category)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (c.currency != 'TZS') '${c.currency} ${Fmt.money2(c.amount)}',
                      payStatusLabel(c.payStatus),
                      if (c.supplier != null) c.supplier!,
                      if (c.hasDebt) '${'payOwed'.tr} ${Fmt.money(c.owedTzs)}',
                      if (!widget.mine && c.createdBy != null) c.createdBy!,
                      Fmt.dateTime(c.createdAt),
                      if (c.note != null) c.note!,
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Fmt.tsh(c.amountTzs), style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (c.hasDebt && canPay)
                          IconButton(
                            tooltip: 'payDebt'.tr,
                            onPressed: () async {
                              if (await showPayCost(c)) _load();
                            },
                            icon: Icon(Icons.payments_outlined, color: p.success),
                          ),
                      ],
                    ),
                  ),
                  if (c != _items.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ukurasa wa "Gharama nilizojaza" (kila mtumiaji) au gharama zote.
class BoxCostsPage extends StatelessWidget {
  final bool mine;

  const BoxCostsPage({super.key, this.mine = true});

  static Future<void> open({bool mine = true}) async => Get.to(() => BoxCostsPage(mine: mine));

  @override
  Widget build(BuildContext context) {
    return AppPage(
      showBack: true,
      title: mine ? 'myBoxCosts'.tr : 'allBoxCosts'.tr,
      subtitle: mine ? 'myBoxCostsHint'.tr : 'allBoxCostsHint'.tr,
      body: BoxCostsView(mine: mine),
    );
  }
}
