import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/lookups.dart';
import '../../data/models/invoice.dart';
import '../../data/models/user.dart';
import '../dashboard/dashboard_controller.dart';
import 'invoice_flows.dart';
import 'invoice_tiles.dart';
import 'invoices_controller.dart';
import 'photo_qr.dart';

class InvoicesPage extends GetView<InvoicesController> {
  const InvoicesPage({super.key});

  Future<void> _scan() async {
    final code = await scanCode(title: 'findByTrack'.tr);
    if (code == null) return;
    controller.search.text = code;
    controller.onSearch(code);
  }

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    final DashboardController? dash = Get.isRegistered<DashboardController>() ? Get.find<DashboardController>() : null;

    return AppPage(
      help: 'invoices',
      title: 'navInvoices'.tr,
      subtitle: 'hintInvoices'.tr,
      actions: [
        IconButton(tooltip: 'scanCode'.tr, onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded)),
        // simu: skani QR ya mzigo (skrini ya web au lebo) na upige picha yake
        if (isMobileDevice && (can(AppModule.product, AppAction.update) || can(AppModule.product, AppAction.insert)))
          IconButton(tooltip: 'photoByQr'.tr, onPressed: photoByQr, icon: const Icon(Icons.add_a_photo_outlined)),
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: can(AppModule.invoice, AppAction.insert)
          ? PageAction(icon: Icons.note_add_outlined, label: 'newInvoice'.tr, onPressed: () => InvoiceFlows.newInvoice())
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchInvoiceHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() {
              final counts = dash?.summary.value.invoices ?? const <String, int>{};
              final chips = FilterChips<InvoiceStatus?>(
                values: InvoicesController.filters,
                selected: controller.filter.value,
                label: (s) => s == null ? 'all'.tr : StatusStyle.of(s).label,
                count: (s) => s == null ? null : counts[s.code],
                onSelected: controller.setFilter,
              );
              final offices = Lookups.to.offices;
              final me = AppController.to.user.value;
              if (offices.isEmpty || (me?.officeOnly ?? false)) return chips;
              String? officeName;
              for (final o in offices) {
                if (o.id == controller.officeId.value) officeName = o.name;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  chips,
                  const SizedBox(height: 8),
                  PopupMenuButton<String?>(
                    tooltip: 'office'.tr,
                    onSelected: controller.setOffice,
                    itemBuilder: (context) => [
                      PopupMenuItem<String?>(value: null, child: Text('allOffices'.tr)),
                      for (final o in offices) PopupMenuItem<String?>(value: o.id, child: Text(o.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
                      label: Text(officeName ?? 'allOffices'.tr),
                    ),
                  ),
                ],
              );
            }),
          ),
          if (can(AppModule.invoice, AppAction.delete))
            Obx(() {
              if (controller.filter.value != InvoiceStatus.blocked || controller.items.isEmpty) {
                return const SizedBox.shrink();
              }
              return _BlockedBanner(
                count: controller.hasMore.value ? '${controller.items.length}+' : '${controller.items.length}',
                onDelete: controller.deleteAllBlocked,
              );
            }),
          Expanded(
            child: Obx(() {
              final list = controller.visible;
              final more = controller.hasMore.value;
              final busyMore = controller.loadingMore.value;
              return AsyncBody(
                status: controller.status.value,
                error: controller.error.value,
                isEmpty: list.isEmpty,
                onRetry: controller.load,
                empty: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: controller.query.value.isEmpty ? 'noInvoices'.tr : 'noMatch'.tr,
                  message: controller.query.value.isEmpty ? 'noInvoicesMsg'.tr : null,
                ),
                builder: () => DataList<Invoice>(
                  items: list,
                  onRefresh: controller.refreshList,
                  footer: more ? LoadMoreButton(busy: busyMore, onPressed: controller.loadMore, shown: list.length) : null,
                  onTap: (i) => InvoiceFlows.open(i.id),
                  columns: [
                    ColumnSpec('invoice'.tr, flex: 2),
                    ColumnSpec('customer'.tr, flex: 3),
                    ColumnSpec('cargo'.tr, flex: 2),
                    ColumnSpec('receiver'.tr, flex: 3),
                    ColumnSpec('total'.tr, flex: 2, align: TextAlign.end),
                    ColumnSpec('status'.tr, flex: 2, align: TextAlign.end),
                  ],
                  cells: (context, i) => [
                    CellText(i.number, sub: Fmt.date(i.createdAt), bold: true),
                    CellText(i.customer?.name ?? '—', sub: Fmt.phone(i.customer?.phoneNumber)),
                    CellText('${i.products.length} ${'items'.tr}', sub: Fmt.kg(i.totalWeight)),
                    CellText(i.receiver?.name ?? '—', sub: i.receiver?.trackNumber),
                    CellText(
                      Fmt.money(i.total),
                      bold: true,
                      align: TextAlign.end,
                      sub: i.debt != null && !i.debt!.isPaid ? '${'due'.tr} ${Fmt.money(i.debt!.balance)}' : null,
                    ),
                    StatusChip(i.status, dense: true),
                  ],
                  card: (context, i) => InvoiceCard(invoice: i),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Inaonekana kwenye kichujio cha "Zimezuiwa": kufuta zote kwa mara moja.
class _BlockedBanner extends StatelessWidget {
  final String count;
  final VoidCallback onDelete;

  const _BlockedBanner({required this.count, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: p.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.danger.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(Icons.block_rounded, color: p.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('blockedCount'.trParams({'n': count}), style: TextStyle(color: p.danger)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text('deleteAllBlocked'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
