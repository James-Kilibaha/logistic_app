import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/branding.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/states.dart';
import '../../data/repositories.dart';
import 'company_dialog.dart';
import 'forgot_password.dart';
import 'server_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController(
      text: (Get.arguments is Map ? (Get.arguments as Map)['username']?.toString() : null) ?? Session.lastUsername);
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _hidden = true;
  bool _remember = Session.rememberMe;
  bool _busy = false;
  String? _error;

  // Hatua ya pili (2FA): code ya SMS
  final _code = TextEditingController();
  String? _otpToken;
  String _phoneHint = '';
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // App ya simu (au web kwenye domain ya mfumo) bila kampuni: uliza code ya kampuni kwanza.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !BrandingController.to.hasCompany) _chooseCompany();
    });
  }

  Future<void> _chooseCompany() async {
    await showCompanyDialog();
    if (mounted) setState(() => _error = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendIn = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  String _message(Object e) {
    if (e is ApiException) {
      return switch (e.status) {
        404 => 'wrongCredentials'.tr,
        429 => 'loginLocked'.trParams({'n': RegExp(r'\d+').firstMatch(e.message)?.group(0) ?? '15'}),
        _ => e.message,
      };
    }
    return e.toString();
  }

  Future<void> _verify() async {
    if (_busy || _otpToken == null) return;
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'otpEnterCode'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppController.to.verifyOtp(_otpToken!, _code.text);
      Get.offAllNamed(AppController.to.homeRoute);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_otpToken == null || _resendIn > 0) return;
    try {
      final res = await AuthRepo.resendOtp(_otpToken!);
      _otpToken = (res['otpToken'] ?? _otpToken).toString();
      _code.clear();
      _startCountdown();
      Toast.success('otpResent'.tr);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  void _backToPassword() {
    _timer?.cancel();
    setState(() {
      _otpToken = null;
      _error = null;
      _code.clear();
      _password.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!BrandingController.to.hasCompany) {
      await _chooseCompany();
      if (!BrandingController.to.hasCompany) return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.setRememberMe(_remember);
      final challenge = await AppController.to.login(_username.text, _password.text);
      if (challenge != null) {
        setState(() {
          _otpToken = (challenge['otpToken'] ?? '').toString();
          _phoneHint = (challenge['phoneHint'] ?? '').toString();
        });
        _startCountdown();
        return;
      }
      Get.offAllNamed(AppController.to.homeRoute);
    } on ApiException catch (e) {
      setState(() => _error = switch (e.status) {
            404 => 'wrongCredentials'.tr,
            429 => 'loginLocked'.trParams({'n': RegExp(r'\d+').firstMatch(e.message)?.group(0) ?? '15'}),
            _ => e.message,
          });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openServer() async {
    await showServerDialog();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool wide = context.screenWidth >= 900;

    final Widget form = _otpToken != null
        ? _OtpForm(
            code: _code,
            phoneHint: _phoneHint,
            busy: _busy,
            error: _error,
            resendIn: _resendIn,
            onVerify: _verify,
            onResend: _resend,
            onBack: _backToPassword,
          )
        : _LoginForm(
      formKey: _formKey,
      username: _username,
      password: _password,
      passwordFocus: _passwordFocus,
      hidden: _hidden,
      busy: _busy,
      error: _error,
      onToggleHidden: () => setState(() => _hidden = !_hidden),
      remember: _remember,
      onRemember: (v) => setState(() => _remember = v),
      onSubmit: _submit,
      onChangeCompany: _chooseCompany,
      onForgot: () async {
        final name = await showForgotPassword(username: _username.text);
        if (name != null && mounted) {
          setState(() {
            _username.text = name;
            _password.clear();
            _error = null;
          });
          _passwordFocus.requestFocus();
        }
      },
    );

    return Scaffold(
      backgroundColor: wide ? p.background : p.surface,
      body: SafeArea(
        child: Stack(
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(flex: 5, child: Obx(() {
                    final b = BrandingController.to.current.value; // ijenge upya branding ikibadilika
                    return _BrandPanel(key: ValueKey(Object.hash(b.name, b.logoUrl, b.primary, b.accent)));
                  })),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: form),
                      ),
                    ),
                  ),
                ],
              )
            else
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandLogo(size: 84, elevated: true)),
                        const SizedBox(height: 14),
                        Obx(() => Text(
                              BrandingController.to.current.value.displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
                            )),
                        const SizedBox(height: 28),
                        form,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Get.toNamed(Routes.track),
                    icon: const Icon(Icons.travel_explore_rounded, size: 20),
                    label: Text('trackCargo'.tr),
                  ),
                  _TopIcon(
                    tooltip: 'language'.tr,
                    icon: Icons.translate_rounded,
                    onTap: () {
                      final isSw = Get.locale?.languageCode == 'sw';
                      AppController.to.setLocale(isSw ? const Locale('en', 'US') : const Locale('sw', 'TZ'));
                    },
                  ),
                  Obx(() {
                    final dark = AppController.to.themeMode.value == ThemeMode.dark;
                    return _TopIcon(
                      tooltip: 'theme'.tr,
                      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      onTap: () => AppController.to.setTheme(dark ? ThemeMode.light : ThemeMode.dark),
                    );
                  }),
                  _TopIcon(tooltip: 'server'.tr, icon: Icons.dns_outlined, onTap: _openServer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _TopIcon({required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon));
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final FocusNode passwordFocus;
  final bool hidden;
  final bool busy;
  final String? error;
  final VoidCallback onToggleHidden;
  final bool remember;
  final ValueChanged<bool> onRemember;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback onChangeCompany;

  const _LoginForm({
    required this.formKey,
    required this.username,
    required this.password,
    required this.passwordFocus,
    required this.hidden,
    required this.busy,
    required this.error,
    required this.onToggleHidden,
    required this.remember,
    required this.onRemember,
    required this.onSubmit,
    required this.onForgot,
    required this.onChangeCompany,
  });

  /// Web iliyofunguliwa kwenye domain ya kampuni yenyewe haihitaji kubadilisha kampuni.
  static bool get _companyFromDomain {
    if (!kIsWeb) return false;
    final b = BrandingController.to.current.value;
    final host = Uri.base.host.toLowerCase();
    return b.resolved && (host == (b.raw['domain'] ?? '').toString().toLowerCase() || host.startsWith('${b.slug}.'));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!Session.companyLocked && !_companyFromDomain)
              Obx(() {
                final b = BrandingController.to.current.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Material(
                    color: b.resolved ? p.surfaceAlt : p.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: busy ? null : onChangeCompany,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.apartment_rounded, size: 20, color: p.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b.resolved ? '${b.name} (${b.slug})' : 'companyChoose'.tr,
                                style: TextStyle(color: p.text, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(b.resolved ? 'change'.tr : 'companyEnterCode'.tr,
                                style: TextStyle(color: p.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            Obx(() {
              // kampuni bado haijathibitishwa / imezuiwa: mtumiaji ajue kabla ya kujaribu kuingia
              final b = BrandingController.to.current.value;
              if (!b.resolved || b.status == 'ACTIVE') return const SizedBox.shrink();
              final (Color color, String text) = switch (b.status) {
                'PENDING' => (p.warning, 'companyPendingNote'.tr),
                'REJECTED' => (p.danger, 'companyRejectedNote'.tr),
                _ => (p.danger, 'companySuspendedNote'.tr),
              };
              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: .35)),
                ),
                child: Row(
                  children: [
                    Icon(b.status == 'PENDING' ? Icons.hourglass_top_rounded : Icons.block_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: TextStyle(color: p.text, height: 1.35))),
                  ],
                ),
              );
            }),
            Text('welcomeBack'.tr, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 6),
            Text('loginSubtitle'.tr, style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
            const SizedBox(height: 28),
            if (error != null) ...[
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
                    Expanded(child: Text(error!, style: TextStyle(color: p.danger))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            FieldLabel('username'.tr),
            TextFormField(
              controller: username,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              validator: Validators.required,
              onFieldSubmitted: (_) => passwordFocus.requestFocus(),
              decoration: InputDecoration(
                hintText: 'usernameHint'.tr,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel('password'.tr),
            TextFormField(
              controller: password,
              focusNode: passwordFocus,
              obscureText: hidden,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              validator: Validators.required,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: hidden ? 'showPassword'.tr : 'hidePassword'.tr,
                  onPressed: onToggleHidden,
                  icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'rememberMeHint'.tr,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onRemember(!remember),
                child: Row(
                  children: [
                    Checkbox(value: remember, onChanged: (v) => onRemember(v ?? false)),
                    Text('rememberMe'.tr, style: TextStyle(color: p.text)),
                    const Spacer(),
                    TextButton(onPressed: busy ? null : onForgot, child: Text('forgotPassword'.tr)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                child: busy
                    ? const ButtonSpinner()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('login'.tr),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
            if (!Session.companyLocked && BrandingController.to.current.value.platform.signup) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text('noAccountYet'.tr, style: TextStyle(color: p.muted))),
                  TextButton(
                    onPressed: busy ? null : () => Get.toNamed(Routes.signup),
                    child: Text('signupCta'.tr),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Upande wa kushoto wa Login (kompyuta): rangi ya brand na maelezo mafupi.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = BrandingController.to.current.value.primary ?? const Color(0xFF1F4FD8);
    final accent = BrandingController.to.current.value.accent ?? const Color(0xFFFBBF24);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, .4)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -60,
            child: Icon(Icons.public_rounded, size: 340, color: Colors.white.withValues(alpha: .06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandLogo(size: 54, elevated: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      BrandingController.to.current.value.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: .95), fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'brandHeadline'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 34, height: 1.15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                'brandSub'.tr,
                style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 15.5, height: 1.5),
              ),
              const SizedBox(height: 30),
              for (final (IconData icon, String key) in const [
                (Icons.inventory_2_outlined, 'brandPoint1'),
                (Icons.local_shipping_outlined, 'brandPoint2'),
                (Icons.payments_outlined, 'brandPoint3'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(key.tr, style: TextStyle(color: Colors.white.withValues(alpha: .92), fontSize: 14.5)),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text('© ${BrandingController.to.current.value.displayName} · ${BrandingController.to.current.value.platform.name}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}


/// Hatua ya pili ya kuingia (2FA): code ya tarakimu 6 iliyotumwa kwa SMS.
class _OtpForm extends StatelessWidget {
  final TextEditingController code;
  final String phoneHint;
  final bool busy;
  final String? error;
  final int resendIn;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _OtpForm({
    required this.code,
    required this.phoneHint,
    required this.busy,
    required this.error,
    required this.resendIn,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, size: 44, color: p.primary),
        const SizedBox(height: 12),
        Text('otpTitle'.tr, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.text)),
        const SizedBox(height: 6),
        Text('otpSubtitle'.trParams({'phone': phoneHint}), style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
        const SizedBox(height: 22),
        if (error != null) ...[
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
                Expanded(child: Text(error!, style: TextStyle(color: p.danger))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: '••••••', counterText: ''),
          onSubmitted: (_) => onVerify(),
          onChanged: (v) {
            if (v.trim().length == 6) onVerify();
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: busy ? null : onVerify,
            child: busy ? const ButtonSpinner() : Text('otpVerify'.tr),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: busy ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text('back'.tr),
            ),
            const Spacer(),
            TextButton(
              onPressed: resendIn > 0 || busy ? null : onResend,
              child: Text(resendIn > 0 ? 'otpResendIn'.trParams({'n': '$resendIn'}) : 'otpResend'.tr),
            ),
          ],
        ),
      ],
    );
  }
}
