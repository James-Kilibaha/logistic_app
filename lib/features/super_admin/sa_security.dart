import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Usalama wa akaunti yako ya super admin: uthibitisho wa hatua mbili (app ya Authenticator).
class SaSecurityPage extends StatelessWidget {
  const SaSecurityPage({super.key});

  static Future<void> open() async {
    await Get.to(() => const SaSecurityPage());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text('sa2faTitle'.tr)),
      body: SaLoader<Map<String, dynamic>>(
        load: PlatformApi.twoFactor,
        builder: (context, d, reload) => PageScroll(
          onRefresh: reload,
          children: [
            SectionCard(
              title: 'sa2faTitle'.tr,
              subtitle: 'sa2faSub'.tr,
              icon: Icons.verified_user_outlined,
              trailing: Pill(J.boolean(d['enabled']) ? 'sa2faOn'.tr : 'sa2faOff'.tr,
                  color: J.boolean(d['enabled']) ? p.success : p.warning, dense: true),
              child: J.boolean(d['enabled']) ? _enabled(context, d, reload) : _disabled(context, reload),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disabled(BuildContext context, Future<void> Function() reload) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sa2faWhy'.tr, style: TextStyle(color: p.text, height: 1.45)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () async {
            if (await _enable()) {
              await PlatformApi.refreshMe();
              await reload();
            }
          },
          icon: const Icon(Icons.qr_code_2_rounded),
          label: Text('sa2faEnable'.tr),
        ),
      ],
    );
  }

  Widget _enabled(BuildContext context, Map<String, dynamic> d, Future<void> Function() reload) {
    final p = context.palette;
    final left = J.integer(d['recoveryLeft']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sa2faEnabledMsg'.tr, style: TextStyle(color: p.text, height: 1.45)),
        const SizedBox(height: 8),
        Text('sa2faRecoveryLeft'.trParams({'n': '$left'}),
            style: TextStyle(color: left <= 2 ? p.danger : p.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final codes = await _confirmThen('sa2faNewRecovery'.tr, PlatformApi.twoFactorNewRecovery);
                if (codes != null) {
                  await _showCodes(codes);
                  await reload();
                }
              },
              icon: const Icon(Icons.password_rounded),
              label: Text('sa2faNewRecovery'.tr),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: p.danger),
              onPressed: () async {
                final done = await _confirmThen('sa2faDisable'.tr, (pw, code) async {
                  await PlatformApi.twoFactorDisable(pw, code);
                  return const <String>[];
                }, danger: true);
                if (done != null) {
                  Toast.success('sa2faDisabled'.tr);
                  await PlatformApi.refreshMe();
                  await reload();
                }
              },
              icon: const Icon(Icons.gpp_bad_outlined),
              label: Text('sa2faDisable'.tr),
            ),
          ],
        ),
      ],
    );
  }

  /// Hatua 1: QR; hatua 2: code ya app; mwisho: code za dharura.
  static Future<bool> _enable() async {
    Map<String, dynamic>? setup;
    final ok = await runGuarded(() async => setup = await PlatformApi.twoFactorSetup());
    if (!ok || setup == null) return false;
    final secret = J.str(setup!['secret']);
    final uri = J.str(setup!['uri']);
    final code = TextEditingController();
    List<String> codes = const [];
    final saved = await showFormSheet(
      title: 'sa2faEnable'.tr,
      icon: Icons.qr_code_2_rounded,
      submitLabel: 'sa2faVerify'.tr,
      builder: (context, setState) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('sa2faStep1'.tr, style: TextStyle(color: p.text, height: 1.4)),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: SizedBox(width: 200, height: 200, child: QrImageView(data: uri, size: 200, padding: EdgeInsets.zero)),
              ),
            ),
            const SizedBox(height: 10),
            Text('sa2faManual'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(secret,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                IconButton(
                  tooltip: 'copy'.tr,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: secret));
                    Toast.success('copied'.tr);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('sa2faStep2'.tr, style: TextStyle(color: p.text, height: 1.4)),
            const SizedBox(height: 10),
            AppField(
              controller: code,
              label: 'sa2faCode'.tr,
              icon: Icons.pin_outlined,
              required: true,
              keyboardType: TextInputType.number,
              validator: Validators.minLength(6),
            ),
          ],
        );
      },
      onSubmit: () async => codes = await PlatformApi.twoFactorEnable(code.text),
    );
    if (!saved) return false;
    await _showCodes(codes);
    return true;
  }

  /// Nywila + code (ya app au ya dharura) kabla ya kuzima au kutengeneza code mpya.
  static Future<List<String>?> _confirmThen(
    String title,
    Future<List<String>> Function(String password, String code) action, {
    bool danger = false,
  }) async {
    final pw = TextEditingController();
    final code = TextEditingController();
    List<String>? result;
    final ok = await showFormSheet(
      title: title,
      icon: Icons.lock_outline_rounded,
      danger: danger,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: pw, label: 'password'.tr, obscure: true, required: true, validator: Validators.required),
          const SizedBox(height: 14),
          AppField(
            controller: code,
            label: 'sa2faCode'.tr,
            helper: 'sa2faCodeHelp'.tr,
            required: true,
            validator: Validators.minLength(6),
          ),
        ],
      ),
      onSubmit: () async => result = await action(pw.text, code.text),
    );
    return ok ? (result ?? const []) : null;
  }

  static Future<void> _showCodes(List<String> codes) async {
    if (codes.isEmpty) return;
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) {
        final p = context.palette;
        return AlertDialog(
          title: Text('sa2faRecoveryTitle'.tr),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('sa2faRecoveryMsg'.tr, style: TextStyle(color: p.text, height: 1.4)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: SelectableText(codes.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 15, height: 1.6)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                Toast.success('copied'.tr);
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text('copy'.tr),
            ),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text('sa2faSavedCodes'.tr)),
          ],
        );
      },
    );
  }
}
