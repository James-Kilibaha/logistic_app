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
import '../../data/models/customer.dart';
import '../../data/models/user.dart';
import '../invoices/invoice_flows.dart';
import 'customer_flows.dart';
import 'customers_controller.dart';

class CustomersPage extends GetView<CustomersController> {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    return AppPage(
      help: 'customers',
      title: 'navCustomers'.tr,
      subtitle: 'hintCustomers'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: controller.load, icon: const Icon(Icons.refresh_rounded)),
      ],
      mainAction: can(AppModule.customer, AppAction.insert)
          ? PageAction(icon: Icons.person_add_alt_1_rounded, label: 'newCustomer'.tr, onPressed: () => CustomerFlows.edit())
          : null,
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(controller: controller.search, hint: 'searchCustomerHint'.tr, onChanged: controller.onSearch),
            filters: Obx(() => FilterChips<CustomerFilter>(
                  values: CustomerFilter.values,
                  selected: controller.filter.value,
                  label: (f) => switch (f) {
                    CustomerFilter.all => 'all'.tr,
                    CustomerFilter.active => 'active'.tr,
                    CustomerFilter.blocked => 'blocked'.tr,
                  },
                  count: controller.countFor,
                  onSelected: controller.setFilter,
                )),
          ),
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
                  icon: Icons.people_alt_outlined,
                  title: controller.query.value.isEmpty ? 'noCustomers'.tr : 'noMatch'.tr,
                  message: controller.query.value.isEmpty ? 'noCustomersMsg'.tr : null,
                ),
                builder: () => DataList<Customer>(
                  items: list,
                  onRefresh: controller.refreshList,
                  footer: more ? LoadMoreButton(busy: busyMore, onPressed: controller.loadMore, shown: list.length) : null,
                  onTap: CustomerFlows.open,
                  columns: [
                    ColumnSpec('customer'.tr, flex: 4),
                    ColumnSpec('phone'.tr, flex: 3),
                    ColumnSpec('registered'.tr, flex: 2),
                    ColumnSpec('status'.tr, flex: 2),
                  ],
                  cells: (context, c) => [
                    Row(
                      children: [
                        Initials(c.initials, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: CellText(c.name, bold: true)),
                      ],
                    ),
                    CellText(Fmt.phone(c.phoneNumber)),
                    CellText(Fmt.date(c.createdAt)),
                    _StatusPill(c),
                  ],
                  actions: (context, c) => CustomerMenu(customer: c),
                  card: (context, c) => Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Row(
                      children: [
                        Initials(c.initials, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              const SizedBox(height: 2),
                              Text(Fmt.phone(c.phoneNumber), style: TextStyle(color: context.palette.muted)),
                              if (!c.isActive) ...[const SizedBox(height: 6), _StatusPill(c)],
                            ],
                          ),
                        ),
                        CustomerMenu(customer: c),
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
}

class _StatusPill extends StatelessWidget {
  final Customer c;

  const _StatusPill(this.c);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return c.isActive
        ? Pill('active'.tr, color: p.success, dense: true)
        : Pill('blocked'.tr, color: p.danger, icon: Icons.block_rounded, dense: true);
  }
}

/// Menyu ya vitendo vya mteja (inatumika kwenye orodha na kwenye ukurasa wa mteja).
class CustomerMenu extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onChanged;

  const CustomerMenu({super.key, required this.customer, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final can = AppController.to.can;
    final p = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'actions'.tr,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) async {
        switch (v) {
          case 'invoice':
            await InvoiceFlows.newInvoice(customer: customer);
          case 'call':
            await callPhone(customer.phoneNumber);
          case 'edit':
            if (await CustomerFlows.edit(customer: customer) != null) onChanged?.call();
          case 'block':
            if (await CustomerFlows.toggleBlock(customer)) onChanged?.call();
          case 'delete':
            if (await CustomerFlows.delete(customer)) onChanged?.call();
        }
      },
      itemBuilder: (context) => [
        if (customer.isActive && can(AppModule.invoice, AppAction.insert))
          _item('invoice', Icons.note_add_outlined, 'newInvoice'.tr),
        _item('call', Icons.call_outlined, 'call'.tr),
        if (can(AppModule.customer, AppAction.update)) _item('edit', Icons.edit_outlined, 'edit'.tr),
        if (can(AppModule.customer, AppAction.block))
          _item(
            'block',
            customer.isActive ? Icons.block_rounded : Icons.lock_open_rounded,
            customer.isActive ? 'block'.tr : 'unblock'.tr,
          ),
        if (can(AppModule.customer, AppAction.delete)) ...[
          const PopupMenuDivider(),
          _item('delete', Icons.delete_outline_rounded, 'delete'.tr, color: p.danger),
        ],
      ],
    );
  }
}

PopupMenuItem<String> _item(String value, IconData icon, String label, {Color? color}) => PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
