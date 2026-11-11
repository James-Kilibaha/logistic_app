import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/ops.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import '../reports/analytics_tabs.dart';

/// Mizigo iliyokaa stoo zaidi ya siku za bure: gharama ya kila mmoja na kumkumbusha mteja.
class OverduePage extends StatefulWidget {
  const OverduePage({super.key});

  static Future<void> open() async {
    await Get.to(() => const OverduePage(), preventDuplicates: true);
  }

  @override
  State<OverduePage> createState() => _OverduePageState();
}

class _OverduePageState extends State<OverduePage> {
  OverdueSummary? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final data = await StorageRepo.overdue();
      if (!mounted) return;
      setState(() {
        _data = data;
        _picked.removeWhere((id) => !data.items.any((i) => i.invoiceId == id));
        _status = LoadStatus.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = LoadStatus.error;
      });
    }
  }

  /// Kumkumbusha mteja: [ids] tupu = wote waliochelewa.
  Future<void> _remind(List<String> ids) async {
    final whatsApp = AppController.to.can(AppModule.whatsapp, AppAction.insert) && await WhatsAppRepo.configured();
    final text = TextEditingController();
    String channel = 'SMS';
    final count = ids.isEmpty ? (_data?.items.length ?? 0) : ids.length;
    final ok = await showFormSheet(
      help: 'overdue',
      title: 'remindCustomers'.tr,
      subtitle: 'remindNInvoices'.trParams({'n': '$count'}),
      icon: Icons.notifications_active_outlined,
      submitLabel: 'send'.tr,
      submitIcon: Icons.send_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'SMS', label: Text('ch_SMS'.tr)),
              ButtonSegment(value: 'WHATSAPP', label: Text('ch_WHATSAPP'.tr), enabled: whatsApp),
              ButtonSegment(value: 'BOTH', label: Text('ch_BOTH'.tr), enabled: whatsApp),
            ],
            selected: {channel},
            onSelectionChanged: (v) => setState(() => channel = v.first),
          ),
          const SizedBox(height: 14),
          AppField(
            controller: text,
            label: 'customMessageOptional'.tr,
            hint: 'remindTemplateHint'.tr,
            helper: 'remindTokens'.tr,
            maxLines: 6,
            minLines: 3,
          ),
          const SizedBox(height: 8),
          Text('remindDefaultMsg'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        ],
      ),
      onSubmit: () async {
        final n = await StorageRepo.remind(invoiceIds: ids, channel: channel, text: text.text);
        Toast.success('remindedN'.trParams({'n': '$n'}));
      },
    );
    if (ok) {
      _picked.clear();
      AppController.to.notifyChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = _data;
    final canRemind = AppController.to.can(AppModule.store, AppAction.update);
    final canExcel = AppController.to.can(AppModule.report);
    // kuwakumbusha wote / wengi kwa mara moja = ujumbe kwa wateja wengi (BROADCAST)
    final canMany = AppController.to.can(AppModule.broadcast, AppAction.insert);

    return AppPage(
      title: 'overdueTitle'.tr,
      subtitle: data == null
          ? 'overdueSub'.tr
          : 'overdueRule'.trParams({'d': '${data.freeDays}', 'usd': data.chargePerDayUsd.toStringAsFixed(2)}),
      showBack: true,
      help: 'overdue',
      actions: [
        if (canExcel)
          IconButton(
            tooltip: 'downloadExcel'.tr,
            onPressed: () => saveExcel(() => AnalyticsRepo.excel('storage'), 'mizigo_stoo_${DateTime.now().millisecondsSinceEpoch}'),
            icon: const Icon(Icons.grid_on_rounded),
          ),
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: canRemind && (data?.items.isNotEmpty ?? false) && (canMany || _picked.length == 1)
          ? PageAction(
              icon: Icons.notifications_active_outlined,
              label: _picked.isEmpty ? 'remindAll'.tr : 'remindSelectedN'.trParams({'n': '${_picked.length}'}),
              onPressed: () => _remind(_picked.toList()),
            )
          : null,
      body: AsyncBody(
        status: _status,
        error: _error,
        isEmpty: data == null || data.items.isEmpty,
        onRetry: _load,
        empty: EmptyState(
          icon: Icons.verified_outlined,
          title: 'noOverdue'.tr,
          message: data == null ? null : 'noOverdueMsg'.trParams({'d': '${data.freeDays}'}),
        ),
        builder: () => PageScroll(
          onRefresh: _load,
          spacing: 12,
          children: [
            ResponsiveGrid(
              minItemWidth: 200,
              children: [
                StatCard(
                  label: 'overdueCount'.tr,
                  value: Fmt.number(data!.items.length),
                  icon: Icons.hourglass_bottom_rounded,
                  color: p.warning,
                ),
                StatCard(
                  label: 'storageChargesTotal'.tr,
                  value: Fmt.tsh(data.totalCharge),
                  icon: Icons.payments_outlined,
                  color: p.success,
                  hint: '\$${Fmt.money2(data.totalUsd)}',
                ),
                StatCard(
                  label: 'oldestInStore'.tr,
                  value: 'daysN'.trParams({'n': '${data.items.first.days}'}),
                  icon: Icons.warehouse_outlined,
                  color: p.danger,
                  hint: data.items.first.customerName,
                ),
              ],
            ),
            if (canRemind && canMany)
              Row(
                children: [
                  Checkbox(
                    value: _picked.length == data.items.length
                        ? true
                        : _picked.isEmpty
                            ? false
                            : null,
                    tristate: true,
                    onChanged: (_) => setState(() {
                      if (_picked.length == data.items.length) {
                        _picked.clear();
                      } else {
                        _picked.addAll(data.items.map((i) => i.invoiceId));
                      }
                    }),
                  ),
                  Text('selectAll'.tr, style: TextStyle(color: p.muted)),
                ],
              ),
            for (final item in data.items)
              _OverdueCard(
                item: item,
                picked: _picked.contains(item.invoiceId),
                canRemind: canRemind,
                onPick: (v) => setState(() => v ? _picked.add(item.invoiceId) : _picked.remove(item.invoiceId)),
                onRemind: () => _remind([item.invoiceId]),
                onOpen: () async {
                  await InvoiceFlows.open(item.invoiceId);
                  _load();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final OverdueItem item;
  final bool picked;
  final bool canRemind;
  final ValueChanged<bool> onPick;
  final VoidCallback onRemind;
  final VoidCallback onOpen;

  const _OverdueCard({
    required this.item,
    required this.picked,
    required this.canRemind,
    required this.onPick,
    required this.onRemind,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = item.chargeableDays >= 14 ? p.danger : p.warning;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canRemind)
                Checkbox(value: picked, onChanged: (v) => onPick(v ?? false))
              else
                const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.customerName,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.text)),
                        ),
                        Pill('daysN'.trParams({'n': '${item.days}'}), color: color, icon: Icons.schedule_rounded),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${'invoice'.tr} ${item.invoiceNumber} · ${Fmt.phone(item.phone)}',
                        style: TextStyle(color: p.muted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text('chargeableDaysN'.trParams({'n': '${item.chargeableDays}'}),
                            style: TextStyle(color: p.text, fontSize: 13)),
                        Text('\$${Fmt.money2(item.chargeUsd)} · ${Fmt.tsh(item.storageCharge)}',
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                        if (item.balance > 0)
                          Text('${'balance'.tr}: ${Fmt.tsh(item.balance)}', style: TextStyle(color: p.muted, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.remindedAt == null
                          ? 'neverReminded'.tr
                          : 'lastReminded'.trParams({'t': Fmt.relative(item.remindedAt)}),
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    tooltip: 'call'.tr,
                    onPressed: item.phone.isEmpty ? null : () => callPhone(item.phone),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  if (canRemind)
                    IconButton.filledTonal(
                      tooltip: 'remind'.tr,
                      onPressed: onRemind,
                      icon: const Icon(Icons.notifications_active_outlined),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
