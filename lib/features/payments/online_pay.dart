import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// Mitandao inayokubaliwa na AzamPay (thamani = jina la AzamPay).
const mobileProviders = <(String, String)>[
  ('Mpesa', 'M-Pesa (Vodacom)'),
  ('Tigo', 'Mixx by Yas (Tigo Pesa)'),
  ('Airtel', 'Airtel Money'),
  ('Halopesa', 'Halopesa'),
  ('Azampesa', 'AzamPesa'),
];

/// Kukisia mtandao kwa namba (mtumiaji anaweza kubadilisha).
String? guessProvider(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final local = digits.startsWith('255') ? digits.substring(3) : digits.replaceFirst(RegExp(r'^0+'), '');
  if (local.length < 2) return null;
  return switch (local.substring(0, 2)) {
    '74' || '75' || '76' || '79' => 'Mpesa',
    '71' || '65' || '67' || '77' => 'Tigo',
    '68' || '69' || '78' => 'Airtel',
    '62' || '61' => 'Halopesa',
    _ => null,
  };
}

/// Mteja anapokea ombi la PIN kwenye simu: fomu (simu, mtandao, kiasi) -> kusubiri hadi athibitishe.
/// Inarudisha true malipo yakifanikiwa.
Future<bool> startMobilePayment({
  required String title,
  required String subtitle,
  String? phone,
  double? amount,
  double? maxAmount,
  bool askAmount = false,
  required Future<Map<String, dynamic>> Function(String phone, String provider, double? amount) start,
  required Future<Map<String, dynamic>> Function(String id) poll,
}) async {
  final phoneCtrl = TextEditingController(text: phone == null ? '' : Fmt.phone(phone));
  final amountCtrl = TextEditingController(text: amount == null ? '' : amount.round().toString());
  String? provider = guessProvider(phone ?? '');
  Map<String, dynamic>? started;
  final ok = await showFormSheet(
    title: title,
    subtitle: subtitle,
    icon: Icons.phone_iphone_rounded,
    submitLabel: 'paySendRequest'.tr,
    submitIcon: Icons.send_to_mobile_rounded,
    builder: (context, setState) => Column(
      children: [
        PhoneField(
          controller: phoneCtrl,
          label: 'payPhone'.tr,
          required: true,
          onChanged: (v) {
            final g = guessProvider(v);
            if (g != null && g != provider) setState(() => provider = g);
          },
        ),
        const SizedBox(height: 14),
        AppDropdown<String>(
          label: 'payNetwork'.tr,
          value: provider,
          items: [for (final p in mobileProviders) p.$1],
          itemLabel: (v) => mobileProviders.firstWhere((p) => p.$1 == v).$2,
          icon: Icons.cell_tower_rounded,
          required: true,
          validator: (v) => v == null ? 'fieldRequired'.tr : null,
          onChanged: (v) => setState(() => provider = v),
        ),
        if (askAmount) ...[
          const SizedBox(height: 14),
          AppField(
            controller: amountCtrl,
            label: 'payAmount'.tr,
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            helper: maxAmount == null ? null : 'payMax'.trParams({'n': Fmt.tsh(maxAmount)}),
            required: true,
            validator: (v) {
              final n = double.tryParse((v ?? '').trim()) ?? 0;
              if (n < 100) return 'payMin'.tr;
              if (maxAmount != null && n > maxAmount + 1) return 'payMax'.trParams({'n': Fmt.tsh(maxAmount)});
              return null;
            },
          ),
        ] else if (amount != null) ...[
          const SizedBox(height: 14),
          InfoRow(label: 'payAmount'.tr, value: Fmt.tsh(amount), emphasize: true),
        ],
        const SizedBox(height: 10),
        Text('payHowItWorks'.tr, style: TextStyle(color: context.palette.muted, fontSize: 12.5, height: 1.4)),
      ],
    ),
    onSubmit: () async {
      started = await start(phoneCtrl.text, provider!, askAmount ? double.tryParse(amountCtrl.text.trim()) : null);
    },
  );
  if (!ok || started == null) return false;
  return waitForMobilePayment(started!, poll);
}

/// Dirisha la kusubiri: linauliza hali kila sekunde 4 hadi SUCCESS / FAILED / EXPIRED.
Future<bool> waitForMobilePayment(Map<String, dynamic> first, Future<Map<String, dynamic>> Function(String id) poll) async {
  final ctx = Get.overlayContext ?? Get.context;
  if (ctx == null) return false;
  final result = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => _WaitDialog(first: first, poll: poll),
  );
  return result ?? false;
}

class _WaitDialog extends StatefulWidget {
  final Map<String, dynamic> first;
  final Future<Map<String, dynamic>> Function(String id) poll;

  const _WaitDialog({required this.first, required this.poll});

  @override
  State<_WaitDialog> createState() => _WaitDialogState();
}

class _WaitDialogState extends State<_WaitDialog> {
  late Map<String, dynamic> _p = widget.first;
  Timer? _timer;

  String get _status => J.str(_p['status'], 'PENDING');

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_status != 'PENDING') return;
    try {
      final p = await widget.poll(J.str(_p['id']));
      if (!mounted) return;
      setState(() => _p = p);
      if (_status != 'PENDING') {
        _timer?.cancel();
        if (_status == 'SUCCESS') AppController.to.notifyChanged();
      }
    } catch (_) {
      // mtandao: tutajaribu tena baada ya sekunde 4
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, Color color, String text) = switch (_status) {
      'SUCCESS' => (Icons.check_circle_rounded, p.success, 'payDone'.tr),
      'FAILED' => (Icons.cancel_rounded, p.danger, 'payFailed'.tr),
      'EXPIRED' => (Icons.timer_off_outlined, p.muted, 'payExpired'.tr),
      _ => (Icons.phone_iphone_rounded, p.primary, 'payWaiting'.tr),
    };
    return AlertDialog(
      title: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_status == 'PENDING') ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 14),
              Text('payWaitingMsg'.trParams({'phone': Fmt.phone(J.str(_p['msisdn'])), 'provider': J.str(_p['provider'])}),
                  style: TextStyle(color: p.text, height: 1.4)),
            ],
            const SizedBox(height: 10),
            InfoRow(label: 'payAmount'.tr, value: Fmt.tsh(J.dbl(_p['amount']))),
            if (J.strOrNull(_p['operatorRef']) != null) InfoRow(label: 'payReference'.tr, value: J.str(_p['operatorRef'])),
            if (_status != 'PENDING' && _status != 'SUCCESS' && J.strOrNull(_p['message']) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(J.str(_p['message']), style: TextStyle(color: p.danger)),
              ),
          ],
        ),
      ),
      actions: [
        if (_status == 'PENDING') TextButton(onPressed: _check, child: Text('payCheckNow'.tr)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_status == 'SUCCESS'),
          child: Text(_status == 'PENDING' ? 'payCloseWait'.tr : 'close'.tr),
        ),
      ],
    );
  }
}

/// Kulipisha ankara kwa simu (mteja anaweka PIN; malipo na risiti vinarekodiwa vyenyewe).
Future<bool> payInvoiceByPhone({required String debtId, required double balance, String? phone, String? invoiceNumber}) =>
    startMobilePayment(
      title: 'payInvoiceTitle'.tr,
      subtitle: 'payForInvoice'.trParams({'n': invoiceNumber ?? '-'}),
      phone: phone,
      amount: balance,
      maxAmount: balance,
      askAmount: true,
      start: (ph, provider, amount) => OnlinePayRepo.payInvoice(debtId, phone: ph, provider: provider, amount: amount),
      poll: OnlinePayRepo.status,
    );

// ---------------------------------------------------------------------------- mipangilio ya AzamPay

/// Kampuni inaunganisha akaunti yake ya AzamPay ili wateja walipe ankara kwa simu.
class OnlinePaySettingsPage extends StatefulWidget {
  const OnlinePaySettingsPage({super.key});

  @override
  State<OnlinePaySettingsPage> createState() => _OnlinePaySettingsPageState();
}

class _OnlinePaySettingsPageState extends State<OnlinePaySettingsPage> {
  final _form = GlobalKey<FormState>();
  final _app = TextEditingController();
  final _client = TextEditingController();
  final _secret = TextEditingController();
  final _key = TextEditingController();
  String _env = 'sandbox';
  bool _enabled = true;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _recent = const [];
  String? _error;
  bool _saving = false;

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_app, _client, _secret, _key]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await OnlinePayRepo.settings();
      List<Map<String, dynamic>> recent = const [];
      try {
        recent = await OnlinePayRepo.list(purpose: 'INVOICE');
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _fill(d);
        _recent = recent;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _fill(Map<String, dynamic> d) {
    _data = d;
    _env = J.str(d['env'], 'sandbox');
    _enabled = J.boolean(d['enabled'], true);
    _app.text = J.str(d['appName']);
    _client.text = J.str(d['clientId']);
    _secret.text = J.str(d['clientSecret']);
    _key.text = J.str(d['apiKey']);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await runGuarded(() async {
      final d = await OnlinePayRepo.saveSettings({
        'env': _env,
        'appName': _app.text.trim(),
        'clientId': _client.text.trim(),
        'clientSecret': _secret.text,
        'apiKey': _key.text,
        'enabled': _enabled,
      });
      if (mounted) setState(() => _fill(d));
    }, success: 'payConnected'.tr);
    if (mounted) setState(() => _saving = false);
    if (ok) await _load();
  }

  Future<void> _disconnect() async {
    final ok = await confirmAction(
      title: 'payDisconnect'.tr,
      message: 'payDisconnectMsg'.tr,
      icon: Icons.link_off_rounded,
      danger: true,
    );
    if (!ok) return;
    if (await runGuarded(() async {
      final d = await OnlinePayRepo.clearSettings();
      if (mounted) setState(() => _fill(d));
    }, success: 'waDisconnected'.tr)) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = _data;
    return AppPage(
      title: 'payMobileTitle'.tr,
      subtitle: 'payPageSub'.tr,
      showBack: true,
      body: d == null
          ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const LoadingList(rows: 4))
          : PageScroll(
              onRefresh: _load,
              children: [
                SectionCard(
                  title: J.boolean(d['connected']) ? 'payStatusConnected'.tr : 'payStatusNotConnected'.tr,
                  subtitle: 'payStatusSub'.tr,
                  icon: Icons.phone_iphone_rounded,
                  trailing: Pill(
                    J.boolean(d['connected']) ? (J.boolean(d['enabled'], true) ? 'waOn'.tr : 'waOff'.tr) : 'waNotConnected'.tr,
                    color: J.boolean(d['connected']) && J.boolean(d['enabled'], true) ? p.success : p.warning,
                    dense: true,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('payCallbackUrl'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                      Row(children: [
                        Expanded(child: SelectableText(J.str(d['callbackUrl']), style: const TextStyle(fontSize: 12.5))),
                        IconButton(
                          tooltip: 'copy'.tr,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: J.str(d['callbackUrl'])));
                            Toast.success('copied'.tr);
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ]),
                      Text('payCallbackSecret'.tr, style: TextStyle(color: p.warning, fontSize: 12)),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'payAccount'.tr,
                  subtitle: 'payAccountSub'.tr,
                  icon: Icons.key_rounded,
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        AppDropdown<String>(
                          label: 'saAzamEnv'.tr,
                          value: _env,
                          items: const ['sandbox', 'live'],
                          itemLabel: (v) => v == 'live' ? 'payEnvLive'.tr : 'payEnvSandbox'.tr,
                          icon: Icons.science_outlined,
                          onChanged: _canEdit ? (v) => setState(() => _env = v ?? 'sandbox') : null,
                        ),
                        const SizedBox(height: 14),
                        AppField(controller: _app, label: 'App name', required: true, enabled: _canEdit,
                            validator: Validators.required),
                        const SizedBox(height: 14),
                        AppField(controller: _client, label: 'Client ID', required: true, enabled: _canEdit,
                            validator: Validators.required),
                        const SizedBox(height: 14),
                        AppField(controller: _secret, label: 'Client secret', required: true, obscure: true,
                            enabled: _canEdit, validator: Validators.required, helper: 'payHiddenHelp'.tr),
                        const SizedBox(height: 14),
                        AppField(controller: _key, label: 'API key (Token)', obscure: true, enabled: _canEdit,
                            helper: 'payApiKeyHelp'.tr),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _enabled,
                          title: Text('payEnabled'.tr),
                          subtitle: Text('payEnabledHelp'.tr),
                          onChanged: _canEdit ? (v) => setState(() => _enabled = v) : null,
                        ),
                        if (_canEdit) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              if (J.boolean(d['connected']))
                                TextButton.icon(
                                  onPressed: _disconnect,
                                  style: TextButton.styleFrom(foregroundColor: p.danger),
                                  icon: const Icon(Icons.link_off_rounded, size: 18),
                                  label: Text('payDisconnect'.tr),
                                ),
                              FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving ? const ButtonSpinner() : const Icon(Icons.save_rounded, size: 18),
                                label: Text('paySaveTest'.tr),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SectionCard(
                  title: 'waStepsTitle'.tr,
                  icon: Icons.checklist_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 1; i <= 5; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('$i. ${'payStep$i'.tr}', style: TextStyle(color: p.text, height: 1.4)),
                        ),
                    ],
                  ),
                ),
                if (_recent.isNotEmpty)
                  SectionCard(
                    title: 'payRecent'.tr,
                    icon: Icons.receipt_long_outlined,
                    child: Column(children: [for (final r in _recent.take(20)) _tile(context, r)]),
                  ),
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> r) {
    final p = context.palette;
    final status = J.str(r['status']);
    final color = switch (status) {
      'SUCCESS' => p.success,
      'FAILED' => p.danger,
      'EXPIRED' => p.muted,
      _ => p.warning,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.phone_iphone_rounded, color: color),
      title: Text('${Fmt.tsh(J.dbl(r['amount']))} · ${J.str(r['provider'])} ${Fmt.phone(J.str(r['msisdn']))}'),
      subtitle: Text([
        'payForInvoice'.trParams({'n': J.str(r['invoiceNumber'], '-')}),
        Fmt.dateTime(J.date(r['createdAt'])),
        if (J.strOrNull(r['username']) != null) J.str(r['username']),
        if (status != 'SUCCESS' && J.strOrNull(r['message']) != null) J.str(r['message']),
      ].join(' · ')),
      trailing: Pill('payStatus_$status'.tr, color: color, dense: true),
    );
  }
}
