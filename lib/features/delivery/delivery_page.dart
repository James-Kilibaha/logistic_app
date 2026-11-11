import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/invoice.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import '../invoices/invoice_forms.dart';
import 'delivery_controller.dart';
import 'handed_over_tab.dart';
import 'handover_form.dart';

/// Kukabidhi mizigo iliyofika stoo: ankara (PDF), malipo na kumkabidhi mpokeaji.
class DeliveryPage extends GetView<DeliveryController> {
  const DeliveryPage({super.key});

  /// Mpokeaji anakuja na "pickup code" - kuiskani kunafungua invoice yake.
  Future<void> _scanPickup() async {
    final code = await scanCode(title: 'scanPickupCode'.tr);
    if (code == null) return;
    final q = code.toLowerCase();
    final key = code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    for (final i in controller.items) {
      final byOfficeCode =
          i.products.any((p) => (p.officeCode ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), '') == key);
      if ((i.receiver?.trackNumber ?? '').toLowerCase() == q || i.invoiceNumber == code || byOfficeCode) {
        await InvoiceFlows.open(i.id);
        return;
      }
    }
    Toast.warning('pickupNotFound'.trParams({'code': code}), title: 'notFound'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPage(
      help: 'delivery',
      title: 'navDelivery'.tr,
      subtitle: 'hintDelivery'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: PageAction(icon: Icons.qr_code_scanner_rounded, label: 'scanPickupCode'.tr, onPressed: _scanPickup),
      bottom: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(icon: const Icon(Icons.warehouse_outlined, size: 20), text: 'tabToHandOver'.tr),
          Tab(icon: const Icon(Icons.task_alt_rounded, size: 20), text: 'tabHandedOver'.tr),
        ],
      ),
      body: TabBarView(children: [
        Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchDeliveryHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() => FilterChips<DeliveryFilter>(
                  values: DeliveryFilter.values,
                  selected: controller.filter.value,
                  label: (f) => switch (f) {
                    DeliveryFilter.all => 'all'.tr,
                    DeliveryFilter.notBilled => 'notBilled'.tr,
                    DeliveryFilter.owing => 'owing'.tr,
                  },
                  count: controller.countFor,
                  onSelected: (f) => controller.filter.value = f,
                )),
            trailing: [
              Obx(() {
                final owing = controller.totalOwing;
                if (owing <= 0 || !context.isMediumUp) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Pill('${'toCollect'.tr}: ${Fmt.tsh(owing)}', color: context.palette.danger),
                );
              }),
            ],
          ),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'noDeliveries'.tr,
                  message: 'noDeliveriesMsg'.tr,
                ),
                builder: () => DataList<Invoice>(
                  items: list,
                  onRefresh: controller.refreshList,
                  onTap: (i) => InvoiceFlows.open(i.id),
                  columns: [
                    ColumnSpec('invoice'.tr, flex: 2),
                    ColumnSpec('receiver'.tr, flex: 3),
                    ColumnSpec('total'.tr, flex: 2, align: TextAlign.end),
                    ColumnSpec('balance'.tr, flex: 2, align: TextAlign.end),
                    ColumnSpec('', flex: 2, align: TextAlign.end),
                  ],
                  cells: (context, i) => [
                    CellText(i.number, sub: i.customer?.name, bold: true),
                    CellText(i.receiver?.name ?? '—', sub: i.receiver == null ? null : '${'pickupCode'.tr}: ${i.receiver!.trackNumber}'),
                    CellText(Fmt.money(i.total), align: TextAlign.end, sub: Fmt.kg(i.totalWeight)),
                    _Balance(invoice: i),
                    _DeliveryAction(invoice: i),
                  ],
                  card: (context, i) => Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Initials(i.customer?.initials ?? '?', size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.customer?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                                  Text(
                                    '${i.number} · ${i.receiver?.name ?? '—'}',
                                    style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            _Balance(invoice: i),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: _DeliveryAction(invoice: i)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
        const HandedOverTab(),
      ]),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  final Invoice invoice;

  const _Balance({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final debt = invoice.debt;
    if (debt == null) return Pill('notBilled'.tr, color: const Color(0xFF7C3AED), dense: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Fmt.money(debt.balance),
          style: TextStyle(fontWeight: FontWeight.w700, color: debt.isPaid ? p.success : p.danger),
        ),
        Text('${'paid'.tr} ${Fmt.money(debt.paid)}', style: TextStyle(color: p.muted, fontSize: 12)),
        if (debt.storageCharge > 0)
          Text('storageShort'.trParams({'n': '${debt.days}'}), style: TextStyle(color: p.warning, fontSize: 11.5)),
      ],
    );
  }
}

/// Kitufe cha kinachofuata: kutengeneza ankara (deni) au kupokea malipo.
class _DeliveryAction extends StatefulWidget {
  final Invoice invoice;

  const _DeliveryAction({required this.invoice});

  @override
  State<_DeliveryAction> createState() => _DeliveryActionState();
}

class _DeliveryActionState extends State<_DeliveryAction> {
  bool _busy = false;

  Future<void> _bill() async {
    setState(() => _busy = true);
    try {
      final bytes = await InvoiceRepo.pdf(widget.invoice);
      AppController.to.notifyChanged();
      await PdfViewerPage.open(
        title: '${'invoice'.tr} ${widget.invoice.number}',
        bytes: bytes,
        fileName: 'invoice_${widget.invoice.invoiceNumber}',
      );
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final debt = await PaymentRepo.debtFor(widget.invoice.id);
      if (debt != null) await showPaymentForm(widget.invoice, debt);
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handOver() async {
    setState(() => _busy = true);
    try {
      final debt = await PaymentRepo.debtFor(widget.invoice.id);
      if (debt != null) await showHandoverForm(widget.invoice, debt);
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14));
    final debt = widget.invoice.debt;
    if (debt == null) {
      return FilledButton.tonalIcon(
        style: style,
        onPressed: _busy ? null : _bill,
        icon: _busy
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary))
            : const Icon(Icons.receipt_long_outlined, size: 18),
        label: Text('bill'.tr),
      );
    }
    if (!AppController.to.can(AppModule.handover, AppAction.insert)) return const SizedBox.shrink();
    if (debt.isPaid) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: context.palette.success,
        ),
        onPressed: _busy ? null : _handOver,
        icon: _busy ? const ButtonSpinner() : const Icon(Icons.handshake_outlined, size: 18),
        label: Text('handOver'.tr),
      );
    }
    return FilledButton.icon(
      style: style,
      onPressed: _busy ? null : _pay,
      icon: _busy ? const ButtonSpinner() : const Icon(Icons.payments_outlined, size: 18),
      label: Text('pay'.tr),
    );
  }
}
