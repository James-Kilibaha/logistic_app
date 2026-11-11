import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/activity_tracker.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/help.dart';
import '../../core/widgets/layout.dart';
import '../accounting/accounting_page.dart';
import '../activity/my_activity_page.dart';
import '../audit/audit_page.dart';
import '../boxes/boxes_controller.dart';
import '../boxes/boxes_page.dart';
import '../payroll/payroll_page.dart';
import '../cashup/cashup_page.dart';
import '../claims/claims_page.dart';
import '../company/subscription_banner.dart';
import '../company/view_as_banner.dart';
import '../customers/customers_controller.dart';
import '../customers/customers_page.dart';
import '../dashboard/dashboard_controller.dart';
import '../demands/demands.dart';
import '../dashboard/dashboard_page.dart';
import '../delivery/delivery_controller.dart';
import '../delivery/delivery_page.dart';
import '../expenses/expenses_controller.dart';
import '../expenses/expenses_page.dart';
import '../invoices/invoices_controller.dart';
import '../invoices/invoices_page.dart';
import '../notifications/notifications.dart';
import '../popup/popup_alerts.dart';
import '../quotations/quotations_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../sms/sms_controller.dart';
import '../sms/sms_page.dart';
import '../store/store_controller.dart';
import '../store/store_page.dart';
import '../support/my_devices_page.dart';
import '../support/support_page.dart';
import 'nav.dart';
import '../users/users_controller.dart';
import '../users/users_page.dart';
import '../whatsapp/whatsapp_inbox_page.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ShellController());
    Get.put(NotificationsController());
    Get.put(PopupAlertsController());
    Get.put(DemandGuardController()); // madai ya gharama: kukumbusha na kuzuia kazi
    AppPage.globalAction = () => const NotificationBell();
    Get.lazyPut(() => DashboardController(), fenix: true);
    Get.lazyPut(() => CustomersController(), fenix: true);
    Get.lazyPut(() => InvoicesController(), fenix: true);
    Get.lazyPut(() => BoxesController(), fenix: true);
    Get.lazyPut(() => StoreController(), fenix: true);
    Get.lazyPut(() => DeliveryController(), fenix: true);
    Get.lazyPut(() => ExpensesController(), fenix: true);
    Get.lazyPut(() => SmsController(), fenix: true);
    Get.lazyPut(() => UsersController(), fenix: true);
  }
}

class ShellController extends GetxController {
  static ShellController get to => Get.find<ShellController>();

  final Rx<NavSection> current = NavSection.dashboard.obs;

  void go(NavSection section) {
    final item = section == NavSection.more ? null : navItemFor(section);
    if (item != null && !item.allowed) {
      Toast.warning('noPermissionMsg'.tr, title: 'noPermission'.tr);
      return;
    }
    current.value = section;
    // super admin anaona kurasa ambazo watumiaji wanafungua
    ActivityTracker.page(section.name, title: item?.labelKey.tr ?? section.name);
  }

  @override
  void onReady() {
    super.onReady();
    ActivityTracker.reset();
    final first = current.value;
    ActivityTracker.page(first.name, title: first == NavSection.more ? null : navItemFor(first).labelKey.tr);
    AppController.to.refreshPermissions();
    BrandingController.to.refreshCompany(); // branding mpya + hali ya subscription + moduli za mpango
  }
}

Widget _pageFor(NavSection section) => switch (section) {
      NavSection.dashboard => const DashboardPage(),
      NavSection.myActivity => const MyActivityPage(),
      NavSection.customers => const CustomersPage(),
      NavSection.invoices => const InvoicesPage(),
      NavSection.quotations => const QuotationsPage(),
      NavSection.boxes => const BoxesPage(),
      NavSection.store => const StorePage(),
      NavSection.delivery => const DeliveryPage(),
      NavSection.claims => const ClaimsPage(),
      NavSection.whatsapp => const WhatsappInboxPage(),
      NavSection.expenses => const ExpensesPage(),
      NavSection.accounting => const AccountingPage(),
      NavSection.payroll => const PayrollPage(),
      NavSection.cashup => const CashUpPage(),
      NavSection.reports => const ReportsPage(),
      NavSection.sms => const SmsPage(),
      NavSection.users => const UsersPage(),
      NavSection.audit => const AuditPage(),
      NavSection.settings => const SettingsPage(),
      NavSection.more => const MorePage(),
    };

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = ShellController.to;
    final double width = context.screenWidth;
    final bool phone = width < Breakpoints.medium;
    final bool compact = !phone && width < Breakpoints.wide;

    return Obx(() {
      final section = shell.current.value;
      // Kusoma ruhusa (na mpango wa subscription) hapa ili menyu ijijenge upya zikibadilika.
      AppController.to.permissions.length;
      BrandingController.to.subscription.value;

      final page = Column(
        children: [
          const ViewAsBanner(),
          const SubscriptionBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(key: ValueKey(section), child: _pageFor(section)),
            ),
          ),
        ],
      );

      return PopScope(
        canPop: section == NavSection.dashboard,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shell.go(NavSection.dashboard);
        },
        child: phone
            ? Scaffold(
                body: page,
                bottomNavigationBar: _BottomBar(current: section),
              )
            : Scaffold(
                body: Row(
                  children: [
                    _Sidebar(current: section, compact: compact),
                    Expanded(child: page),
                  ],
                ),
              ),
      );
    });
  }
}

// ----------------------------------------------------------------- simu

class _BottomBar extends StatelessWidget {
  final NavSection current;

  const _BottomBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final primary = mobilePrimary.map(navItemFor).where((i) => i.allowed).toList();
    final sections = [...primary.map((i) => i.section), NavSection.more];
    int index = sections.indexOf(current);
    if (index < 0) index = sections.length - 1; // ukurasa uliofunguliwa kutoka "Zaidi"

    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.border))),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ShellController.to.go(sections[i]),
        destinations: [
          for (final item in primary)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: _short(item.labelKey.tr),
            ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: 'navMore'.tr,
          ),
        ],
      ),
    );
  }

  String _short(String label) => label.length > 12 ? '${label.substring(0, 11)}…' : label;
}

/// Ukurasa wa "Zaidi" (simu): sehemu zote ambazo hazimo kwenye menyu ya chini.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = navItems.where((i) => !mobilePrimary.contains(i.section) && i.allowed).toList();
    final user = AppController.to.user.value;

    return AppPage(
      title: 'navMore'.tr,
      body: PageScroll(
        children: [
          if (user != null)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Initials(user.initials, size: 46),
                title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('@${user.username}'),
                trailing: IconButton(
                  tooltip: 'logout'.tr,
                  onPressed: () => _confirmLogout(),
                  icon: Icon(Icons.logout_rounded, color: p.danger),
                ),
              ),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: Text('tkTitle'.tr),
                  subtitle: Text('tkSub'.tr),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: SupportPage.open,
                ),
                ListTile(
                  leading: const Icon(Icons.devices_rounded),
                  title: Text('devTitle'.tr),
                  subtitle: Text('devSub'.tr),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: MyDevicesPage.open,
                ),
              ],
            ),
          ),
          for (final group in NavGroup.values)
            if (items.any((i) => i.group == group))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      groupLabelKey(group).tr.toUpperCase(),
                      style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .8),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final item in items.where((i) => i.group == group))
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(10)),
                              child: Icon(item.icon, color: p.primary, size: 20),
                            ),
                            title: Text(item.labelKey.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(item.hintKey.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => ShellController.to.go(item.section),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book_outlined, color: p.primary, size: 20),
              ),
              title: Text('helpCenter'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('helpCenterSub'.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Get.to(() => const HelpCenterPage()),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmLogout() async {
  final ok = await confirmAction(
    title: 'logout'.tr,
    message: 'logoutConfirm'.tr,
    confirmText: 'logout'.tr,
    icon: Icons.logout_rounded,
    danger: true,
  );
  if (ok) await AppController.to.logout();
}

// ------------------------------------------------------------- kompyuta

class _Sidebar extends StatelessWidget {
  final NavSection current;
  final bool compact;

  const _Sidebar({required this.current, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = navItems.where((i) => i.allowed).toList();

    return Container(
      width: compact ? 78 : 252,
      decoration: BoxDecoration(color: p.surface, border: Border(right: BorderSide(color: p.border))),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------------------------------------------------- nembo
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 0 : 20, 20, compact ? 0 : 16, 14),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const BrandLogo(size: 40),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Obx(() {
                        final brand = BrandingController.to.current.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(brand.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text)),
                            Text(brand.platform.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
            // ---------------------------------------------------- menyu
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 4),
                children: [
                  for (final group in NavGroup.values)
                    if (items.any((i) => i.group == group)) ...[
                      if (group != NavGroup.main)
                        compact
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: p.border),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                                child: Text(
                                  groupLabelKey(group).tr.toUpperCase(),
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .9,
                                  ),
                                ),
                              ),
                      for (final item in items.where((i) => i.group == group))
                        _SideItem(item: item, selected: item.section == current, compact: compact),
                    ],
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            _UserTile(compact: compact),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool compact;

  const _SideItem({required this.item, required this.selected, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color fg = selected ? p.primary : p.text.withValues(alpha: .78);

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? p.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => ShellController.to.go(item.section),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12, vertical: 10),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(selected ? item.selectedIcon : item.icon, color: selected ? p.primary : p.muted, size: 22),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.labelKey.tr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: item.labelKey.tr, preferBelow: false, child: tile) : tile;
  }
}

class _UserTile extends StatelessWidget {
  final bool compact;

  const _UserTile({required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final user = AppController.to.user.value;
      final dark = AppController.to.themeMode.value == ThemeMode.dark;
      final initials = user?.initials ?? '?';

      return PopupMenuButton<String>(
        tooltip: 'account'.tr,
        position: PopupMenuPosition.over,
        offset: const Offset(0, -260),
        onSelected: (value) {
          switch (value) {
            case 'theme':
              AppController.to.setTheme(dark ? ThemeMode.light : ThemeMode.dark);
            case 'settings':
              ShellController.to.go(NavSection.settings);
            case 'support':
              SupportPage.open();
            case 'devices':
              MyDevicesPage.open();
            case 'logout':
              _confirmLogout();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'theme',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              title: Text(dark ? 'lightMode'.tr : 'darkMode'.tr),
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text('navSettings'.tr),
            ),
          ),
          PopupMenuItem(
            value: 'support',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent_rounded),
              title: Text('tkTitle'.tr),
            ),
          ),
          PopupMenuItem(
            value: 'devices',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_rounded),
              title: Text('devTitle'.tr),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'logout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: p.danger),
              title: Text('logout'.tr, style: TextStyle(color: p.danger)),
            ),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16, vertical: 14),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Initials(initials, size: 38),
              if (!compact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 14),
                      ),
                      Text(
                        '@${user?.username ?? ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more_rounded, color: p.muted, size: 20),
              ],
            ],
          ),
        ),
      );
    });
  }
}
