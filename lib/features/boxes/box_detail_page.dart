import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/box.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';
import '../../data/models/invoice.dart';
import '../invoices/invoices_controller.dart';
import '../shell/nav.dart';
import '../shell/shell_page.dart';
import 'box_drag.dart';
import 'box_costs.dart';
import 'box_flows.dart';
import 'arrivals_page.dart';

class BoxDetailPage extends StatefulWidget {
  final String boxId;
  final Box? initial;

  const BoxDetailPage({super.key, required this.boxId, this.initial});

  @override
  State<BoxDetailPage> createState() => _BoxDetailPageState();
}

class _BoxDetailPageState extends State<BoxDetailPage> {
  Box? _box;
  List<BoxProduct> _inside = const [];
  List<BoxProduct> _waiting = const [];
  int _otherCarrier = 0; // bidhaa za usafiri mwingine (AIR/SEA) zisizofaa box hili
  final Set<String> _selected = {};
  final _search = TextEditingController();
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _busy = false;
  Worker? _changes;

  @override
  void initState() {
    super.initState();
    _box = widget.initial;
    _changes = ever<int>(AppController.to.changes, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final boxes = await BoxRepo.all();
      Box? box;
      for (final b in boxes) {
        if (b.id == widget.boxId) box = b;
      }
      if (box == null) throw ApiNotFound();
      final inside = await BoxRepo.products(box.id);
      final found = box;
      final all = found.isOpen ? await BoxRepo.available() : const <BoxProduct>[];
      final waiting = all.where((p) => found.accepts(p.carrierType)).toList();
      if (!mounted) return;
      setState(() {
        _box = box;
        _inside = inside;
        _waiting = waiting;
        _otherCarrier = all.length - waiting.length;
        _selected.removeWhere((id) => !waiting.any((w) => w.id == id));
        _status = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = LoadStatus.error;
        _error = e is ApiNotFound ? 'errNotFound'.tr : e.toString();
      });
    }
  }

  Future<void> _addSelected() async {
    final box = _box;
    if (box == null || _selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await dropCargo(box, _waiting.where((w) => _selected.contains(w.id)).toList());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _selected.clear();
    });
  }

  Future<void> _remove(BoxProduct product) async {
    final box = _box;
    if (box == null) return;
    final done = await runGuarded(() => BoxRepo.removeProduct(box.id, product.id), success: 'removedFromBox'.tr);
    if (done) AppController.to.notifyChanged();
  }

  /// Code ya ofisi bila nafasi/vistari, herufi kubwa (kama backend).
  static String _codeKey(String? v) => (v ?? '').toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// Kuskani track number au QR ya lebo (code ya ofisi) na kuichagua kwenye orodha ya zinazosubiri.
  Future<void> _scanToSelect() async {
    final code = await scanCode(title: 'scanProduct'.tr);
    if (code == null) return;
    final q = code.toLowerCase();
    final key = _codeKey(code);
    final match = _waiting
        .where((w) => (w.trackNumber ?? '').toLowerCase() == q || (key.isNotEmpty && _codeKey(w.officeCode) == key))
        .toList();
    if (match.isEmpty) {
      Toast.warning('notInWaitingList'.trParams({'code': code}), title: 'notFound'.tr);
      return;
    }
    setState(() => _selected.addAll(match.map((m) => m.id)));
    Toast.info(match.first.description, title: 'selected'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    final can = AppController.to.can;
    if (box == null || (_status != LoadStatus.ready && _inside.isEmpty && _waiting.isEmpty)) {
      return AppPage(
        help: 'boxDetail',
        title: box == null ? 'box'.tr : 'Box ${box.boxId}',
        showBack: true,
        body: _status == LoadStatus.error ? ErrorState(message: _error ?? '', onRetry: _load) : const LoadingList(rows: 4),
      );
    }

    final bool editable = box.isOpen && can(AppModule.package, AppAction.update);
    final double insideWeight = _inside.fold<double>(0, (s, p) => s + p.weight);

    return AppPage(
      help: 'boxDetail',
      title: 'Box ${box.boxId}',
      subtitle: box.isOpen ? 'packing'.tr : (box.inTransit ? 'inTransit'.tr : 'arrived'.tr),
      showBack: true,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        if (box.arrived)
          IconButton(
            tooltip: 'arrTitleShort'.tr,
            onPressed: () => ArrivalsPage.open(box),
            icon: const Icon(Icons.mark_chat_unread_outlined),
          ),
        if (_inside.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'print'.tr,
            icon: const Icon(Icons.print_outlined),
            onSelected: (v) => switch (v) {
              'manifest' => openPdfFrom(() => BoxRepo.manifest(box.id),
                  title: '${'manifest'.tr} ${box.boxId}', fileName: 'manifest_${box.boxId}'),
              'labels' => openPdfFrom(() => BoxRepo.labels(box.id),
                  title: '${'qrLabels'.tr} ${box.boxId}', fileName: 'lebo_${box.boxId}'),
              _ => openPdfFrom(() => BoxRepo.labels(box.id, perCarton: true),
                  title: '${'qrLabels'.tr} ${box.boxId}', fileName: 'lebo_katoni_${box.boxId}'),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'manifest',
                child: ListTile(leading: const Icon(Icons.list_alt_rounded), title: Text('manifest'.tr), subtitle: Text('manifestSub'.tr)),
              ),
              PopupMenuItem(
                value: 'labels',
                child: ListTile(leading: const Icon(Icons.qr_code_2_rounded), title: Text('qrLabels'.tr), subtitle: Text('qrLabelsSub'.tr)),
              ),
              PopupMenuItem(
                value: 'cartons',
                child: ListTile(leading: const Icon(Icons.layers_outlined), title: Text('qrLabelsCartons'.tr), subtitle: Text('qrLabelsCartonsSub'.tr)),
              ),
            ],
          ),
        if (box.isOpen && can(AppModule.package, AppAction.delete))
          IconButton(
            tooltip: 'deleteBox'.tr,
            onPressed: () async {
              if (await BoxFlows.delete(box)) Get.back();
            },
            icon: Icon(Icons.delete_outline_rounded, color: context.palette.danger),
          ),
      ],
      mainAction: editable && _inside.isNotEmpty
          ? PageAction(
              icon: Icons.local_shipping_outlined,
              label: 'closeAndShip'.tr,
              onPressed: () => BoxFlows.close(box, suggestedWeight: insideWeight),
            )
          : (box.inTransit && can(AppModule.store, AppAction.update))
              ? PageAction(icon: Icons.warehouse_outlined, label: 'receiveBox'.tr, onPressed: () => BoxFlows.receive(box))
              : null,
      body: LayoutBuilder(builder: (context, c) {
        final summary = _BoxSummary(
          box: box,
          insideCount: _inside.length,
          insideWeight: insideWeight,
          insideCbm: _inside.fold<double>(0, (s, p) => s + p.cbm),
        );
        final insideCard = _ProductsPanel(
          title: 'insideBox'.tr,
          icon: Icons.inventory_2_outlined,
          products: _inside,
          emptyText: 'boxEmpty'.tr,
          trailingFor: editable
              ? (p) => IconButton(
                    tooltip: 'removeFromBox'.tr,
                    onPressed: () => _remove(p),
                    icon: Icon(Icons.remove_circle_outline_rounded, color: context.palette.danger),
                  )
              : null,
        );

        final Widget costsCard = AppController.to.can(AppModule.profit)
            ? BoxCostsCard(box: box, key: ValueKey('costs-${box.id}-${_inside.length}'))
            : const SizedBox.shrink();
        if (!editable) {
          return PageScroll(onRefresh: _load, children: [summary, insideCard, costsCard]);
        }

        // Box lenyewe ni eneo la kudondoshea mizigo inayoburutwa.
        final insideTarget = BoxDropTarget(
          box: box,
          onDropped: () => setState(_selected.clear),
          builder: (context, hovering, rejected) =>
              DropHighlight(hovering: hovering, rejected: rejected, child: insideCard),
        );

        final waitingCard = _WaitingPanel(
          products: _waiting,
          box: box,
          otherCarrier: _otherCarrier,
          selected: _selected,
          search: _search,
          busy: _busy,
          onToggle: (id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
          onToggleAll: (ids, value) => setState(() {
            if (value) {
              _selected.addAll(ids);
            } else {
              _selected.removeAll(ids);
            }
          }),
          onSearch: () => setState(() {}),
          onScan: _scanToSelect,
          onAdd: _addSelected,
        );

        if (c.maxWidth >= 1000) {
          return PageScroll(
            onRefresh: _load,
            children: [
              summary,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: waitingCard),
                  const SizedBox(width: 18),
                  Expanded(child: insideTarget),
                ],
              ),
              costsCard,
            ],
          );
        }
        return PageScroll(onRefresh: _load, children: [summary, insideTarget, waitingCard, costsCard]);
      }),
    );
  }
}

class ApiNotFound implements Exception {}

class _BoxSummary extends StatelessWidget {
  final Box box;
  final int insideCount;
  final double insideWeight;
  final double insideCbm;

  const _BoxSummary({required this.box, required this.insideCount, required this.insideWeight, this.insideCbm = 0});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ResponsiveGrid(
      minItemWidth: 190,
      children: [
        StatCard(label: 'items'.tr, value: '$insideCount', icon: Icons.inventory_2_outlined, color: p.primary),
        StatCard(
          label: 'weight'.tr,
          value: Fmt.kg(box.isOpen ? insideWeight : box.weight),
          icon: Icons.scale_outlined,
          color: const Color(0xFFD97706),
          hint: insideCbm > 0 ? '${insideCbm.toStringAsFixed(3)} CBM' : null,
        ),
        StatCard(
          label: 'navInvoices'.tr,
          value: '${box.invoiceIds.length}',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFF7C3AED),
        ),
        StatCard(
          label: box.isOpen ? 'boxType'.tr : 'track'.tr,
          value: box.isOpen ? 'box_${box.packageType}'.tr : box.trackNumber,
          icon: box.isOpen ? Icons.category_outlined : Icons.qr_code_2_rounded,
          color: p.info,
          hint: Fmt.dateTime(box.isOpen ? box.createdAt : (box.updatedAt ?? box.createdAt)),
        ),
        if (!box.isOpen)
          StatCard(
            label: box.arrived ? 'arrivedOn'.tr : 'etaLabel'.tr,
            value: box.arrived ? Fmt.date(box.arrivedAt ?? box.updatedAt) : (box.eta == null ? '—' : Fmt.date(box.eta)),
            icon: box.arrived ? Icons.where_to_vote_outlined : Icons.event_outlined,
            color: box.isLate ? p.danger : (box.arrived ? p.success : const Color(0xFF0891B2)),
            hint: box.isLate
                ? 'lateDaysN'.trParams({'n': '${box.daysLate}'})
                : (box.inTransit && AppController.to.can(AppModule.package, AppAction.update) ? 'etaTapToChange'.tr : null),
            onTap: box.inTransit && AppController.to.can(AppModule.package, AppAction.update)
                ? () => BoxFlows.changeEta(box)
                : null,
          ),
      ],
    );
  }
}

class _ProductsPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<BoxProduct> products;
  final String emptyText;
  final Widget Function(BoxProduct p)? trailingFor;

  const _ProductsPanel({
    required this.title,
    required this.icon,
    required this.products,
    required this.emptyText,
    this.trailingFor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: title,
      subtitle: '${products.length} ${'items'.tr}',
      icon: icon,
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
      child: products.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text(emptyText, style: TextStyle(color: p.muted))),
            )
          : Column(
              children: [
                for (int i = 0; i < products.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  BoxProductRow(product: products[i], trailing: trailingFor?.call(products[i])),
                ],
              ],
            ),
    );
  }
}

class BoxProductRow extends StatelessWidget {
  final BoxProduct product;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const BoxProductRow({super.key, required this.product, this.leading, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            if (leading != null) leading!,
            ProductThumb(product.path, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  Text(
                    [
                      '#${product.invoiceNumber ?? '-'}',
                      product.customerName ?? '',
                      Fmt.kg(product.weight),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                  if ((product.trackNumber ?? '').isNotEmpty)
                    Text('${'track'.tr}: ${product.trackNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ),
            ),
            if (product.invoiceId != null)
              IconButton(
                tooltip: 'openInvoice'.tr,
                onPressed: () => InvoiceFlows.open(product.invoiceId!),
                icon: Icon(Icons.open_in_new_rounded, size: 18, color: p.muted),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  final List<BoxProduct> products;
  final Set<String> selected;
  final TextEditingController search;
  final bool busy;
  final ValueChanged<String> onToggle;
  final void Function(List<String> ids, bool value) onToggleAll;
  final VoidCallback onSearch;
  final VoidCallback onScan;
  final VoidCallback onAdd;
  final Box box;
  final int otherCarrier;

  const _WaitingPanel({
    required this.products,
    required this.box,
    required this.otherCarrier,
    required this.selected,
    required this.search,
    required this.busy,
    required this.onToggle,
    required this.onToggleAll,
    required this.onSearch,
    required this.onScan,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = search.text.trim().toLowerCase();
    final list = q.isEmpty
        ? products
        : products
            .where((e) =>
                e.description.toLowerCase().contains(q) ||
                (e.trackNumber ?? '').toLowerCase().contains(q) ||
                (e.customerName ?? '').toLowerCase().contains(q) ||
                (e.invoiceNumber ?? '').contains(q))
            .toList();
    final ids = list.map((e) => e.id).toList();
    final bool allSelected = ids.isNotEmpty && ids.every(selected.contains);
    final double selectedWeight =
        products.where((e) => selected.contains(e.id)).fold<double>(0, (s, e) => s + e.weight);

    return SectionCard(
      title: 'waitingForPacking'.tr,
      subtitle: '${products.length} ${'items'.tr} · ${(box.carrier == null ? 'allCarriers' : 'box_${box.carrier}').tr}',
      icon: Icons.move_to_inbox_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      trailing: IconButton(tooltip: 'scanProduct'.tr, onPressed: onScan, icon: const Icon(Icons.qr_code_scanner_rounded)),
      child: products.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Text('nothingWaiting'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                  const SizedBox(height: 6),
                  Text('nothingWaitingMsg'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  if (otherCarrier > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'otherCarrierWaiting'.trParams({'n': '$otherCarrier'}),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.warning, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Get.back();
                      if (Get.isRegistered<InvoicesController>()) {
                        Get.find<InvoicesController>().setFilter(InvoiceStatus.open);
                      }
                      ShellController.to.go(NavSection.invoices);
                    },
                    icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
                    label: Text('invoicesNeedReceiver'.tr),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: search,
                  onChanged: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'searchProductHint'.tr,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.pan_tool_alt_outlined, size: 16, color: p.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isMobileDevice ? 'dragHintMobile'.tr : 'dragHint'.tr,
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: allSelected,
                  onChanged: (v) => onToggleAll(ids, v ?? false),
                  title: Text('selectAll'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                Divider(height: 1, color: p.border),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
                    itemBuilder: (context, i) {
                      final item = list[i];
                      return DraggableCargo(
                        product: item,
                        group: products.where((e) => selected.contains(e.id)).toList(),
                        child: Material(
                          color: Colors.transparent,
                          child: BoxProductRow(
                            product: item,
                            onTap: () => onToggle(item.id),
                            leading: Checkbox(value: selected.contains(item.id), onChanged: (_) => onToggle(item.id)),
                            trailing: Icon(Icons.drag_indicator_rounded, color: p.muted, size: 20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: selected.isEmpty || busy ? null : onAdd,
                  icon: busy ? const ButtonSpinner() : const Icon(Icons.input_rounded, size: 20),
                  label: Text(
                    selected.isEmpty
                        ? 'selectToPack'.tr
                        : 'addNToBox'.trParams({'n': '${selected.length}', 'kg': Fmt.number(selectedWeight)}),
                  ),
                ),
              ],
            ),
    );
  }
}
