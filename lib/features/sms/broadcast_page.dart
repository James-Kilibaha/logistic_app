import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/customer.dart';
import '../../data/models/ops.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../invoices/invoice_flows.dart';

/// Idadi ya SMS (vipande) kwa ujumbe: 160 herufi, au 153 kwa kila kipande zikizidi.
int smsSegments(String text) {
  final n = text.length;
  if (n <= 160) return 1;
  return (n / 153).ceil();
}

/// Ujumbe kwa wateja: mmoja, waliochaguliwa, wote au kundi (wenye mzigo stoo, wanaodaiwa ...).
class BroadcastPage extends StatefulWidget {
  /// Mteja aliyechaguliwa tayari (mf. kutoka ukurasa wa mteja).
  final Customer? customer;
  final Audience audience;
  final String? initialText;

  const BroadcastPage({super.key, this.customer, this.audience = Audience.all, this.initialText});

  static Future<void> open({Customer? customer, Audience? audience, String? text}) async {
    await Get.to(
      () => BroadcastPage(
        customer: customer,
        audience: audience ?? (customer != null ? Audience.one : Audience.all),
        initialText: text,
      ),
      preventDuplicates: false,
    );
  }

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  late Audience _audience = widget.audience;
  final List<Customer> _selected = [];
  Customer? _one;
  final _phone = TextEditingController();
  final _name = TextEditingController();
  late final TextEditingController _text = TextEditingController(text: widget.initialText ?? '');
  String _channel = 'SMS';
  bool _sendNow = true;
  bool _whatsApp = false;
  bool _busy = false;

  /// Kutuma kwa wateja wengi kunahitaji ruhusa ya BROADCAST; bila hiyo ni mteja mmoja tu.
  bool get _canMany => AppController.to.can(AppModule.broadcast, AppAction.insert);

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _one = widget.customer;
      _selected.add(widget.customer!);
    }
    if (!_canMany) _audience = Audience.one;
    _text.addListener(() => setState(() {}));
    if (!AppController.to.can(AppModule.whatsapp, AppAction.insert)) return;
    WhatsAppRepo.configured().then((ok) {
      if (mounted) setState(() => _whatsApp = ok);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  String _audienceLabel(Audience a) => 'aud_${a.code}'.tr;

  IconData _audienceIcon(Audience a) => switch (a) {
        Audience.all => Icons.groups_rounded,
        Audience.selected => Icons.checklist_rounded,
        Audience.one => Icons.person_rounded,
        Audience.inStore => Icons.warehouse_outlined,
        Audience.overdue => Icons.hourglass_bottom_rounded,
        Audience.debt => Icons.account_balance_outlined,
      };

  /// Kama walengwa wamekamilika (kabla ya kuuliza server).
  String? _missing() {
    if (_text.text.trim().isEmpty) return 'writeMessageFirst'.tr;
    if (_audience == Audience.selected && _selected.isEmpty) return 'chooseCustomersFirst'.tr;
    if (_audience == Audience.one && _one == null) {
      if (_phone.text.trim().isEmpty) return 'chooseOneFirst'.tr;
      if (Phone.normalize(_phone.text) == null) return 'invalidPhoneFormat'.tr;
    }
    return null;
  }

  Future<BroadcastPreview?> _preview() async {
    final missing = _missing();
    if (missing != null) {
      Toast.warning(missing);
      return null;
    }
    try {
      return await SmsRepo.broadcastPreview(
        audience: _audience,
        text: _text.text,
        customerIds: _selected.map((c) => c.id).toList(),
        customerId: _audience == Audience.one ? _one?.id : null,
        phone: _audience == Audience.one && _one == null ? Phone.forApi(_phone.text) : null,
        name: _audience == Audience.one && _one == null ? _name.text : null,
      );
    } catch (e) {
      Toast.error(e);
      return null;
    }
  }

  Future<void> _showPreview() async {
    setState(() => _busy = true);
    final preview = await _preview();
    if (mounted) setState(() => _busy = false);
    if (preview == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _PreviewDialog(preview: preview, channel: _channel),
    );
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final preview = await _preview();
    if (!mounted) return;
    setState(() => _busy = false);
    if (preview == null) return;
    if (preview.count == 0) {
      Toast.warning('noRecipients'.tr);
      return;
    }
    final perPerson = _channel == 'BOTH' ? 2 : 1;
    final ok = await confirmAction(
      title: 'sendMessageQ'.tr,
      message: 'sendToNMsg'.trParams({
        'n': Fmt.number(preview.count),
        'sms': Fmt.number(_channel == 'WHATSAPP' ? preview.count : preview.totalSms * perPerson),
        'channel': 'ch_$_channel'.tr,
      }),
      confirmText: 'send'.tr,
      icon: Icons.send_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await runGuarded(() async {
      final n = await SmsRepo.broadcast(
        audience: _audience,
        text: _text.text,
        customerIds: _selected.map((c) => c.id).toList(),
        customerId: _audience == Audience.one ? _one?.id : null,
        phone: _audience == Audience.one && _one == null ? Phone.forApi(_phone.text) : null,
        name: _audience == Audience.one && _one == null ? _name.text : null,
        channel: _channel,
        sendNow: _sendNow,
      );
      Toast.success(
        _sendNow ? 'broadcastSent'.trParams({'n': Fmt.number(n)}) : 'broadcastSaved'.trParams({'n': Fmt.number(n)}),
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      AppController.to.notifyChanged();
      Get.back();
    }
  }

  Future<void> _pickMany() async {
    final picked = await showDialog<List<Customer>>(
      context: context,
      builder: (_) => _MultiCustomerPicker(initial: _selected),
    );
    if (picked != null && mounted) {
      setState(() => _selected
        ..clear()
        ..addAll(picked));
    }
  }

  Future<void> _pickOne() async {
    final c = await InvoiceFlows.pickCustomer();
    if (c != null && mounted) setState(() => _one = c);
  }

  void _insert(String token) {
    final sel = _text.selection;
    final text = _text.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _text.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sample = _text.text.replaceAll('{jina}', 'Juma');
    final segments = smsSegments(sample);

    return AppPage(
      title: 'broadcastTitle'.tr,
      subtitle: 'broadcastSub'.tr,
      showBack: true,
      help: 'broadcast',
      body: PageScroll(
        children: [
          SectionCard(
            title: 'whoReceives'.tr,
            icon: Icons.groups_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in Audience.values)
                      if (_canMany || a == Audience.one)
                      ChoiceChip(
                        avatar: Icon(_audienceIcon(a), size: 18),
                        label: Text(_audienceLabel(a)),
                        selected: _audience == a,
                        onSelected: (_) => setState(() => _audience = a),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('aud_${_audience.code}_hint'.tr, style: TextStyle(color: p.muted, fontSize: 13)),
                if (_audience == Audience.selected) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in _selected)
                        InputChip(
                          label: Text(c.name),
                          onDeleted: () => setState(() => _selected.remove(c)),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: Text(_selected.isEmpty ? 'chooseCustomers'.tr : 'addOrRemove'.tr),
                        onPressed: _pickMany,
                      ),
                    ],
                  ),
                ],
                if (_audience == Audience.one) ...[
                  const SizedBox(height: 12),
                  if (_one != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: p.primarySoft, child: Icon(Icons.person, color: p.primary)),
                      title: Text(_one!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(Fmt.phone(_one!.phoneNumber)),
                      trailing: IconButton(
                        tooltip: 'remove'.tr,
                        onPressed: () => setState(() => _one = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _pickOne,
                      icon: const Icon(Icons.person_search_rounded),
                      label: Text('chooseCustomer'.tr),
                    ),
                    const SizedBox(height: 10),
                    Text('orTypeNumber'.tr, style: TextStyle(color: p.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    FieldRow(children: [
                      PhoneField(controller: _phone, label: 'phone'.tr, onChanged: (_) => setState(() {})),
                      AppField(controller: _name, label: 'nameOptional'.tr, icon: Icons.badge_outlined),
                    ]),
                  ],
                ],
              ],
            ),
          ),
          SectionCard(
            title: 'message'.tr,
            icon: Icons.edit_note_rounded,
            trailing: Text(
              'smsCounter'.trParams({'c': '${sample.length}', 's': '$segments'}),
              style: TextStyle(color: segments > 1 ? p.warning : p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _text,
                  maxLines: 8,
                  minLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(hintText: 'broadcastHint'.tr),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.person_pin_outlined, size: 18),
                      label: Text('insertName'.tr),
                      onPressed: () => _insert('{jina}'),
                    ),
                    for (final t in const ['tplArrived', 'tplHoliday', 'tplPay', 'tplNewRate'])
                      ActionChip(
                        label: Text('${t}_label'.tr),
                        onPressed: () => _text.text = t.tr,
                      ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'sendVia'.tr,
            icon: Icons.send_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'SMS', label: Text('ch_SMS'.tr), icon: const Icon(Icons.sms_outlined)),
                    ButtonSegment(
                      value: 'WHATSAPP',
                      label: Text('ch_WHATSAPP'.tr),
                      icon: const Icon(Icons.chat_outlined),
                      enabled: _whatsApp,
                    ),
                    ButtonSegment(
                      value: 'BOTH',
                      label: Text('ch_BOTH'.tr),
                      icon: const Icon(Icons.forum_outlined),
                      enabled: _whatsApp,
                    ),
                  ],
                  selected: {_channel},
                  onSelectionChanged: (v) => setState(() => _channel = v.first),
                ),
                if (!_whatsApp)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('whatsAppNotSet'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sendNow,
                  onChanged: (v) => setState(() => _sendNow = v),
                  title: Text('sendNow'.tr),
                  subtitle: Text(_sendNow ? 'sendNowHint'.tr : 'sendLaterHint'.tr),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _showPreview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text('previewRecipients'.tr),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _send,
                        icon: _busy ? const ButtonSpinner() : const Icon(Icons.send_rounded),
                        label: Text('send'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  final BroadcastPreview preview;
  final String channel;

  const _PreviewDialog({required this.preview, required this.channel});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Text('recipientsN'.trParams({'n': Fmt.number(preview.count)})),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(context).height * .6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (channel != 'WHATSAPP')
              Text('smsTotalN'.trParams({'n': Fmt.number(preview.totalSms), 's': '${preview.segments}'}),
                  style: TextStyle(color: p.muted)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Text(preview.sample, style: TextStyle(color: p.text, height: 1.4)),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in preview.recipients)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline_rounded, size: 20),
                      title: Text(r.name.isEmpty ? '-' : r.name),
                      trailing: Text(Fmt.phone(r.phone)),
                    ),
                  if (preview.count > preview.recipients.length)
                    Text('andNMore'.trParams({'n': '${preview.count - preview.recipients.length}'}),
                        style: TextStyle(color: p.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr))],
    );
  }
}

/// Kuchagua wateja wengi (kutafuta + alama ya kuchagua).
class _MultiCustomerPicker extends StatefulWidget {
  final List<Customer> initial;

  const _MultiCustomerPicker({required this.initial});

  @override
  State<_MultiCustomerPicker> createState() => _MultiCustomerPickerState();
}

class _MultiCustomerPickerState extends State<_MultiCustomerPicker> {
  final _search = TextEditingController();
  late final Map<String, Customer> _picked = {for (final c in widget.initial) c.id: c};
  List<Customer> _list = const [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _list = await CustomerRepo.search(query: _search.text, active: 1, limit: 100);
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('chooseCustomers'.tr,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                  ),
                  Pill('${_picked.length}', color: p.primary),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _load);
                },
                decoration: InputDecoration(
                  hintText: 'searchCustomerHint'.tr,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in _list)
                          CheckboxListTile(
                            value: _picked.containsKey(c.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _picked[c.id] = c;
                              } else {
                                _picked.remove(c.id);
                              }
                            }),
                            title: Text(c.name),
                            subtitle: Text(Fmt.phone(c.phoneNumber)),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      for (final c in _list) {
                        _picked[c.id] = c;
                      }
                    }),
                    child: Text('selectAllShown'.tr),
                  ),
                  const Spacer(),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_picked.values.toList()),
                    child: Text('doneSelecting'.tr),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
