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
import '../../data/models/box.dart';
import '../../data/models/user.dart';
import '../boxes/box_flows.dart';
import 'overdue_page.dart';
import 'store_controller.dart';

class StorePage extends GetView<StoreController> {
  const StorePage({super.key});

  /// Kuskani track number ya box lililofika na kulipokea.
  Future<void> _scanReceive() async {
    final code = await scanCode(title: 'scanBoxTrack'.tr);
    if (code == null) return;
    final q = code.toLowerCase();
    Box? found;
    for (final b in controller.items) {
      if (b.trackNumber.toLowerCase() == q || b.boxId.toLowerCase() == q) found = b;
    }
    if (found == null) {
      Toast.warning('boxNotFoundMsg'.trParams({'code': code}), title: 'notFound'.tr);
      return;
    }
    if (found.arrived) {
      Toast.info('boxAlreadyArrived'.tr, title: 'Box ${found.boxId}');
      return;
    }
    await BoxFlows.receive(found);
  }

  @override
  Widget build(BuildContext context) {
    final canReceive = AppController.to.can(AppModule.store, AppAction.update);
    return AppPage(
      title: 'navStore'.tr,
      subtitle: 'hintStore'.tr,
      help: 'store',
      actions: [
        Obx(() {
          final n = controller.overdue.value;
          return IconButton(
            tooltip: 'overdueTitle'.tr,
            onPressed: () async {
              await OverduePage.open();
              controller.loadOverdue();
            },
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              backgroundColor: context.palette.warning,
              child: const Icon(Icons.hourglass_bottom_rounded),
            ),
          );
        }),
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: canReceive
          ? PageAction(icon: Icons.qr_code_scanner_rounded, label: 'scanToReceive'.tr, onPressed: _scanReceive)
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchBoxHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() => FilterChips<StoreFilter>(
                  values: StoreFilter.values,
                  selected: controller.filter.value,
                  label: (f) => f == StoreFilter.expected ? 'expectedBoxes'.tr : 'boxesArrived'.tr,
                  count: controller.countFor,
                  onSelected: (f) => controller.filter.value = f,
                )),
          ),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              final expected = controller.filter.value == StoreFilter.expected;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.warehouse_outlined,
                  title: expected ? 'noExpectedBoxes'.tr : 'noArrivedBoxes'.tr,
                  message: expected ? 'noExpectedBoxesMsg'.tr : null,
                ),
                builder: () => DataList<Box>(
                  items: list,
                  onRefresh: controller.refreshList,
                  onTap: BoxFlows.open,
                  columns: [
                    ColumnSpec('box'.tr, flex: 2),
                    ColumnSpec('track'.tr, flex: 3),
                    ColumnSpec('cargo'.tr, flex: 2),
                    ColumnSpec(expected ? 'shipped'.tr : 'arrivedOn'.tr, flex: 2),
                    ColumnSpec('', flex: 2, align: TextAlign.end),
                  ],
                  cells: (context, b) => [
                    CellText(b.boxId, sub: 'box_${b.packageType}'.tr, bold: true),
                    CellText(b.trackNumber),
                    CellText('${b.productCount} ${'items'.tr}', sub: '${Fmt.kg(b.weight)} · ${b.invoiceIds.length} ${'invoicesShort'.tr}'),
                    CellText(
                      Fmt.date(b.arrived ? (b.arrivedAt ?? b.updatedAt ?? b.createdAt) : (b.shippedAt ?? b.updatedAt ?? b.createdAt)),
                      sub: b.isLate
                          ? 'lateDaysN'.trParams({'n': '${b.daysLate}'})
                          : (b.inTransit && b.eta != null ? 'etaShort'.trParams({'d': Fmt.date(b.eta)}) : null),
                      color: b.isLate ? context.palette.danger : null,
                    ),
                    _action(context, b, canReceive),
                  ],
                  card: (context, b) => Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (b.arrived ? context.palette.success : const Color(0xFF0284C7)).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            b.arrived ? Icons.warehouse_outlined : Icons.local_shipping_outlined,
                            color: b.arrived ? context.palette.success : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Box ${b.boxId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              Text('${'track'.tr}: ${b.trackNumber}', style: TextStyle(color: context.palette.muted, fontSize: 13)),
                              Text(
                                '${b.productCount} ${'items'.tr} · ${Fmt.kg(b.weight)}',
                                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                              ),
                              if (b.inTransit && b.eta != null)
                                Text(
                                  b.isLate
                                      ? 'lateDaysN'.trParams({'n': '${b.daysLate}'})
                                      : 'etaShort'.trParams({'d': Fmt.date(b.eta)}),
                                  style: TextStyle(
                                    color: b.isLate ? context.palette.danger : context.palette.muted,
                                    fontSize: 12.5,
                                    fontWeight: b.isLate ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _action(context, b, canReceive),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, Box b, bool canReceive) {
    if (b.arrived) return Pill('arrived'.tr, color: context.palette.success, icon: Icons.check_rounded, dense: true);
    if (!canReceive) return Pill('inTransit'.tr, color: const Color(0xFF0284C7), dense: true);
    return FilledButton.tonal(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
      onPressed: () => BoxFlows.receive(b),
      child: Text('receive'.tr),
    );
  }
}
