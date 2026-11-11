import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../data/models/user.dart';

/// Sehemu kuu za app (menyu).
enum NavSection {
  dashboard,
  myActivity,
  customers,
  invoices,
  quotations,
  boxes,
  store,
  delivery,
  claims,
  whatsapp,
  expenses,
  accounting,
  payroll,
  cashup,
  reports,
  sms,
  users,
  audit,
  settings,
  more,
}

enum NavGroup { main, operations, finance, admin }

class NavItem {
  final NavSection section;
  final NavGroup group;
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final String hintKey;

  /// Moduli inayohitaji ruhusa ya kuona (`null` = kila mtu).
  final AppModule? module;

  const NavItem({
    required this.section,
    required this.group,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    required this.hintKey,
    this.module,
  });

  bool get allowed => module == null || AppController.to.can(module!);
}

const List<NavItem> navItems = [
  NavItem(
    section: NavSection.dashboard,
    group: NavGroup.main,
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    labelKey: 'navDashboard',
    hintKey: 'hintDashboard',
  ),
  NavItem(
    section: NavSection.myActivity,
    group: NavGroup.main,
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    labelKey: 'navMyActivity',
    hintKey: 'hintMyActivity',
  ),
  NavItem(
    section: NavSection.customers,
    group: NavGroup.operations,
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
    labelKey: 'navCustomers',
    hintKey: 'hintCustomers',
    module: AppModule.customer,
  ),
  NavItem(
    section: NavSection.invoices,
    group: NavGroup.operations,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    labelKey: 'navInvoices',
    hintKey: 'hintInvoices',
    module: AppModule.invoice,
  ),
  NavItem(
    section: NavSection.quotations,
    group: NavGroup.operations,
    icon: Icons.request_quote_outlined,
    selectedIcon: Icons.request_quote_rounded,
    labelKey: 'navQuotations',
    hintKey: 'hintQuotations',
    module: AppModule.quote,
  ),
  NavItem(
    section: NavSection.boxes,
    group: NavGroup.operations,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    labelKey: 'navBoxes',
    hintKey: 'hintBoxes',
    module: AppModule.package,
  ),
  NavItem(
    section: NavSection.store,
    group: NavGroup.operations,
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
    labelKey: 'navStore',
    hintKey: 'hintStore',
    module: AppModule.store,
  ),
  NavItem(
    section: NavSection.delivery,
    group: NavGroup.operations,
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake_rounded,
    labelKey: 'navDelivery',
    hintKey: 'hintDelivery',
    module: AppModule.handover,
  ),
  NavItem(
    section: NavSection.claims,
    group: NavGroup.operations,
    icon: Icons.report_problem_outlined,
    selectedIcon: Icons.report_problem_rounded,
    labelKey: 'navClaims',
    hintKey: 'hintClaims',
    module: AppModule.claim,
  ),
  NavItem(
    section: NavSection.whatsapp,
    group: NavGroup.operations,
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum_rounded,
    labelKey: 'navWhatsapp',
    hintKey: 'hintWhatsapp',
    module: AppModule.whatsapp,
  ),
  NavItem(
    section: NavSection.expenses,
    group: NavGroup.finance,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    labelKey: 'navExpenses',
    hintKey: 'hintExpenses',
    module: AppModule.expenses,
  ),
  NavItem(
    section: NavSection.accounting,
    group: NavGroup.finance,
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance_rounded,
    labelKey: 'navAccounting',
    hintKey: 'hintAccounting',
    module: AppModule.accounting,
  ),
  NavItem(
    section: NavSection.payroll,
    group: NavGroup.finance,
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge_rounded,
    labelKey: 'navPayroll',
    hintKey: 'hintPayroll',
    module: AppModule.payroll,
  ),
  NavItem(
    section: NavSection.cashup,
    group: NavGroup.finance,
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    labelKey: 'navCashup',
    hintKey: 'hintCashup',
    module: AppModule.cashup,
  ),
  NavItem(
    section: NavSection.reports,
    group: NavGroup.finance,
    icon: Icons.insert_chart_outlined_rounded,
    selectedIcon: Icons.insert_chart_rounded,
    labelKey: 'navReports',
    hintKey: 'hintReports',
    module: AppModule.report,
  ),
  NavItem(
    section: NavSection.sms,
    group: NavGroup.admin,
    icon: Icons.sms_outlined,
    selectedIcon: Icons.sms_rounded,
    labelKey: 'navSms',
    hintKey: 'hintSms',
    module: AppModule.sms,
  ),
  NavItem(
    section: NavSection.users,
    group: NavGroup.admin,
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts_rounded,
    labelKey: 'navUsers',
    hintKey: 'hintUsers',
    module: AppModule.user,
  ),
  NavItem(
    section: NavSection.audit,
    group: NavGroup.admin,
    icon: Icons.history_rounded,
    selectedIcon: Icons.manage_history_rounded,
    labelKey: 'navAudit',
    hintKey: 'hintAudit',
    module: AppModule.audit,
  ),
  NavItem(
    section: NavSection.settings,
    group: NavGroup.admin,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    labelKey: 'navSettings',
    hintKey: 'hintSettings',
  ),
];

NavItem navItemFor(NavSection section) => navItems.firstWhere(
      (i) => i.section == section,
      orElse: () => navItems.first,
    );

String groupLabelKey(NavGroup g) => switch (g) {
      NavGroup.main => 'grpMain',
      NavGroup.operations => 'grpOperations',
      NavGroup.finance => 'grpFinance',
      NavGroup.admin => 'grpAdmin',
    };

/// Vitu vinne vya kwanza kwenye menyu ya chini (simu); vingine viko "Zaidi".
const List<NavSection> mobilePrimary = [
  NavSection.dashboard,
  NavSection.invoices,
  NavSection.boxes,
  NavSection.delivery,
];
