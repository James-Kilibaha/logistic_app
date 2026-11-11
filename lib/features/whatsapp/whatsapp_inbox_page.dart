import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// Inbox ya WhatsApp: mazungumzo na wateja (majibu yao + majibu yenu).
/// Skrini pana: orodha + mazungumzo pembeni. Simu: orodha -> mazungumzo (ukurasa mpya).
class WhatsappInboxPage extends StatefulWidget {
  const WhatsappInboxPage({super.key});

  /// Kufungua mazungumzo ya namba moja moja kwa moja (mf. kutoka kwenye taarifa).
  static Future<void> openThread(String phone) async {
    await Get.to(() => WhatsappThreadPage(phone: phone, standalone: true));
  }

  @override
  State<WhatsappInboxPage> createState() => _WhatsappInboxPageState();
}

class _WhatsappInboxPageState extends State<WhatsappInboxPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  String? _selected;
  Timer? _timer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _status = LoadStatus.loading);
    try {
      final items = await WhatsappInboxRepo.conversations(q: _search.text);
      if (!mounted) return;
      setState(() {
        _items = items;
        _status = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!quiet) {
        setState(() {
          _status = LoadStatus.error;
          _error = e.toString();
        });
      }
    }
  }

  void _open(String phone, bool wide) {
    if (wide) {
      setState(() => _selected = phone);
      // kiashiria cha "hazijasomwa" kinaondoka (backend inaweka imesomwa thread ikifunguliwa)
      Future<void>.delayed(const Duration(seconds: 1), () => _load(quiet: true));
    } else {
      Get.to(() => WhatsappThreadPage(phone: phone, standalone: true))?.then((_) => _load(quiet: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isMediumUp;
    final unread = _items.fold<int>(0, (a, c) => a + J.integer(c['unread']));
    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SearchBox(
            controller: _search,
            hint: 'waInboxSearch'.tr,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () => _load(quiet: true));
            },
          ),
        ),
        Expanded(
          child: AsyncBody(
            status: _status,
            error: _error,
            isEmpty: _items.isEmpty,
            onRetry: _load,
            empty: EmptyState(
              icon: Icons.forum_outlined,
              title: 'waInboxEmpty'.tr,
              message: 'waInboxEmptyMsg'.tr,
            ),
            builder: () => RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = _items[i];
                  final phone = J.str(c['phone']);
                  return _ConversationTile(
                    data: c,
                    selected: wide && phone == _selected,
                    onTap: () => _open(phone, wide),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );

    return AppPage(
      title: 'waInbox'.tr,
      subtitle: unread > 0 ? 'waInboxUnreadN'.trParams({'n': '$unread'}) : 'waInboxSub'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: !wide
          ? list
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 360, child: list),
                VerticalDivider(width: 1, color: context.palette.border),
                Expanded(
                  child: _selected == null
                      ? EmptyState(icon: Icons.chat_outlined, title: 'waInboxPick'.tr)
                      : WhatsappThreadPage(key: ValueKey(_selected), phone: _selected!),
                ),
              ],
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selected;
  final VoidCallback onTap;

  const _ConversationTile({required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final phone = J.str(data['phone']);
    final title = J.strOrNull(data['customerName']) ?? J.strOrNull(data['name']) ?? phone;
    final unread = J.integer(data['unread']);
    final mine = J.str(data['lastDirection']) == 'OUT';
    final text = J.str(data['lastText']);
    return ListTile(
      selected: selected,
      selectedTileColor: p.primarySoft,
      onTap: onTap,
      leading: Initials(title),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(
        '${mine ? '${'waInboxYou'.tr}: ' : ''}$text',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unread > 0 ? p.text : p.muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Fmt.relative(J.date(data['lastAt'])), style: TextStyle(color: p.muted, fontSize: 11.5)),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: p.success, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          else if (J.boolean(data['windowOpen']))
            Icon(Icons.schedule_rounded, size: 14, color: p.success),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------- mazungumzo

class WhatsappThreadPage extends StatefulWidget {
  final String phone;

  /// true = ukurasa kamili (simu / kutoka kwenye taarifa); false = ndani ya inbox (skrini pana).
  final bool standalone;

  const WhatsappThreadPage({super.key, required this.phone, this.standalone = false});

  @override
  State<WhatsappThreadPage> createState() => _WhatsappThreadPageState();
}

class _WhatsappThreadPageState extends State<WhatsappThreadPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _sending = false;
  Timer? _timer;
  int _count = 0;

  bool get _canReply => AppController.to.can(AppModule.whatsapp, AppAction.insert);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _messages =>
      (_data?['messages'] is List ? _data!['messages'] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load({bool quiet = false}) async {
    try {
      final d = await WhatsappInboxRepo.thread(widget.phone);
      if (!mounted) return;
      final before = _count;
      setState(() {
        _data = d;
        _error = null;
        _count = _messages.length;
      });
      if (_count != before) _toBottom();
    } catch (e) {
      if (!mounted || quiet) return;
      setState(() => _error = e.toString());
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await runGuarded(() => WhatsappInboxRepo.reply(widget.phone, text));
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _text.clear();
      await _load(quiet: true);
    }
  }

  Future<void> _openMedia(Map<String, dynamic> m) async {
    final id = J.str(m['id']);
    final mime = J.str(m['mimeType']);
    final name = J.strOrNull(m['fileName']) ?? 'whatsapp_${id.substring(0, 8)}';
    if (mime.contains('pdf')) {
      await openPdfFrom(() => WhatsappInboxRepo.media(id), title: name, fileName: name.replaceAll('.pdf', ''));
      return;
    }
    if (!mime.startsWith('image/')) {
      Toast.info('waInboxMediaUnsupported'.trParams({'type': mime.isEmpty ? J.str(m['kind']) : mime}));
      return;
    }
    Uint8List? bytes;
    final ok = await runGuarded(() async => bytes = await WhatsappInboxRepo.media(id));
    if (!ok || bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes!, fit: BoxFit.contain)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = _data;
    final title = J.strOrNull(d?['customerName']) ?? J.strOrNull(d?['name']) ?? widget.phone;
    final body = d == null
        ? (_error != null ? ErrorState(message: _error!, onRetry: _load) : const LoadingList(rows: 4))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.standalone) _header(context, title, d),
              _windowBanner(context, d),
              Expanded(
                child: _messages.isEmpty
                    ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'waInboxNoMessages'.tr)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _Bubble(message: _messages[i], onOpenMedia: _openMedia),
                      ),
              ),
              if (_canReply) _composer(context, d) else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('waInboxNoPermission'.tr, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                ),
            ],
          );
    if (!widget.standalone) return Container(color: p.background, child: body);
    return AppPage(
      title: title,
      subtitle: [widget.phone, if (J.strOrNull(d?['name']) != null && J.str(d?['name']) != title) J.str(d?['name'])].join(' · '),
      showBack: true,
      actions: [IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      body: body,
    );
  }

  Widget _header(BuildContext context, String title, Map<String, dynamic> d) {
    final p = context.palette;
    final name = J.strOrNull(d['name']);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: p.surface, border: Border(bottom: BorderSide(color: p.border))),
      child: Row(
        children: [
          Initials(title, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text([widget.phone, if (name != null && name != title) name].join(' · '),
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ),
          ),
          IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
    );
  }

  Widget _windowBanner(BuildContext context, Map<String, dynamic> d) {
    final p = context.palette;
    final open = J.boolean(d['windowOpen']);
    final until = J.date(d['windowUntil']);
    final template = J.boolean(d['hasTemplate']);
    final color = open ? p.success : (template ? p.info : p.warning);
    final text = open
        ? 'waWindowOpen'.trParams({'t': Fmt.dateTime(until)})
        : (template ? 'waWindowTemplate'.tr : 'waWindowClosed'.tr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withValues(alpha: .10),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open_rounded : Icons.lock_clock_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: p.text, fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, Map<String, dynamic> d) {
    final p = context.palette;
    final blocked = !J.boolean(d['windowOpen']) && !J.boolean(d['hasTemplate']);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                enabled: !blocked && !_sending,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: blocked ? 'waWindowClosedShort'.tr : 'waInboxTypeReply'.tr,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'waSend'.tr,
              onPressed: blocked || _sending ? null : _send,
              icon: _sending ? const ButtonSpinner() : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final Future<void> Function(Map<String, dynamic>) onOpenMedia;

  const _Bubble({required this.message, required this.onOpenMedia});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = J.str(message['direction']) == 'OUT';
    final system = J.str(message['source']) == 'SYSTEM';
    final status = J.str(message['status']);
    final error = J.strOrNull(message['error']);
    final kind = J.str(message['kind']);
    final text = J.strOrNull(message['text']);
    final by = J.strOrNull(message['byName']);
    final meta = [
      if (system) 'waInboxSystem'.tr,
      if (by != null) by,
      Fmt.relative(J.date(message['at'])),
    ].join(' · ');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? (system ? p.surfaceAlt : p.primarySoft) : p.surface,
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (J.boolean(message['hasMedia']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenMedia(message),
                    icon: Icon(switch (kind) {
                      'image' || 'sticker' => Icons.image_outlined,
                      'document' => Icons.description_outlined,
                      'audio' => Icons.mic_none_rounded,
                      'video' => Icons.videocam_outlined,
                      _ => Icons.attach_file_rounded,
                    }, size: 18),
                    label: Text(J.strOrNull(message['fileName']) ?? 'waInboxOpenMedia'.tr),
                  ),
                ),
              if (text != null && text.isNotEmpty)
                SelectableText(text, style: TextStyle(color: p.text, height: 1.35))
              else if (!J.boolean(message['hasMedia']))
                Text('[$kind]', style: TextStyle(color: p.muted, fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(meta, style: TextStyle(color: p.muted, fontSize: 11))),
                  if (mine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      switch (status) {
                        'READ' => Icons.done_all_rounded,
                        'DELIVERED' => Icons.done_all_rounded,
                        'FAILED' => Icons.error_outline_rounded,
                        _ => Icons.done_rounded,
                      },
                      size: 14,
                      color: status == 'READ' ? p.info : (status == 'FAILED' ? p.danger : p.muted),
                    ),
                  ],
                ],
              ),
              if (mine && status == 'FAILED' && error != null)
                Text(error, style: TextStyle(color: p.danger, fontSize: 11.5)),
            ],
          ),
        ),
      ),
    );
  }
}
