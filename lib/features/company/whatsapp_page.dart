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

/// Kuunganisha WhatsApp Business ya kampuni hii (Meta Cloud API): hatua, taarifa, webhook, majaribio.
class WhatsappPage extends StatefulWidget {
  const WhatsappPage({super.key});

  @override
  State<WhatsappPage> createState() => _WhatsappPageState();
}

class _WhatsappPageState extends State<WhatsappPage> {
  Map<String, dynamic>? _data;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _saving = false;
  bool _enabled = true;
  List<Map<String, dynamic>>? _templates;

  final _phoneId = TextEditingController();
  final _waba = TextEditingController();
  final _token = TextEditingController();
  final _secret = TextEditingController();
  final _template = TextEditingController();
  final _docTemplate = TextEditingController();
  final _imageTemplate = TextEditingController();
  final _lang = TextEditingController();

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_phoneId, _waba, _token, _secret, _template, _docTemplate, _imageTemplate, _lang]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> d) {
    _phoneId.text = J.str(d['phoneNumberId']);
    _waba.text = J.str(d['businessAccountId']);
    _token.text = J.str(d['accessToken']);
    _secret.text = J.str(d['appSecret']);
    _template.text = J.str(d['template']);
    _docTemplate.text = J.str(d['documentTemplate']);
    _imageTemplate.text = J.str(d['imageTemplate']);
    _lang.text = J.str(d['language']);
    // bado haijaunganishwa: washa kwa kawaida; vinginevyo hali iliyohifadhiwa
    _enabled = J.str(d['phoneNumberId']).isEmpty || J.boolean(d['enabled']);
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final d = await CompanyRepo.whatsapp();
      _fill(d);
      setState(() {
        _data = d;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  void _apply(Map<String, dynamic> d) {
    _fill(d);
    setState(() => _data = d);
  }

  Future<void> _save() async {
    if (_phoneId.text.trim().length < 5 || _token.text.trim().isEmpty) {
      Toast.warning('waNeedIds'.tr);
      return;
    }
    setState(() => _saving = true);
    await runGuarded(() async {
      _apply(await CompanyRepo.whatsappConnect({
        'phoneNumberId': _phoneId.text.trim(),
        'accessToken': _token.text.trim(),
        'businessAccountId': _waba.text.trim(),
        'appSecret': _secret.text.trim(),
        'template': _template.text.trim(),
        'documentTemplate': _docTemplate.text.trim(),
        'imageTemplate': _imageTemplate.text.trim(),
        'language': _lang.text.trim(),
        'enabled': _enabled,
      }));
    }, success: 'waConnected'.tr);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _test() async {
    await runGuarded(() async => _apply(await CompanyRepo.whatsappTest()));
    final st = J.map(_data?['status']) ?? const {};
    if (st['ok'] == true) {
      Toast.success('${J.str(st['displayPhone'])} · ${J.str(st['verifiedName'])}', title: 'waTestOk'.tr);
    } else if (st['error'] != null) {
      Toast.warning(J.str(st['error']), title: 'waTestFailed'.tr);
    }
  }

  Future<void> _loadTemplates() async {
    final ok = await runGuarded(() async {
      final list = await CompanyRepo.whatsappTemplates();
      setState(() => _templates = list);
    });
    if (ok && (_templates?.isEmpty ?? true)) Toast.info('waNoTemplates'.tr);
  }

  Future<void> _sendTest() async {
    final phone = TextEditingController();
    final text = TextEditingController();
    final ok = await showFormSheet(
      title: 'waSendTest'.tr,
      subtitle: 'waSendTestSub'.tr,
      icon: Icons.send_rounded,
      submitLabel: 'waSend'.tr,
      builder: (context, setState) => Column(
        children: [
          PhoneField(controller: phone, required: true),
          const SizedBox(height: 14),
          AppField(controller: text, label: 'waMessage'.tr, hint: 'waMessageHint'.tr, maxLines: 3, minLines: 2),
        ],
      ),
      onSubmit: () => CompanyRepo.whatsappTestMessage(Phone.normalize(phone.text) ?? phone.text.trim(), text.text.trim()),
    );
    if (ok) Toast.success('waSentMsg'.tr, title: 'waSent'.tr);
  }

  Future<void> _disconnect() async {
    final sure = await confirmAction(
      title: 'waDisconnect'.tr,
      message: 'waDisconnectMsg'.tr,
      confirmText: 'waDisconnect'.tr,
      icon: Icons.link_off_rounded,
      danger: true,
    );
    if (!sure) return;
    await runGuarded(() async => _apply(await CompanyRepo.whatsappDisconnect()), success: 'waDisconnected'.tr);
  }

  Future<void> _rotate() async {
    final sure = await confirmAction(
      title: 'waRotateToken'.tr,
      message: 'waRotateTokenMsg'.tr,
      confirmText: 'waRotateToken'.tr,
      icon: Icons.autorenew_rounded,
    );
    if (!sure) return;
    await runGuarded(() async => _apply(await CompanyRepo.whatsappRotateToken()), success: 'saved'.tr);
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    Toast.success(value, title: 'copied'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'whatsappSettings'.tr,
      subtitle: 'waPageSub'.tr,
      showBack: true,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _status == LoadStatus.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded)),
      ],
      body: _data == null
          ? (_status == LoadStatus.error
              ? ErrorState(message: _error ?? 'errUnknown'.tr, onRetry: _load)
              : const LoadingList())
          : _content(context, _data!),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> d) {
    final p = context.palette;
    final st = J.map(d['status']) ?? const {};
    final connected = J.boolean(d['connected']);
    final inPlan = J.boolean(d['inPlan'], true);
    final enabled = _canEdit && inPlan;

    Widget copyRow(String label, String value, IconData icon) => InfoRow(
          label: label,
          value: value,
          icon: icon,
          trailing: IconButton(
              tooltip: 'copy'.tr, icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () => _copy(value)),
        );

    final status = SectionCard(
      title: connected ? 'waStatusConnected'.tr : 'waStatusNotConnected'.tr,
      subtitle: connected ? 'waStatusConnectedSub'.tr : 'waStatusNotConnectedSub'.tr,
      icon: connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
      trailing: Pill(connected ? (J.boolean(d['enabled']) ? 'waOn'.tr : 'waOff'.tr) : 'waNotConnected'.tr,
          color: connected ? (J.boolean(d['enabled']) ? p.success : p.warning) : p.muted, dense: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!inPlan)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('waNotInPlan'.tr, style: TextStyle(color: p.warning, height: 1.4)),
            ),
          if (st['displayPhone'] != null) InfoRow(label: 'waNumber'.tr, value: J.str(st['displayPhone']), icon: Icons.call_outlined),
          if (st['verifiedName'] != null)
            InfoRow(label: 'waVerifiedName'.tr, value: J.str(st['verifiedName']), icon: Icons.verified_outlined),
          if (st['quality'] != null) InfoRow(label: 'waQuality'.tr, value: J.str(st['quality']), icon: Icons.speed_rounded),
          if (st['checkedAt'] != null)
            InfoRow(label: 'waCheckedAt'.tr, value: Fmt.dateTime(J.date(st['checkedAt'])), icon: Icons.schedule_rounded),
          if (st['ok'] == false && st['error'] != null)
            Text(J.str(st['error']), style: TextStyle(color: p.danger, fontSize: 13)),
          if (connected && _canEdit) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _test, icon: const Icon(Icons.network_check_rounded, size: 18),
                  label: Text('waTest'.tr)),
              OutlinedButton.icon(onPressed: inPlan ? _sendTest : null, icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('waSendTest'.tr)),
              TextButton.icon(
                onPressed: _disconnect,
                style: TextButton.styleFrom(foregroundColor: p.danger),
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: Text('waDisconnect'.tr),
              ),
            ]),
          ],
        ],
      ),
    );

    final steps = SectionCard(
      title: 'waStepsTitle'.tr,
      subtitle: 'waStepsSub'.tr,
      icon: Icons.checklist_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 1; i <= 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: p.primarySoft,
                    child: Text('$i', style: TextStyle(color: p.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('waStep$i'.tr, style: TextStyle(color: p.text, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );

    final webhook = SectionCard(
      title: 'waWebhook'.tr,
      subtitle: 'waWebhookSub'.tr,
      icon: Icons.webhook_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          copyRow('waCallbackUrl'.tr, J.str(d['webhookUrl']), Icons.link_rounded),
          copyRow('waVerifyToken'.tr, J.str(d['verifyToken']), Icons.key_rounded),
          const SizedBox(height: 6),
          Text('waWebhookFields'.tr, style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4)),
          if (_canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _rotate,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: Text('waRotateToken'.tr),
              ),
            ),
        ],
      ),
    );

    final form = SectionCard(
      title: 'waAccount'.tr,
      subtitle: 'waAccountSub'.tr,
      icon: Icons.settings_input_antenna_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: _phoneId, label: 'Phone Number ID', hint: '1234567890123', required: true,
              enabled: enabled, keyboardType: TextInputType.number, icon: Icons.numbers_rounded),
          const SizedBox(height: 14),
          AppField(controller: _waba, label: 'WhatsApp Business Account ID (WABA)', helper: 'waWabaHelp'.tr,
              enabled: enabled, keyboardType: TextInputType.number, icon: Icons.business_rounded),
          const SizedBox(height: 14),
          AppField(controller: _token, label: 'Access Token', helper: 'waTokenHelp'.tr, required: true,
              enabled: enabled, obscure: true, icon: Icons.vpn_key_outlined),
          const SizedBox(height: 14),
          AppField(controller: _secret, label: 'App Secret', helper: 'waSecretHelp'.tr, enabled: enabled,
              obscure: true, icon: Icons.lock_outline_rounded),
          const SizedBox(height: 18),
          Text('waTemplates'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
          Text('waTemplatesHelp'.tr, style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 10),
          AppField(controller: _template, label: 'waTplText'.tr, hint: 'taarifa_kwa_mteja', enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _docTemplate, label: 'waTplDoc'.tr, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _imageTemplate, label: 'waTplImage'.tr, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _lang, label: 'setWaLang'.tr, hint: 'sw / en / en_US', enabled: enabled),
          if (_templates != null && _templates!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _templates!)
                  ActionChip(
                    avatar: Icon(J.str(t['status']) == 'APPROVED' ? Icons.check_circle_rounded : Icons.pending_outlined,
                        size: 16, color: J.str(t['status']) == 'APPROVED' ? p.success : p.warning),
                    label: Text('${J.str(t['name'])} · ${J.str(t['language'])}'
                        '${t['header'] == null ? '' : ' · ${J.str(t['header'])}'}'),
                    onPressed: !enabled
                        ? null
                        : () {
                            // template yenye DOCUMENT -> PDF, IMAGE -> picha, nyingine -> ujumbe wa kawaida
                            final header = J.str(t['header']);
                            final target = header == 'DOCUMENT'
                                ? _docTemplate
                                : (header == 'IMAGE' ? _imageTemplate : _template);
                            setState(() {
                              target.text = J.str(t['name']);
                              _lang.text = J.str(t['language']);
                            });
                          },
                  ),
              ],
            ),
          ],
          if (enabled) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _waba.text.trim().isEmpty || !connected ? null : _loadTemplates,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('waLoadTemplates'.tr),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('setWaEnabled'.tr),
              subtitle: Text('waEnabledHelp'.tr),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const ButtonSpinner() : const Icon(Icons.link_rounded, size: 18),
              label: Text(connected ? 'waSaveTest'.tr : 'waConnect'.tr),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 900) return PageScroll(onRefresh: _load, children: [status, form, webhook, steps]);
      Widget column(List<Widget> items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (int i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i]]],
          );
      return PageScroll(onRefresh: _load, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: column([status, form])),
          const SizedBox(width: 16),
          Expanded(child: column([webhook, steps])),
        ]),
      ]);
    });
  }
}
