import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/box.dart';
import '../../data/models/user.dart';
import 'box_drag.dart';
import 'box_flows.dart';
import 'boxes_controller.dart';

class BoxesPage extends GetView<BoxesController> {
  const BoxesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    return AppPage(
      help: 'boxes',
      title: 'navBoxes'.tr,
      subtitle: 'hintBoxes'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: can(AppModule.package, AppAction.insert)
          ? PageAction(icon: Icons.add_box_outlined, label: 'newBox'.tr, onPressed: BoxFlows.newBox)
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchBoxHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() => FilterChips<BoxFilter>(
                  values: BoxFilter.values,
                  selected: controller.filter.value,
                  label: (f) => switch (f) {
                    BoxFilter.open => 'boxesPacking'.tr,
                    BoxFilter.transit => 'boxesInTransit'.tr,
                    BoxFilter.arrived => 'boxesArrived'.tr,
                  },
                  count: controller.countFor,
                  onSelected: (f) => controller.filter.value = f,
                )),
          ),
          Expanded(
            child: Obx(() {
              final packing = controller.filter.value == BoxFilter.open;
              final waiting = controller.waitingItems.toList();
              final grid = _gridArea();
              if (!packing || waiting.isEmpty) return grid;
              return LayoutBuilder(builder: (context, c) {
                if (c.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 4, 0, 24),
                        child: SizedBox(width: 340, child: _WaitingPanel(items: waiting)),
                      ),
                      Expanded(child: grid),
                    ],
                  );
                }
                return Column(
                  children: [
                    _WaitingStrip(items: waiting),
                    Expanded(child: grid),
                  ],
                );
              });
            }),
          ),
        ],
      ),
    );
  }

  Widget _gridArea() {
    return Obx(() {
              final list = controller.visible;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'noBoxes'.tr,
                  message: controller.filter.value == BoxFilter.open ? 'noBoxesMsg'.tr : null,
                  action: controller.filter.value == BoxFilter.open &&
                          AppController.to.can(AppModule.package, AppAction.insert)
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () => BoxFlows.newBox(carrier: 'AIR'),
                              icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                              label: Text('newAirBox'.tr),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => BoxFlows.newBox(carrier: 'SEA'),
                              icon: const Icon(Icons.directions_boat_outlined, size: 18),
                              label: Text('newContainer'.tr),
                            ),
                          ],
                        )
                      : null,
                ),
                builder: () => _BoxGrid(boxes: list, onRefresh: controller.refreshList),
              );
            });
  }
}

class _BoxGrid extends StatelessWidget {
  final List<Box> boxes;
  final Future<void> Function() onRefresh;

  const _BoxGrid({required this.boxes, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final double h = context.isMediumUp ? 28 : 16;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(builder: (context, c) {
        final double width = c.maxWidth.clamp(0, kContentMaxWidth).toDouble() - h * 2;
        final int columns = (width / 300).floor().clamp(1, 8).toInt();
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(h, 4, h, 96),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 176,
              ),
              itemCount: boxes.length,
              itemBuilder: (context, i) => BoxDropTarget(
                box: boxes[i],
                builder: (context, hovering, rejected) => DropHighlight(
                  hovering: hovering,
                  rejected: rejected,
                  child: BoxCard(box: boxes[i]),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class BoxCard extends StatelessWidget {
  final Box box;

  const BoxCard({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color color, String label, IconData icon) = box.isOpen
        ? (const Color(0xFFD97706), 'packing'.tr, BoxFlows.iconFor(box))
        : box.inTransit
            ? (const Color(0xFF0284C7), 'inTransit'.tr, Icons.local_shipping_outlined)
            : (p.success, 'arrived'.tr, Icons.warehouse_outlined);

    return Card(
      child: InkWell(
        onTap: () => BoxFlows.open(box),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(box.boxId, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.text, letterSpacing: .5)),
                        Text(
                          [
                            'box_${box.packageType}'.tr,
                            if (box.inTransit && box.eta != null) 'etaShort'.trParams({'d': Fmt.date(box.eta)}),
                          ].join(' · '),
                          style: TextStyle(color: p.muted, fontSize: 12.5),
                        ),
                        if (box.isLate)
                          Text('lateDaysN'.trParams({'n': '${box.daysLate}'}),
                              style: TextStyle(color: p.danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Pill(label, color: color, dense: true),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _metric(p, Icons.inventory_2_outlined, '${box.productCount}', 'items'.tr),
                  _metric(p, Icons.scale_outlined, Fmt.number(box.weight), 'kg'),
                  _metric(p, Icons.receipt_long_outlined, '${box.invoiceIds.length}', 'invoicesShort'.tr),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                box.isOpen
                    ? '${'created'.tr}: ${Fmt.relative(box.createdAt)}'
                    : '${'track'.tr}: ${box.trackNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(AppPalette p, IconData icon, String value, String unit) => Expanded(
        child: Row(
          children: [
            Icon(icon, size: 16, color: p.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                  children: [TextSpan(text: ' $unit', style: TextStyle(color: p.muted, fontWeight: FontWeight.w500, fontSize: 12))],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

/// Mizigo inayosubiri kupakiwa (kompyuta/web): iburute kwenda kwenye box upande wa kulia.
class _WaitingPanel extends StatelessWidget {
  final List<BoxProduct> items;

  const _WaitingPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final double kg = items.fold<double>(0, (s, e) => s + e.weight);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: p.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.move_to_inbox_outlined, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('waitingForPacking'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                    ),
                    Pill('${items.length}', color: const Color(0xFFD97706), dense: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${Fmt.kg(kg)} · ${'dragToBoxHint'.tr}', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
              itemBuilder: (context, i) => DraggableCargo(
                product: items[i],
                child: Material(
                  color: Colors.transparent,
                  child: _CargoTile(product: items[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simu: mstari wa mizigo juu ya mabox - bonyeza kwa muda kisha uburute kwenda kwenye box.
class _WaitingStrip extends StatelessWidget {
  final List<BoxProduct> items;

  const _WaitingStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            '${'waitingForPacking'.tr} (${items.length}) · ${'dragHintMobile'.tr}',
            style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => DraggableCargo(
              product: items[i],
              child: Container(
                width: 230,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: _CargoTile(product: items[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _CargoTile extends StatelessWidget {
  final BoxProduct product;

  const _CargoTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sea = product.carrierType.toUpperCase() == 'SEA';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Row(
        children: [
          ProductThumb(product.path, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 13.5),
                ),
                Text(
                  '#${product.invoiceNumber ?? '-'} · ${product.customerName ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
                Row(
                  children: [
                    Icon(sea ? Icons.directions_boat_outlined : Icons.flight_rounded, size: 13, color: p.muted),
                    const SizedBox(width: 4),
                    Text(Fmt.kg(product.weight), style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator_rounded, color: p.muted, size: 20),
        ],
      ),
    );
  }
}
