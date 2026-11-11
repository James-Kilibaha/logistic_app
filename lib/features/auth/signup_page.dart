import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/company.dart';
import '../../data/repositories.dart';

/// Kampuni mpya ya usafirishaji inajisajili yenyewe na kupata majaribio ya bure.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _slug = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  List<Plan> _plans = [];
  Plan? _plan;
  bool _slugEdited = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  /// null = bado haijaangaliwa; true/false = inapatikana / imechukuliwa
  bool? _slugOk;
  String? _slugReason;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_company, _slug, _phone, _email, _first, _last, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await CompanyRepo.publicPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _plan = plans.isEmpty ? null : plans.first;
        });
      }
    } catch (_) {
      // mipango si lazima: server itachagua ya bei ndogo
    }
  }

  static String _suggest(String name) {
    final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return s.length > 30 ? s.substring(0, 30) : s;
  }

  void _onCompanyName(String v) {
    if (_slugEdited) return;
    _slug.text = _suggest(v);
    _checkSlugSoon();
  }

  void _checkSlugSoon() {
    _debounce?.cancel();
    setState(() {
      _slugOk = null;
      _slugReason = null;
    });
    final value = _slug.text.trim();
    if (value.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await CompanyRepo.checkSlug(value);
        if (!mounted || _slug.text.trim() != value) return;
        setState(() {
          _slugOk = res['available'] == true;
          _slugReason = res['reason']?.toString();
        });
      } catch (_) {
        // tutaangalia tena wakati wa kutuma
      }
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_slugOk == false) {
      setState(() => _error = _slugReason ?? 'companyCodeTaken'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final slug = _slug.text.trim().toLowerCase();
    try {
      final res = await CompanyRepo.signup({
        'companyName': _company.text.trim(),
        'slug': slug,
        'phone': Phone.normalize(_phone.text) ?? _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_plan != null) 'plan_id': _plan!.id,
        'admin': {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'username': _username.text.trim(),
          'password': _password.text,
          'phoneNumber': Phone.normalize(_phone.text),
        },
      });
      await BrandingController.to.useCompany(slug);
      if (res['pending'] == true) {
        // akaunti inasubiri super admin aithibitishe kabla ya kuingia
        if (mounted) await _pendingDialog(slug);
      } else {
        Toast.success('signupDoneMsg'.trParams({'code': slug}), title: 'signupDone'.tr);
      }
      Get.offAllNamed(Routes.login, arguments: {'username': _username.text.trim()});
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pendingDialog(String slug) {
    final p = context.palette;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.hourglass_top_rounded, size: 40, color: p.warning),
        title: Text('signupPendingTitle'.tr, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text('signupPendingMsg'.trParams({'code': slug}), textAlign: TextAlign.center,
              style: const TextStyle(height: 1.45)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text('ok'.tr))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final platform = BrandingController.to.current.value.platform;

    Widget? slugSuffix;
    if (_slugOk == true) slugSuffix = Icon(Icons.check_circle_rounded, color: p.success, size: 20);
    if (_slugOk == false) slugSuffix = Icon(Icons.cancel_rounded, color: p.danger, size: 20);

    return AppPage(
      title: 'signupTitle'.tr,
      subtitle: platform.name,
      showBack: true,
      body: Form(
        key: _form,
        child: PageScroll(
          maxWidth: 720,
          children: [
            SectionCard(
              title: 'signupCompany'.tr,
              subtitle: 'signupCompanySub'.tr,
              icon: Icons.apartment_rounded,
              child: Column(
                children: [
                  AppField(
                    controller: _company,
                    label: 'companyName'.tr,
                    hint: 'Mfano Logistics Ltd',
                    required: true,
                    validator: Validators.required,
                    onChanged: _onCompanyName,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _slug,
                    label: 'companyCode'.tr,
                    hint: 'companyCodeHint'.tr,
                    helper: _slugOk == false ? (_slugReason ?? 'companyCodeTaken'.tr) : 'companyCodeSignupHelp'.tr,
                    icon: Icons.tag_rounded,
                    suffix: slugSuffix,
                    required: true,
                    validator: Validators.minLength(3),
                    onChanged: (_) {
                      _slugEdited = true;
                      _checkSlugSoon();
                    },
                  ),
                  const SizedBox(height: 16),
                  PhoneField(controller: _phone, required: true, label: 'companyPhone'.tr),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _email,
                    label: 'email'.tr,
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            if (_plans.isNotEmpty)
              SectionCard(
                title: 'choosePlan'.tr,
                subtitle: 'choosePlanSub'.tr,
                icon: Icons.workspace_premium_outlined,
                child: Column(
                  children: [
                    for (final plan in _plans)
                      _PlanTile(plan: plan, selected: _plan == plan, onTap: () => setState(() => _plan = plan)),
                  ],
                ),
              ),
            SectionCard(
              title: 'signupAdmin'.tr,
              subtitle: 'signupAdminSub'.tr,
              icon: Icons.admin_panel_settings_outlined,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          controller: _first,
                          label: 'firstName'.tr,
                          required: true,
                          validator: Validators.required,
                          capitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppField(
                          controller: _last,
                          label: 'lastName'.tr,
                          required: true,
                          validator: Validators.required,
                          capitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _username,
                    label: 'username'.tr,
                    icon: Icons.person_outline_rounded,
                    required: true,
                    validator: Validators.minLength(3),
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _password,
                    label: 'password'.tr,
                    icon: Icons.lock_outline_rounded,
                    obscure: _hidden,
                    required: true,
                    helper: 'passwordPolicy'.tr,
                    validator: Validators.minLength(8),
                    suffix: IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _confirm,
                    label: 'confirmPassword'.tr,
                    icon: Icons.lock_outline_rounded,
                    obscure: _hidden,
                    required: true,
                    validator: (v) => v != _password.text ? 'passwordsDontMatch'.tr : null,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.danger.withValues(alpha: .3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: p.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: p.danger))),
                  ],
                ),
              ),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy ? const ButtonSpinner() : const Icon(Icons.rocket_launch_outlined, size: 20),
                label: Text('signupSubmit'.tr),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Get.offAllNamed(Routes.login),
                child: Text('haveAccountLogin'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final limits = [
      plan.maxUsers == null ? 'unlimitedUsers'.tr : 'nUsers'.trParams({'n': '${plan.maxUsers}'}),
      plan.maxOffices == null ? 'unlimitedOffices'.tr : 'nOffices'.trParams({'n': '${plan.maxOffices}'}),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? p.primarySoft : p.surfaceAlt,
            border: Border.all(color: selected ? p.primary : p.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? p.primary : p.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                    if (plan.description != null)
                      Text(plan.description!, style: TextStyle(color: p.muted, fontSize: 13)),
                    Text(limits, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${plan.currency} ${Fmt.number(plan.price)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  Text(plan.months == 1 ? 'perMonth'.tr : 'perMonths'.trParams({'n': '${plan.months}'}),
                      style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
