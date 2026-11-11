import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/help.dart';
import '../../core/widgets/inputs.dart';
import '../../data/repositories.dart';

/// Sera ya nywila (sawa na ya server): herufi 8+, zenye herufi na namba.
String? passwordPolicy(String? v) {
  final s = v ?? '';
  if (s.length < 8) return 'minChars'.trParams({'n': '8'});
  if (!s.contains(RegExp(r'[A-Za-z]')) || !s.contains(RegExp(r'[0-9]'))) return 'passwordLettersDigits'.tr;
  return null;
}

/// Kubadilisha nywila yako. [forced] = mtumiaji mpya / nywila ya muda: hawezi kuendelea bila kuibadilisha.
class ChangePasswordPage extends StatefulWidget {
  final bool forced;

  const ChangePasswordPage({super.key, this.forced = false});

  static Future<void> open() async {
    await Get.to(() => const ChangePasswordPage());
  }

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await AccountRepo.changeOwnPassword(_old.text, _new.text);
      await AppController.to.applyAuthResponse(res);
      Toast.success('passwordChangedSelf'.tr, title: 'passwordChanged'.tr);
      if (widget.forced) {
        await AppController.to.refreshPermissions();
        Get.offAllNamed(Routes.home);
      } else {
        Get.back();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = AppController.to.user.value;
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: Text('changePassword'.tr),
          actions: [
            const HelpButton(topic: 'changePassword'),
            if (widget.forced)
              TextButton.icon(
                onPressed: () => AppController.to.logout(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('logout'.tr),
              ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.lock_reset_rounded, size: 44, color: p.primary),
                        const SizedBox(height: 10),
                        Text(
                          widget.forced ? 'mustChangePasswordTitle'.tr : 'changePassword'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.forced
                              ? 'mustChangePasswordMsg'.trParams({'name': user?.firstName ?? ''})
                              : 'changePasswordSelfMsg'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        AppField(
                          controller: _old,
                          label: widget.forced ? 'tempPassword'.tr : 'currentPassword'.tr,
                          icon: Icons.lock_outline_rounded,
                          obscure: _hidden,
                          required: true,
                        ),
                        const SizedBox(height: 14),
                        AppField(
                          controller: _new,
                          label: 'newPassword'.tr,
                          helper: 'passwordRules'.tr,
                          icon: Icons.password_rounded,
                          obscure: _hidden,
                          required: true,
                          validator: passwordPolicy,
                          suffix: IconButton(
                            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                            onPressed: () => setState(() => _hidden = !_hidden),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppField(
                          controller: _confirm,
                          label: 'confirmPassword'.tr,
                          icon: Icons.password_rounded,
                          obscure: _hidden,
                          required: true,
                          validator: (v) => v != _new.text ? 'passwordsDontMatch'.tr : null,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: p.danger)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check_rounded),
                          label: Text('savePassword'.tr),
                        ),
                        const SizedBox(height: 8),
                        Text('otherDevicesLoggedOut'.tr,
                            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ],
                    ),
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
