import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/branding.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/states.dart';
import '../auth/forgot_password.dart';
import 'platform_api.dart';
import 'sa_activity.dart';
import 'sa_admins.dart';
import 'sa_audit.dart';
import 'sa_companies.dart';
import 'sa_dashboard.dart';
import 'sa_notices.dart';
import 'sa_payments.dart';
import 'sa_plans.dart';
import 'sa_reports.dart';
import 'sa_security.dart';
import 'sa_support.dart';

/// Admin panel ya mfumo mzima (wewe - super admin): `/#/super-admin`.
///
/// Inaingiwa kwa akaunti ya platform admin (ADMIN_USERNAME/ADMIN_PASSWORD za .env), si mtumiaji wa kampuni.
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  bool _loggedIn = Session.platformToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    PlatformApi.onUnauthorized = () async {
      await PlatformApi.logout();
      if (!mounted || !_loggedIn) return;
      setState(() => _loggedIn = false);
      Toast.warning('sessionExpiredMsg'.tr, title: 'sessionExpired'.tr);
    };
  }

  @override
  void dispose() {
    PlatformApi.onUnauthorized = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return _SuperLogin(onDone: () => setState(() => _loggedIn = true));
    return _SuperShell(onLogout: () async {
      await PlatformApi.logout();
      if (mounted) setState(() => _loggedIn = false);
    });
  }
}

// ------------------------------------------------------------------ kuingia

class _SuperLogin extends StatefulWidget {
  final VoidCallback onDone;

  const _SuperLogin({required this.onDone});

  @override
  State<_SuperLogin> createState() => _SuperLoginState();
}

class _SuperLoginState extends State<_SuperLogin> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(text: (Session.platformAdmin?['username'] ?? '').toString());
  final _password = TextEditingController();
  final _code = TextEditingController();

  /// Imewekwa baada ya nywila sahihi kwa akaunti yenye 2FA: sasa code ya app inahitajika.
  String? _challenge;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_challenge != null) {
        await PlatformApi.login2fa(_challenge!, _code.text);
        widget.onDone();
        return;
      }
      final challenge = await PlatformApi.login(_username.text, _password.text);
      if (challenge != null) {
        setState(() {
          _challenge = challenge;
          _code.clear();
        });
        return;
      }
      widget.onDone();
    } on ApiException catch (e) {
      final expired = _challenge != null && e.message.toLowerCase().contains('expired');
      setState(() {
        _error = e.status == 404 ? 'wrongCredentials'.tr : e.message;
        if (expired) _challenge = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Umesahau nywila: code kwa SMS/email ya akaunti yako ya super admin.
  Future<void> _forgot() async {
    final account = await showForgotPassword(
      username: _username.text,
      request: PlatformApi.forgot,
      reset: PlatformApi.forgotReset,
      fieldLabelKey: 'saForgotField',
    );
    if (account != null && mounted) {
      setState(() {
        _username.text = account;
        _password.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 48, color: p.primary),
                      const SizedBox(height: 12),
                      Text('saTitle'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 6),
                      Text('saLoginSub'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: p.danger)),
                        const SizedBox(height: 12),
                      ],
                      if (_challenge == null) ...[
                        AppField(
                          controller: _username,
                          label: 'username'.tr,
                          icon: Icons.person_outline_rounded,
                          required: true,
                          validator: Validators.required,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        AppField(
                          controller: _password,
                          label: 'password'.tr,
                          icon: Icons.lock_outline_rounded,
                          obscure: _hidden,
                          required: true,
                          validator: Validators.required,
                          onSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          ),
                        ),
                      ] else ...[
                        Text('sa2faEnterCode'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.text, height: 1.4)),
                        const SizedBox(height: 14),
                        AppField(
                          controller: _code,
                          label: 'sa2faCode'.tr,
                          icon: Icons.verified_user_outlined,
                          required: true,
                          autofocus: true,
                          helper: 'sa2faCodeHelp'.tr,
                          validator: Validators.minLength(6),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy ? const ButtonSpinner() : Text(_challenge == null ? 'login'.tr : 'sa2faVerify'.tr),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_challenge != null)
                        TextButton(
                          onPressed: _busy ? null : () => setState(() {
                            _challenge = null;
                            _error = null;
                          }),
                          child: Text('back'.tr),
                        )
                      else
                        TextButton(onPressed: _busy ? null : _forgot, child: Text('forgotPassword'.tr)),
                      TextButton(onPressed: () => Get.offAllNamed('/login'), child: Text('saBackToApp'.tr)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ menyu

enum _Section { dashboard, reports, activity, companies, payments, plans, support, admins, audit }

class _SuperShell extends StatefulWidget {
  final VoidCallback onLogout;

  const _SuperShell({required this.onLogout});

  @override
  State<_SuperShell> createState() => _SuperShellState();
}

class _SuperShellState extends State<_SuperShell> {
  _Section _section = _Section.dashboard;
  final _scaffold = GlobalKey<ScaffoldState>();

  /// Kampuni iliyochaguliwa kutoka dashboard (inafunguliwa kwenye "Kampuni").
  String? _openCompanyId;

  /// Kichujio cha kampuni kutoka dashboard (mf. zinazosubiri kuthibitishwa).
  String? _companyStatus;

  /// Kichupo cha malipo cha kufungua (mf. ONLINE kutoka kwenye taarifa).
  String? _paymentsTab;

  /// Taarifa (🔔) + popup za mambo ya haraka.
  late final SaNotices _notices = SaNotices(onOpen: _openLink);

  @override
  void initState() {
    super.initState();
    _notices.start();
  }

  @override
  void dispose() {
    _notices.dispose();
    SaNotices.resetSession();
    super.dispose();
  }

  /// Kiungo cha taarifa -> sehemu husika.
  void _openLink(String link) {
    final i = link.indexOf(':');
    final kind = i < 0 ? link : link.substring(0, i);
    final id = i < 0 ? null : link.substring(i + 1);
    switch (kind) {
      case 'payment':
      case 'payments':
        _go(_Section.payments);
      case 'onlinepay':
        _go(_Section.payments, paymentsTab: 'ONLINE');
      case 'company':
        _go(_Section.companies, companyId: id);
      case 'companies':
        _go(_Section.companies, status: 'PENDING');
      case 'ticket':
        _go(_Section.support);
        if (id != null) openPlatformTicket(id).then((_) => _notices.refresh());
      case 'support':
        _go(_Section.support);
      default:
        _go(_Section.dashboard);
    }
  }

  static const _items = [
    (_Section.dashboard, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'navDashboard'),
    (_Section.reports, Icons.insights_outlined, Icons.insights_rounded, 'saReports'),
    (_Section.activity, Icons.timeline_outlined, Icons.timeline_rounded, 'saActivity'),
    (_Section.companies, Icons.apartment_outlined, Icons.apartment_rounded, 'saCompanies'),
    (_Section.payments, Icons.payments_outlined, Icons.payments_rounded, 'subPayments'),
    (_Section.plans, Icons.layers_outlined, Icons.layers_rounded, 'subPlans'),
    (_Section.support, Icons.support_agent_outlined, Icons.support_agent_rounded, 'tkTitle'),
    (_Section.admins, Icons.shield_outlined, Icons.shield_rounded, 'saAdmins'),
    (_Section.audit, Icons.history_rounded, Icons.manage_history_rounded, 'saAudit'),
  ];

  void _go(_Section s, {String? companyId, String? status, String? paymentsTab}) => setState(() {
        _section = s;
        _openCompanyId = companyId;
        _companyStatus = status;
        _paymentsTab = paymentsTab;
      });

  Widget _body() => switch (_section) {
        _Section.dashboard => SaDashboard(
            onOpenCompany: (id) => _go(_Section.companies, companyId: id),
            onOpenPayments: () => _go(_Section.payments),
            onOpenPending: () => _go(_Section.companies, status: 'PENDING'),
            onOpenSupport: () => _go(_Section.support),
          ),
        _Section.reports => SaReports(onOpenCompany: (id) => _go(_Section.companies, companyId: id)),
        _Section.support => const SaSupport(),
        _Section.activity => SaActivity(onOpenCompany: (id) => _go(_Section.companies, companyId: id)),
        _Section.companies => SaCompanies(
            key: ValueKey('${_openCompanyId}_$_companyStatus'),
            openCompanyId: _openCompanyId,
            initialStatus: _companyStatus,
          ),
        _Section.payments => SaPayments(key: ValueKey(_paymentsTab), initialStatus: _paymentsTab),
        _Section.plans => const SaPlans(),
        _Section.admins => const SaAdmins(),
        _Section.audit => SaAudit(onOpenCompany: (id) => _go(_Section.companies, companyId: id)),
      };

  Future<void> _changePassword() async {
    final old = TextEditingController();
    final fresh = TextEditingController();
    final ok = await showFormSheet(
      title: 'changePassword'.tr,
      icon: Icons.lock_reset_rounded,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: old, label: 'saOldPassword'.tr, obscure: true, required: true,
              validator: Validators.required),
          const SizedBox(height: 14),
          AppField(controller: fresh, label: 'saNewPassword'.tr, obscure: true, required: true,
              helper: 'passwordPolicy'.tr, validator: Validators.minLength(8)),
        ],
      ),
      onSubmit: () => PlatformApi.changePassword(old.text, fresh.text),
    );
    if (ok) Toast.success('saved'.tr);
  }

  @override
  Widget build(BuildContext context) {
    // jina la tab ya browser: "Sehemu · Super Admin · Jukwaa"
    final section = _items[_Section.values.indexOf(_section)].$4.tr;
    final platform = Get.isRegistered<BrandingController>() ? BrandingController.to.current.value.platform.name : '';
    return ListenableBuilder(
      listenable: _notices,
      builder: (context, child) => Title(
        title: '${_notices.badge > 0 ? '(${_notices.badge}) ' : ''}'
            '${[section, 'saTitle'.tr, if (platform.isNotEmpty) platform].join(' · ')}',
        color: context.palette.primary,
        child: child!,
      ),
      child: _page(context),
    );
  }

  Widget _page(BuildContext context) {
    final p = context.palette;
    final wide = context.screenWidth >= Breakpoints.medium;
    final admin = Session.platformAdmin;
    final index = _Section.values.indexOf(_section);
    final current = _items[index];

    final menu = PopupMenuButton<String>(
      tooltip: (admin?['fullName'] ?? '').toString(),
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (v) {
        switch (v) {
          case 'password':
            _changePassword();
          case 'security':
            SaSecurityPage.open().then((_) => setState(() {}));
          case 'theme':
            final dark = AppController.to.themeMode.value == ThemeMode.dark;
            AppController.to.setTheme(dark ? ThemeMode.light : ThemeMode.dark);
          case 'logout':
            widget.onLogout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text('${admin?['fullName'] ?? ''} (${admin?['username'] ?? ''}) · ${'saRole_${admin?['role'] ?? 'OWNER'}'.tr}',
              style: TextStyle(color: p.muted, fontSize: 13)),
        ),
        PopupMenuItem(value: 'password', child: Text('changePassword'.tr)),
        PopupMenuItem(value: 'security', child: Text('sa2faTitle'.tr)),
        PopupMenuItem(value: 'theme', child: Text('theme'.tr)),
        PopupMenuItem(value: 'logout', child: Text('logout'.tr)),
      ],
    );

    final appBar = AppBar(
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: p.primary),
          const SizedBox(width: 10),
          Flexible(child: Text('${'saTitle'.tr} · ${current.$4.tr}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: [SaBell(notices: _notices), menu, const SizedBox(width: 6)],
    );

    if (!wide) {
      // simu: sehemu ni nyingi kwa menyu ya chini - drawer
      return Scaffold(
        key: _scaffold,
        backgroundColor: p.background,
        appBar: appBar,
        body: _body(),
        drawer: NavigationDrawer(
          selectedIndex: index,
          onDestinationSelected: (i) {
            _scaffold.currentState?.closeDrawer();
            _go(_Section.values[i]);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
              child: Text('saTitle'.tr, style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 16)),
            ),
            for (final it in _items)
              NavigationDrawerDestination(icon: Icon(it.$2), selectedIcon: Icon(it.$3), label: Text(it.$4.tr)),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            extended: context.screenWidth >= Breakpoints.wide,
            onDestinationSelected: (i) => _go(_Section.values[i]),
            destinations: [
              for (final it in _items)
                NavigationRailDestination(icon: Icon(it.$2), selectedIcon: Icon(it.$3), label: Text(it.$4.tr)),
            ],
          ),
          VerticalDivider(width: 1, color: p.border),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
