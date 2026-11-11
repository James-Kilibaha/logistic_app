import 'dart:typed_data';

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
import '../../data/lookups.dart';
import '../../data/models/claim.dart';
import '../../data/models/invoice.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../claims/claim_flows.dart';
import '../customers/customer_flows.dart';
import '../delivery/handover_form.dart';
import '../payments/online_pay.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';
import 'invoice_forms.dart';
import 'invoice_sms_sheet.dart';
import 'photo_qr.dart';

class InvoiceDetailPage extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailPage({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  Debt? _debt;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _pdfBusy = false;
  Worker? _changes;

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
    try {
      final invoice = await InvoiceRepo.byId(widget.invoiceId);
      Debt? debt;
      if (invoice?.debt != null) {
        debt = await PaymentRepo.debtFor(widget.invoiceId);
      }
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _debt = debt ?? invoice?.debt;
        _status = invoice == null ? LoadStatus.error : LoadStatus.ready;
        _error = invoice == null ? 'errNotFound'.tr : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _pdf() async {
    final invoice = _invoice;
    if (invoice == null || _pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      final bytes = await InvoiceRepo.pdf(invoice);
      if (invoice.status == InvoiceStatus.store && _debt == null) {
        // PDF ya stoo inafungua deni la malipo.
        AppController.to.notifyChanged();
      }
      await PdfViewerPage.open(
        title: '${'invoice'.tr} ${invoice.number}',
        bytes: bytes,
        fileName: 'invoice_${invoice.invoiceNumber}',
      );
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _setStatus(InvoiceStatus status, {required String title, required String message}) async {
    final invoice = _invoice;
    if (invoice == null) return;
    final ok = await confirmAction(
      title: title,
      message: message,
      danger: status == InvoiceStatus.blocked,
      icon: status == InvoiceStatus.blocked ? Icons.block_rounded : Icons.lock_open_rounded,
    );
    if (!ok) return;
    final done = await runGuarded(() => InvoiceRepo.changeStatus(invoice.id, status.code), success: 'changesSaved'.tr);
    if (done) AppController.to.notifyChanged();
  }

  Future<void> _delete() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final ok = await confirmAction(
      title: 'deleteInvoice'.tr,
      message: 'deleteInvoiceMsg'.trParams({'n': invoice.number}),
      confirmText: 'delete'.tr,
      danger: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok) return;
    final done = await runGuarded(() => InvoiceRepo.delete(invoice.id), success: 'invoiceDeleted'.tr);
    if (!done) return;
    AppController.to.notifyChanged();
    if (mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    if (invoice == null) {
      return AppPage(
        help: 'invoiceDetail',
        title: 'invoice'.tr,
        showBack: true,
        body: _status == LoadStatus.error
            ? ErrorState(message: _error ?? '', onRetry: _load)
            : const LoadingList(rows: 4),
      );
    }

    final can = AppController.to.can;
    final status = invoice.status;
    final bool editable = status == InvoiceStatus.open && can(AppModule.product, AppAction.update);

    return AppPage(
      help: 'invoiceDetail',
      title: '${'invoice'.tr} ${invoice.number}',
      subtitle: invoice.customer?.name,
      showBack: true,
      actions: [
        if (invoice.products.isNotEmpty)
          IconButton(
            tooltip: 'invoicePdf'.tr,
            onPressed: _pdfBusy ? null : _pdf,
            icon: _pdfBusy
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.palette.primary))
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        if (invoice.products.isNotEmpty && can(AppModule.sms, AppAction.insert))
          IconButton(
            tooltip: 'invoiceSms'.tr,
            onPressed: () => showInvoiceSms(invoice),
            icon: const Icon(Icons.sms_outlined),
          ),
        if (invoice.products.isNotEmpty && can(AppModule.whatsapp, AppAction.insert))
          _WhatsAppAction(invoice: invoice, debt: _debt),
        if (invoice.products.isNotEmpty)
          IconButton(
            tooltip: 'qrLabels'.tr,
            onPressed: () => openPdfFrom(
              () => BoxRepo.invoiceLabels(invoice.id, perCarton: true),
              title: '${'qrLabels'.tr} ${invoice.number}',
              fileName: 'lebo_${invoice.invoiceNumber}',
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        if (can(AppModule.invoice, AppAction.block) &&
            (status == InvoiceStatus.open || status == InvoiceStatus.parking || status == InvoiceStatus.blocked))
          PopupMenuButton<String>(
            tooltip: 'actions'.tr,
            onSelected: (v) {
              if (v == 'block') {
                _setStatus(InvoiceStatus.blocked, title: 'blockInvoice'.tr, message: 'blockInvoiceMsg'.tr);
              } else if (v == 'reopen') {
                _setStatus(InvoiceStatus.open, title: 'reopenInvoice'.tr, message: 'reopenInvoiceMsg'.tr);
              } else if (v == 'delete') {
                _delete();
              }
            },
            itemBuilder: (context) => [
              if (status == InvoiceStatus.blocked) ...[
                PopupMenuItem(value: 'reopen', child: Text('reopenInvoice'.tr)),
                if (can(AppModule.invoice, AppAction.delete))
                  PopupMenuItem(value: 'delete', child: Text('deleteInvoice'.tr, style: TextStyle(color: context.palette.danger))),
              ] else
                PopupMenuItem(value: 'block', child: Text('blockInvoice'.tr, style: TextStyle(color: context.palette.danger))),
            ],
          ),
      ],
      body: LayoutBuilder(builder: (context, c) {
        final bool twoCols = c.maxWidth >= 1000;

        final left = <Widget>[
          _NextStep(invoice: invoice, debt: _debt, onPdf: _pdf, pdfBusy: _pdfBusy),
          _ProductsCard(invoice: invoice, editable: editable),
        ];
        final right = <Widget>[
          _SummaryCard(invoice: invoice, debt: _debt),
          _PeopleCard(invoice: invoice),
          _ClaimsCard(invoice: invoice, key: ValueKey('claims-${invoice.id}')),
          if (invoice.handovers.isNotEmpty) _HandoverCard(invoice: invoice, key: ValueKey('ho-${invoice.handovers.length}')),
          if (_debt != null) _PaymentsCard(invoice: invoice, debt: _debt!),
          _TimelineCard(invoice: invoice),
        ];

        if (!twoCols) {
          return PageScroll(onRefresh: _load, children: [_ProgressCard(invoice: invoice), ...left, ...right]);
        }
        return PageScroll(
          onRefresh: _load,
          children: [
            _ProgressCard(invoice: invoice),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(left)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(right)),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  List<Widget> _spaced(List<Widget> items) => [
        for (int i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i]],
      ];
}

// ------------------------------------------------------------- maendeleo

class _ProgressCard extends StatelessWidget {
  final Invoice invoice;

  const _ProgressCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = invoice.status;
    final flow = InvoiceStatus.flow;
    // Imekabidhiwa kwa mkopo: mzigo umetoka (hatua ya mwisho) ingawa deni bado.
    final int index = flow.indexOf(current == InvoiceStatus.delivered ? InvoiceStatus.completed : current);
    final events = invoice.events;

    DateTime? when(InvoiceStatus s) {
      for (final e in events.reversed) {
        if (e.status == s) return e.at;
      }
      return null;
    }

    if (current == InvoiceStatus.blocked) {
      return Card(
        color: p.danger.withValues(alpha: .06),
        child: ListTile(
          leading: Icon(Icons.block_rounded, color: p.danger),
          title: Text('invoiceBlocked'.tr, style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
          subtitle: Text('invoiceBlockedMsg'.tr),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < flow.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == 0 ? Colors.transparent : (i <= index ? p.primary : p.border),
                          ),
                        ),
                        _dot(p, i, index, flow[i]),
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == flow.length - 1 ? Colors.transparent : (i < index ? p.primary : p.border),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      StatusStyle.of(flow[i]).label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                        color: i <= index ? p.text : p.muted,
                      ),
                    ),
                    if (i <= index && when(flow[i]) != null)
                      Text(Fmt.date(when(flow[i])), style: TextStyle(fontSize: 11, color: p.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dot(AppPalette p, int i, int index, InvoiceStatus s) {
    final bool done = i < index;
    final bool active = i == index;
    final style = StatusStyle.of(s);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? p.primary : (active ? style.color : p.surfaceAlt),
        border: Border.all(color: done || active ? Colors.transparent : p.border),
        boxShadow: active ? [BoxShadow(color: style.color.withValues(alpha: .35), blurRadius: 10)] : null,
      ),
      child: Icon(done ? Icons.check_rounded : style.icon, size: 17, color: done || active ? Colors.white : p.muted),
    );
  }
}

/// Kinachofuata kwa invoice hii (mwongozo kwa mtumiaji).
class _NextStep extends StatelessWidget {
  final Invoice invoice;
  final Debt? debt;
  final VoidCallback onPdf;
  final bool pdfBusy;

  const _NextStep({required this.invoice, required this.debt, required this.onPdf, required this.pdfBusy});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    late final IconData icon;
    late final Color color;
    late final String title;
    late String message;
    Widget? action;

    switch (invoice.status) {
      case InvoiceStatus.open:
        if (invoice.products.isEmpty) {
          icon = Icons.add_box_outlined;
          color = p.primary;
          title = 'stepAddProducts'.tr;
          message = 'stepAddProductsMsg'.tr;
          if (can(AppModule.product, AppAction.insert)) {
            action = FilledButton.icon(
              onPressed: () => showProductForm(invoice),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('addProduct'.tr),
            );
          }
        } else {
          icon = Icons.person_pin_circle_outlined;
          color = const Color(0xFFD97706);
          title = 'stepReceiver'.tr;
          message = 'stepReceiverMsg'.tr;
          if (can(AppModule.receive, AppAction.insert)) {
            action = FilledButton.icon(
              onPressed: () => showReceiverForm(invoice),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: Text('registerReceiver'.tr),
            );
          }
        }
      case InvoiceStatus.parking:
        icon = Icons.inventory_2_outlined;
        color = const Color(0xFFD97706);
        title = 'stepPack'.tr;
        message = 'stepPackMsg'.tr;
        if (can(AppModule.package)) {
          action = OutlinedButton.icon(
            onPressed: () {
              Get.back();
              ShellController.to.go(NavSection.boxes);
            },
            icon: const Icon(Icons.inventory_2_outlined, size: 20),
            label: Text('goToBoxes'.tr),
          );
        }
      case InvoiceStatus.shipping:
        icon = Icons.local_shipping_outlined;
        color = const Color(0xFF0284C7);
        title = 'stepTransit'.tr;
        message = 'stepTransitMsg'.tr;
      case InvoiceStatus.store:
        if (debt == null) {
          icon = Icons.receipt_long_outlined;
          color = const Color(0xFF7C3AED);
          title = 'stepBill'.tr;
          message = 'stepBillMsg'.tr;
          action = FilledButton.icon(
            onPressed: pdfBusy ? null : onPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: Text('createInvoicePdf'.tr),
          );
        } else if (!debt!.isPaid) {
          icon = Icons.payments_outlined;
          color = p.success;
          title = 'stepPay'.tr;
          message = 'stepPayMsg'.trParams({'amount': Fmt.tsh(debt!.balance)});
          if (debt!.storageCharge > 0) {
            message += '\n${'storageNote'.trParams({'n': '${debt!.days}', 'amount': Fmt.tsh(debt!.storageCharge)})}';
          }
          if (can(AppModule.payment, AppAction.insert) || can(AppModule.handover, AppAction.update)) {
            action = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (can(AppModule.payment, AppAction.insert))
                  FilledButton.icon(
                    onPressed: () => showPaymentForm(invoice, debt!),
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    label: Text('receivePayment'.tr),
                  ),
                if (can(AppModule.payment, AppAction.insert))
                  OutlinedButton.icon(
                    onPressed: () => payInvoiceByPhone(
                      debtId: debt!.id,
                      balance: debt!.balance,
                      phone: invoice.customer?.phoneNumber,
                      invoiceNumber: invoice.invoiceNumber,
                    ),
                    icon: const Icon(Icons.phone_iphone_rounded, size: 20),
                    label: Text('payByPhone'.tr),
                  ),
                if (can(AppModule.handover, AppAction.update))
                  OutlinedButton.icon(
                    onPressed: () => showHandoverForm(invoice, debt!),
                    icon: const Icon(Icons.handshake_outlined, size: 20),
                    label: Text('handOverOnCredit'.tr),
                  ),
              ],
            );
          }
        } else {
          icon = Icons.handshake_outlined;
          color = p.success;
          title = invoice.handovers.isEmpty ? 'stepHandover'.tr : 'stepHandoverRest'.tr;
          message = invoice.handovers.isEmpty
              ? 'stepHandoverMsg'.trParams({'name': invoice.receiver?.name ?? invoice.customer?.name ?? ''})
              : 'stepHandoverRestMsg'.tr;
          if (can(AppModule.handover, AppAction.insert)) {
            action = FilledButton.icon(
              onPressed: () => showHandoverForm(invoice, debt!),
              icon: const Icon(Icons.handshake_outlined, size: 20),
              label: Text('handOver'.tr),
            );
          }
        }
      case InvoiceStatus.delivered:
        icon = Icons.warning_amber_rounded;
        color = p.warning;
        title = 'stepDeliveredOwing'.tr;
        message = 'stepDeliveredOwingMsg'.trParams({'amount': Fmt.tsh(debt?.balance ?? 0)});
        if (debt != null && can(AppModule.payment, AppAction.insert)) {
          action = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showPaymentForm(invoice, debt!),
                icon: const Icon(Icons.payments_outlined, size: 20),
                label: Text('receivePayment'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () => payInvoiceByPhone(
                  debtId: debt!.id,
                  balance: debt!.balance,
                  phone: invoice.customer?.phoneNumber,
                  invoiceNumber: invoice.invoiceNumber,
                ),
                icon: const Icon(Icons.phone_iphone_rounded, size: 20),
                label: Text('payByPhone'.tr),
              ),
            ],
          );
        }
      case InvoiceStatus.completed:
        icon = Icons.task_alt_rounded;
        color = p.success;
        title = 'stepDone'.tr;
        message = invoice.handover == null
            ? 'stepDoneMsg'.tr
            : 'stepDoneHandover'.trParams({
                'name': invoice.handover!.collectorName,
                'when': Fmt.dateTime(invoice.handover!.createdAt),
              });
      case InvoiceStatus.blocked:
      case InvoiceStatus.other:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: p.text)),
                      const SizedBox(height: 3),
                      Text(message, style: TextStyle(color: p.muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- bidhaa

class _ProductsCard extends StatelessWidget {
  final Invoice invoice;
  final bool editable;

  const _ProductsCard({required this.invoice, required this.editable});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    final bool canAdd = invoice.status == InvoiceStatus.open && can(AppModule.product, AppAction.insert);

    return SectionCard(
      title: 'products'.tr,
      subtitle: '${invoice.products.length} ${'items'.tr} · ${Fmt.kg(invoice.totalWeight)}',
      icon: Icons.inventory_2_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
      trailing: canAdd
          ? TextButton.icon(
              onPressed: () => showProductForm(invoice),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('add'.tr),
            )
          : null,
      child: invoice.products.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, color: p.muted, size: 34),
                  const SizedBox(height: 8),
                  Text('noProducts'.tr, style: TextStyle(color: p.muted)),
                ],
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < invoice.products.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  _ProductRow(product: invoice.products[i], invoice: invoice, editable: editable),
                ],
              ],
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final Invoice invoice;
  final bool editable;

  const _ProductRow({required this.product, required this.invoice, required this.editable});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    final details = <String>[
      '${Fmt.number(product.quantities)} ${'ctn'.tr}',
      Fmt.kg(product.weight),
      if (product.isSea && product.cbm > 0) '${product.cbm.toStringAsFixed(3)} CBM',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          ProductThumb(product.path, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Pill(
                      product.isSea ? 'sea'.tr : 'air'.tr,
                      color: product.isSea ? const Color(0xFF0891B2) : const Color(0xFF4F46E5),
                      icon: product.isSea ? Icons.directions_boat_outlined : Icons.flight_rounded,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(details.join(' · '), style: TextStyle(color: p.muted, fontSize: 12.5)),
                if ((product.trackNumber ?? '').isNotEmpty)
                  Text(
                    '${'track'.tr}: ${product.trackNumber}',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if ((product.officeCode ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    // Wrap (si Row): kwenye simu nafasi ni ndogo, badge inashuka mstari unaofuata badala ya overflow
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Text('${'officeCode'.tr}:', style: TextStyle(color: p.muted, fontSize: 12.5)),
                        OfficeCodeBadge(product.officeCode!, dense: true),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(Fmt.money(product.unitPrice), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
          if ((product.officeCode ?? '').isNotEmpty &&
              (can(AppModule.product, AppAction.update) || can(AppModule.product, AppAction.insert)) &&
              invoice.status != InvoiceStatus.delivered &&
              invoice.status != InvoiceStatus.completed)
            IconButton(
              tooltip: isMobileDevice ? 'takePhoto'.tr : 'photoByPhone'.tr,
              icon: Icon(isMobileDevice ? Icons.add_a_photo_outlined : Icons.qr_code_2_rounded, size: 20, color: p.primary),
              onPressed: () async {
                if (!isMobileDevice) return showProductPhotoQr(product);
                final picked = await pickImage(camera: true);
                if (picked == null) return;
                final ok = await runGuarded(() => PhotoRepo.upload(product.officeCode!, picked.bytes, picked.name),
                    success: 'photoSaved'.tr);
                if (ok) AppController.to.notifyChanged();
              },
            ),
          if (editable)
            PopupMenuButton<String>(
              tooltip: 'actions'.tr,
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (v) {
                if (v == 'edit') showProductForm(invoice, product: product);
                if (v == 'delete') deleteProduct(product);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('edit'.tr)),
                if (can(AppModule.product, AppAction.delete))
                  PopupMenuItem(value: 'delete', child: Text('delete'.tr, style: TextStyle(color: p.danger))),
              ],
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- muhtasari

class _SummaryCard extends StatelessWidget {
  final Invoice invoice;
  final Debt? debt;

  const _SummaryCard({required this.invoice, required this.debt});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final air = invoice.products.where((e) => !e.isSea).length;
    final sea = invoice.products.length - air;
    return SectionCard(
      title: 'summary'.tr,
      icon: Icons.summarize_outlined,
      child: Column(
        children: [
          InfoRow(label: 'status'.tr, value: '', trailing: StatusChip(invoice.status, dense: true)),
          _OfficeRow(invoice: invoice),
          InfoRow(label: 'created'.tr, value: Fmt.dateTime(invoice.createdAt)),
          InfoRow(label: 'cartons'.tr, value: Fmt.number(invoice.totalQuantity)),
          InfoRow(label: 'weight'.tr, value: Fmt.kg(invoice.totalWeight)),
          if (invoice.products.isNotEmpty)
            InfoRow(label: 'carrierType'.tr, value: '${'air'.tr}: $air · ${'sea'.tr}: $sea'),
          Divider(color: p.border),
          InfoRow(label: 'total'.tr, value: Fmt.tsh(invoice.total), emphasize: true),
          if (debt != null) ...[
            if (debt!.storageCharge > 0)
              InfoRow(label: 'storageDays'.trParams({'n': '${debt!.days}'}), value: Fmt.tsh(debt!.storageCharge)),
            if (debt!.discount > 0) InfoRow(label: 'discount'.tr, value: '- ${Fmt.tsh(debt!.discount)}'),
            if (debt!.storageCharge > 0 || debt!.discount > 0)
              InfoRow(label: 'invoiceTotal'.tr, value: Fmt.tsh(debt!.total), emphasize: true),
            InfoRow(label: 'paid'.tr, value: Fmt.tsh(debt!.paid)),
            InfoRow(
              label: 'balanceDue'.tr,
              value: Fmt.tsh(debt!.balance),
              emphasize: true,
              trailing: debt!.isPaid ? Icon(Icons.check_circle_rounded, color: p.success, size: 18) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  final Invoice invoice;

  const _PeopleCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = invoice.customer;
    final r = invoice.receiver;
    return SectionCard(
      title: 'people'.tr,
      icon: Icons.people_alt_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
      child: Column(
        children: [
          if (c != null)
            _person(
              context,
              label: 'customer'.tr,
              initials: c.initials,
              name: c.name,
              phone: c.phoneNumber,
              onTap: () => CustomerFlows.open(c),
            ),
          Divider(height: 1, color: p.border),
          if (r != null)
            _person(
              context,
              label: 'receiver'.tr,
              initials: r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
              name: r.name,
              phone: r.phoneNumber,
              extra: '${'pickupCode'.tr}: ${r.trackNumber}',
              actions: _receiverActions(context, r),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined, color: p.muted),
                  const SizedBox(width: 12),
                  Expanded(child: Text('noReceiverYet'.tr, style: TextStyle(color: p.muted))),
                  if (invoice.status == InvoiceStatus.open &&
                      invoice.products.isNotEmpty &&
                      AppController.to.can(AppModule.receive, AppAction.insert))
                    TextButton(onPressed: () => showReceiverForm(invoice), child: Text('register'.tr)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Hariri (kabla ya kukabidhi) / futa (kabla ya kusafirisha) mpokeaji.
  Widget? _receiverActions(BuildContext context, Receiver r) {
    final can = AppController.to.can;
    final s = invoice.status;
    final bool canEdit = can(AppModule.receive, AppAction.update) &&
        s != InvoiceStatus.delivered &&
        s != InvoiceStatus.completed;
    final bool canDelete = can(AppModule.receive, AppAction.delete) &&
        (s == InvoiceStatus.open || s == InvoiceStatus.parking || s == InvoiceStatus.blocked);
    if (!canEdit && !canDelete) return null;
    final p = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'actions'.tr,
      icon: Icon(Icons.more_vert_rounded, color: p.muted, size: 20),
      onSelected: (v) {
        if (v == 'edit') showReceiverForm(invoice, current: r);
        if (v == 'delete') deleteReceiver(invoice, r);
      },
      itemBuilder: (_) => [
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text('editReceiver'.tr),
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_remove_outlined, size: 20, color: p.danger),
              title: Text('deleteReceiver'.tr, style: TextStyle(color: p.danger)),
            ),
          ),
      ],
    );
  }

  Widget _person(
    BuildContext context, {
    required String label,
    required String initials,
    required String name,
    required String phone,
    String? extra,
    VoidCallback? onTap,
    Widget? actions,
  }) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Initials(initials, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6)),
                  Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  Text(Fmt.phone(phone), style: TextStyle(color: p.muted, fontSize: 13)),
                  if (extra != null) Text(extra, style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
            IconButton(tooltip: 'call'.tr, onPressed: () => callPhone(phone), icon: Icon(Icons.call_outlined, color: p.primary)),
            if (actions != null) actions,
          ],
        ),
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  final Invoice invoice;
  final Debt debt;

  const _PaymentsCard({required this.invoice, required this.debt});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final can = AppController.to.can;
    final bool canPay = !debt.isPaid && can(AppModule.payment, AppAction.insert);
    final bool canDiscount = can(AppModule.discount, AppAction.insert);
    final bool canRefund = debt.paid > 0 && can(AppModule.refund, AppAction.insert);
    final bool canAdjust = canDiscount || canRefund;
    return SectionCard(
      title: 'payments'.tr,
      icon: Icons.payments_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPay)
            TextButton.icon(
              onPressed: () => showPaymentForm(invoice, debt),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('receivePayment'.tr),
            ),
          if (canAdjust)
            PopupMenuButton<String>(
              tooltip: 'actions'.tr,
              onSelected: (v) {
                if (v == 'discount') showDiscountForm(invoice, debt);
                if (v == 'refund') showRefundForm(invoice, debt);
              },
              itemBuilder: (context) => [
                if (canDiscount) PopupMenuItem(value: 'discount', child: Text('giveDiscount'.tr)),
                if (canRefund) PopupMenuItem(value: 'refund', child: Text('refund'.tr)),
              ],
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DebtBreakdown(debt: debt),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: debt.progress,
              minHeight: 8,
              color: debt.isPaid ? p.success : p.primary,
              backgroundColor: p.surfaceAlt,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${(debt.progress * 100).round()}% ${'paidLower'.tr}', style: TextStyle(color: p.muted, fontSize: 12.5)),
              const Spacer(),
              if (debt.isPaid) Pill('fullyPaid'.tr, color: p.success, icon: Icons.check_rounded, dense: true),
            ],
          ),
          if (debt.discountNote != null && debt.discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${'discount'.tr}: ${debt.discountNote}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ),
          const SizedBox(height: 8),
          if (debt.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('noPaymentsYet'.tr, style: TextStyle(color: p.muted)),
            )
          else
            for (final pay in debt.payments)
              InkWell(
                onTap: () => openReceipt(pay),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(pay.isRefund ? Icons.north_east_rounded : Icons.south_west_rounded,
                          size: 18, color: pay.isRefund ? p.danger : p.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (pay.isRefund) 'refund'.tr,
                                pay.institute?.name ?? '—',
                                if (pay.receiptNumber != null) pay.receiptNumber!,
                              ].join(' · '),
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                            ),
                            Text(
                              [
                                Fmt.dateTime(pay.createdAt),
                                if (pay.isForeign) '${pay.currency} ${Fmt.money2(pay.amountOriginal)}',
                                if (pay.note != null) pay.note!,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${pay.isRefund ? '-' : ''}${Fmt.money(pay.paid)}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: pay.isRefund ? p.danger : p.success),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.receipt_outlined, size: 18, color: p.muted),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Nani alichukua mzigo, lini, kitambulisho na sahihi - kila awamu ya makabidhiano.
class _HandoverCard extends StatefulWidget {
  final Invoice invoice;

  const _HandoverCard({super.key, required this.invoice});

  @override
  State<_HandoverCard> createState() => _HandoverCardState();
}

class _HandoverCardState extends State<_HandoverCard> {
  HandoverStatus? _status;

  @override
  void initState() {
    super.initState();
    HandoverRepo.status(widget.invoice.id).then((s) {
      if (mounted) setState(() => _status = s);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final invoice = widget.invoice;
    final handovers = _status?.handovers ?? invoice.handovers;
    final left = _status?.remainingCartons ?? 0;
    return SectionCard(
      title: 'handoverTitle'.tr,
      subtitle: handovers.length > 1 ? 'handoverRounds'.trParams({'n': '${handovers.length}'}) : null,
      icon: Icons.handshake_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_status != null && !_status!.complete)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: p.warning.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
              child: Text(
                'stillInStore'.trParams({'n': Fmt.number(left), 'total': Fmt.number(_status!.totalCartons)}),
                style: TextStyle(color: p.warning, fontWeight: FontWeight.w700),
              ),
            ),
          for (int i = handovers.length - 1; i >= 0; i--) ...[
            _HandoverRound(invoice: invoice, handover: handovers[i], round: handovers.length > 1 ? i + 1 : null),
            if (i > 0) Divider(color: p.border, height: 24),
          ],
          if (invoice.status == InvoiceStatus.delivered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Pill('stDelivered'.tr, color: p.warning, icon: Icons.warning_amber_rounded, dense: true),
            ),
        ],
      ),
    );
  }
}

class _HandoverRound extends StatelessWidget {
  final Invoice invoice;
  final Handover handover;
  final int? round;

  const _HandoverRound({required this.invoice, required this.handover, this.round});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final h = handover;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (round != null) Pill('${'round'.tr} $round', color: p.primary, dense: true),
            if (h.partial) ...[const SizedBox(width: 6), Pill('partial'.tr, color: p.warning, dense: true)],
            const Spacer(),
            TextButton.icon(
              onPressed: () => openHandoverNote(invoice, handoverId: h.id),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text('handoverNote'.tr),
            ),
          ],
        ),
        InfoRow(label: 'collectorName'.tr, value: h.collectorName),
        InfoRow(label: 'phone'.tr, value: Fmt.phone(h.collectorPhone)),
        if (h.idNumber != null) InfoRow(label: idTypeLabel(h.idType), value: h.idNumber!),
        InfoRow(label: 'handedOverAt'.tr, value: Fmt.dateTime(h.createdAt)),
        if (h.staffName != null) InfoRow(label: 'handedOverBy'.tr, value: h.staffName!),
        if (h.items.isNotEmpty)
          InfoRow(
            label: 'cartonsTaken'.tr,
            value: h.items.map((i) => '${i.description} ×${Fmt.number(i.cartons)}').join(', '),
          ),
        if (!h.isReceiver) InfoRow(label: 'status'.tr, value: 'onBehalf'.tr),
        if (h.onCredit) InfoRow(label: 'balanceAtHandover'.tr, value: Fmt.tsh(h.balance)),
        if (h.note != null) InfoRow(label: 'note'.tr, value: h.note!),
        if (h.hasSignature || h.hasPhoto) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (h.hasSignature)
                Expanded(child: _HandoverImage(invoiceId: invoice.id, handoverId: h.id, kind: 'signature')),
              if (h.hasSignature && h.hasPhoto) const SizedBox(width: 10),
              if (h.hasPhoto) Expanded(child: _HandoverImage(invoiceId: invoice.id, handoverId: h.id, kind: 'photo')),
            ],
          ),
        ],
      ],
    );
  }
}

class _HandoverImage extends StatefulWidget {
  final String invoiceId;
  final String handoverId;
  final String kind;

  const _HandoverImage({required this.invoiceId, required this.handoverId, required this.kind});

  @override
  State<_HandoverImage> createState() => _HandoverImageState();
}

class _HandoverImageState extends State<_HandoverImage> {
  late final Future<Uint8List> _bytes = HandoverRepo.file(widget.invoiceId, widget.kind, handoverId: widget.handoverId);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: widget.kind == 'signature' ? Colors.white : p.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(snap.data!, fit: widget.kind == 'signature' ? BoxFit.contain : BoxFit.cover);
          }
          if (snap.hasError) return Icon(Icons.broken_image_outlined, color: p.muted);
          return const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        },
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Invoice invoice;

  const _TimelineCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final events = invoice.events.reversed.toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'history'.tr,
      icon: Icons.history_rounded,
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: StatusStyle.of(events[i].status).color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < events.length - 1) Expanded(child: Container(width: 2, color: p.border)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            events[i].status == InvoiceStatus.other
                                ? events[i].code
                                : StatusStyle.of(events[i].status).label,
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                          ),
                          Text(Fmt.dateTime(events[i].at), style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// Ofisi ya kuchukulia mzigo; inaweza kubadilishwa na wanaoona ofisi zote.
class _OfficeRow extends StatelessWidget {
  final Invoice invoice;

  const _OfficeRow({required this.invoice});

  Future<void> _change(BuildContext context) async {
    final offices = await Lookups.to.loadOffices();
    if (!context.mounted || offices.isEmpty) return;
    final picked = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('pickupOffice'.tr),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'none'), child: Text('noOffice'.tr)),
          for (final o in offices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, o),
              child: Text(o.label, style: TextStyle(fontWeight: o.id == invoice.officeId ? FontWeight.w700 : null)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final id = picked is Office ? picked.id : null;
    if (await runGuarded(() => InvoiceRepo.setOffice(invoice.id, id), success: 'changesSaved'.tr)) {
      AppController.to.notifyChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offices = Lookups.to.offices;
      if (offices.isEmpty && invoice.officeId == null) return const SizedBox.shrink();
      String name = '—';
      for (final o in offices) {
        if (o.id == invoice.officeId) name = o.name;
      }
      final me = AppController.to.user.value;
      final canMove = !(me?.officeOnly ?? false) && AppController.to.can(AppModule.invoice, AppAction.update);
      return InfoRow(
        label: 'pickupOffice'.tr,
        value: name,
        trailing: canMove
            ? IconButton(
                tooltip: 'change'.tr,
                visualDensity: VisualDensity.compact,
                onPressed: () => _change(context),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              )
            : null,
      );
    });
  }
}


/// Madai ya ankara hii (yanaonekana yakiwepo) + kitufe cha kuripoti tatizo.
class _ClaimsCard extends StatefulWidget {
  final Invoice invoice;

  const _ClaimsCard({super.key, required this.invoice});

  @override
  State<_ClaimsCard> createState() => _ClaimsCardState();
}

class _ClaimsCardState extends State<_ClaimsCard> {
  List<CargoClaim> _claims = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppController.to.can(AppModule.claim)) return;
    try {
      final list = await ClaimRepo.search(invoiceId: widget.invoice.id);
      if (mounted) setState(() => _claims = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canReport = AppController.to.can(AppModule.claim, AppAction.insert) &&
        const [InvoiceStatus.store, InvoiceStatus.delivered, InvoiceStatus.completed, InvoiceStatus.shipping]
            .contains(widget.invoice.status);
    if (_claims.isEmpty && !canReport) return const SizedBox.shrink();
    if (_claims.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            if (await ClaimFlows.report(widget.invoice)) _load();
          },
          icon: Icon(Icons.report_problem_outlined, size: 18, color: p.danger),
          label: Text('reportCargoProblem'.tr, style: TextStyle(color: p.danger)),
        ),
      );
    }
    return SectionCard(
      title: 'claims'.tr,
      icon: Icons.report_problem_outlined,
      trailing: canReport
          ? TextButton.icon(
              onPressed: () async {
                if (await ClaimFlows.report(widget.invoice)) _load();
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('add'.tr),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _claims.length; i++) ...[
            if (i > 0) Divider(color: p.border, height: 20),
            ClaimTile(claim: _claims[i], showInvoice: false),
          ],
        ],
      ),
    );
  }
}


/// Kutuma ankara / risiti / hati ya makabidhiano kwa mteja kupitia WhatsApp (kama server imewekewa).
class _WhatsAppAction extends StatelessWidget {
  final Invoice invoice;
  final Debt? debt;

  const _WhatsAppAction({required this.invoice, this.debt});

  Future<void> _send(String kind, {String? paymentId}) async {
    final ok = await confirmAction(
      title: 'sendWhatsApp'.tr,
      message: 'sendWhatsAppMsg'.trParams({
        'doc': 'wa_$kind'.tr,
        'phone': Fmt.phone(invoice.customer?.phoneNumber),
      }),
      confirmText: 'send'.tr,
      icon: Icons.chat_rounded,
    );
    if (!ok) return;
    await runGuarded(
      () => WhatsAppRepo.sendDocument(invoice.id, kind: kind, paymentId: paymentId),
      success: 'whatsAppSent'.tr,
    );
  }

  /// Ujumbe wa maandishi + picha (si lazima) kwa mteja.
  Future<void> _message() async {
    final text = TextEditingController(text: 'Habari ${invoice.customer?.name ?? ''}, ');
    PickedImage? image;
    final ok = await showFormSheet(
      help: 'invoiceDetail',
      title: 'wa_MESSAGE'.tr,
      subtitle: '${invoice.customer?.name ?? ''} · ${Fmt.phone(invoice.customer?.phoneNumber)}',
      icon: Icons.chat_rounded,
      submitLabel: 'send'.tr,
      submitIcon: Icons.send_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            controller: text,
            label: 'message'.tr,
            icon: Icons.notes_rounded,
            required: true,
            maxLines: 5,
            minLines: 3,
            capitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final img = await pickImage(camera: false);
                  if (img != null) setState(() => image = img);
                },
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(image == null ? 'addPhoto'.tr : 'changePhoto'.tr),
              ),
              if (image != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(image!.bytes, width: 56, height: 56, fit: BoxFit.cover),
                ),
                IconButton(onPressed: () => setState(() => image = null), icon: const Icon(Icons.close_rounded)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text('waTemplateHint'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12)),
        ],
      ),
      onSubmit: () => WhatsAppRepo.sendMessage(
        text: text.text,
        invoiceId: invoice.id,
        image: image?.bytes,
        imageName: image?.name,
      ),
    );
    if (ok) Toast.success(Fmt.phone(invoice.customer?.phoneNumber), title: 'whatsAppSent'.tr);
  }

  Future<void> _photos() async {
    final ok = await confirmAction(
      title: 'wa_PHOTOS'.tr,
      message: 'waPhotosMsg'.trParams({
        'n': '${invoice.products.where((p) => p.path != null).length}',
        'phone': Fmt.phone(invoice.customer?.phoneNumber),
      }),
      confirmText: 'send'.tr,
      icon: Icons.photo_library_outlined,
    );
    if (!ok) return;
    try {
      final n = await WhatsAppRepo.sendProductPhotos(invoice.id);
      Toast.success('waPhotosSent'.trParams({'n': '$n'}), title: 'whatsAppSent'.tr);
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WhatsAppRepo.configured(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        final payments = debt?.payments.where((p) => !p.isRefund).toList() ?? const <Payment>[];
        return PopupMenuButton<String>(
          tooltip: 'WhatsApp',
          icon: const Icon(Icons.chat_outlined, color: Color(0xFF16A34A)),
          onSelected: (v) {
            if (v == 'MESSAGE') {
              _message();
            } else if (v == 'PHOTOS') {
              _photos();
            } else if (v == 'RECEIPT' && payments.isNotEmpty) {
              _send('RECEIPT', paymentId: payments.first.id);
            } else {
              _send(v);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'MESSAGE', child: Text('wa_MESSAGE'.tr)),
            if (invoice.products.any((p) => p.path != null))
              PopupMenuItem(value: 'PHOTOS', child: Text('wa_PHOTOS'.tr)),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'INVOICE', child: Text('wa_INVOICE'.tr)),
            if (payments.isNotEmpty) PopupMenuItem(value: 'RECEIPT', child: Text('wa_RECEIPT'.tr)),
            if (invoice.handovers.isNotEmpty) PopupMenuItem(value: 'HANDOVER', child: Text('wa_HANDOVER'.tr)),
          ],
        );
      },
    );
  }
}
