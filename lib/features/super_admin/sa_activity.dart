import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Kitendo kimoja kwenye kampuni (kutoka audit log).
class ActivityEntry {
  final String id;
  final DateTime? at;
  final String? companyId;
  final String companyName;
  final String? companySlug;
  final String? username;
  final String module;
  final String action;
  final String method;
  final String path;
  final String? entityId;
  final int status;
  final String? ip;
  final String? summary;

  /// APP / WEB / API na kifaa (mf. "Samsung SM-A515F · Android 13").
  final String? client;
  final String? device;

  const ActivityEntry({
    required this.id,
    this.at,
    this.companyId,
    required this.companyName,
    this.companySlug,
    this.username,
    required this.module,
    required this.action,
    required this.method,
    required this.path,
    this.entityId,
    required this.status,
    this.ip,
    this.summary,
    this.client,
    this.device,
  });

  bool get failed => status >= 400;

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: J.str(j['id']),
        at: J.date(j['created_at']),
        companyId: J.strOrNull(j['company_id']),
        companyName: J.str(j['companyName'], '-'),
        companySlug: J.strOrNull(j['companySlug']),
        username: J.strOrNull(j['username']),
        module: J.str(j['module']),
        action: J.str(j['action']),
        method: J.str(j['method']),
        path: J.str(j['path']),
        entityId: J.strOrNull(j['entity_id']),
        status: J.integer(j['status_code']),
        ip: J.strOrNull(j['ip']),
        summary: J.strOrNull(j['summary']),
        client: J.strOrNull(j['client']),
        device: J.strOrNull(j['device']),
      );

  /// "App · Samsung SM-A515F · Android 13" / "Web · Chrome 130 · Windows 10/11"
  String? get deviceLabel {
    final kind = switch (client) { 'APP' => 'App', 'WEB' => 'Web', 'API' => 'API', _ => null };
    final parts = [if (kind != null) kind, if (device != null && device!.isNotEmpty) device!];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get title => summary ?? '$action ${module.replaceAll('/', ' › ')}';
}

IconData _icon(String action) => switch (action) {
      'LOGIN' => Icons.login_rounded,
      'LOGOUT' => Icons.logout_rounded,
      'CREATE' => Icons.add_circle_outline_rounded,
      'UPDATE' => Icons.edit_outlined,
      'DELETE' => Icons.delete_outline_rounded,
      'BLOCK' => Icons.block_rounded,
      'VIEW_AS' => Icons.admin_panel_settings_outlined,
      'VIEW' => Icons.visibility_outlined,
      _ => Icons.bolt_rounded,
    };

/// Orodha ya shughuli (kampuni zote, au moja ikiwa [companyId] imewekwa). Inapakia zaidi ukibonyeza "Zaidi".
class ActivityFeed extends StatefulWidget {
  final String? companyId;

  /// Idadi ya kwanza (dashboard/kampuni moja: chache; ukurasa wa shughuli: nyingi).
  final int pageSize;

  /// Kuonyesha jina la kampuni kwenye kila mstari (kampuni zote).
  final bool showCompany;

  /// Kuonyesha kisanduku cha kutafuta na vichujio.
  final bool filters;

  const ActivityFeed({super.key, this.companyId, this.pageSize = 50, this.showCompany = true, this.filters = true});

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  final _search = TextEditingController();
  Timer? _debounce;
  final List<ActivityEntry> _items = [];
  int _total = 0;
  bool _loading = true;
  bool? _failed;

  /// null = zote, 'views' = kurasa walizofungua, 'actions' = vitendo (kuongeza, kubadilisha ...)
  String? _kind;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await PlatformApi.get('activity', query: {
        'company_id': widget.companyId,
        'q': _search.text.trim(),
        'failed': _failed,
        'kind': _kind,
        'offset': reset ? 0 : _items.length,
        'limit': widget.pageSize,
      });
      final map = Map<String, dynamic>.from(body as Map);
      final rows = J.list(map['items'], ActivityEntry.fromJson);
      setState(() {
        if (reset) _items.clear();
        _items.addAll(rows);
        _total = J.integer(map['total']);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  void _details(ActivityEntry e) {
    final ctx = Get.overlayContext ?? context;
    showDialog<void>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(e.title),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'saCompany'.tr, value: '${e.companyName}${e.companySlug == null ? '' : ' (${e.companySlug})'}'),
              InfoRow(label: 'username'.tr, value: e.username ?? '-'),
              InfoRow(label: 'saWhen'.tr, value: Fmt.dateTime(e.at)),
              InfoRow(label: 'saAction'.tr, value: '${e.action} · ${e.module}'),
              InfoRow(label: 'saRequest'.tr, value: '${e.method} ${e.path}'),
              InfoRow(label: 'saResult'.tr, value: '${e.status}', emphasize: e.failed),
              if (e.entityId != null) InfoRow(label: 'ID', value: e.entityId!),
              if (e.ip != null) InfoRow(label: 'IP', value: e.ip!),
              if (e.deviceLabel != null) InfoRow(label: 'auditDevice'.tr, value: e.deviceLabel!),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('close'.tr))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.filters) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => _searchSoon(),
                  decoration: InputDecoration(
                    hintText: 'saSearchActivity'.tr,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              for (final (String? value, String label) in [
                (null, 'saAll'.tr),
                ('views', 'saPagesOpened'.tr),
                ('actions', 'saActionsOnly'.tr),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _kind == value,
                  onSelected: (_) {
                    _kind = value;
                    _load(reset: true);
                  },
                ),
              const SizedBox(width: 6),
              for (final (bool? value, String label) in [
                (false, 'saSucceeded'.tr),
                (true, 'saFailed'.tr),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _failed == value,
                  onSelected: (_) {
                    _failed = _failed == value ? null : value; // bonyeza tena kuondoa kichujio
                    _load(reset: true);
                  },
                ),
              IconButton(
                tooltip: 'refresh'.tr,
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_items.isEmpty && _loading)
          const LoadingList()
        else if (_items.isEmpty && _error != null)
          ErrorState(message: _error!, onRetry: () => _load(reset: true))
        else if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('saNoActivity'.tr, style: TextStyle(color: p.muted)),
          )
        else ...[
          for (final e in _items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () => _details(e),
              leading: Icon(_icon(e.action),
                  color: e.failed ? p.danger : (e.action == 'VIEW_AS' ? p.info : (e.action == 'VIEW' ? p.muted : p.primary))),
              title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                if (widget.showCompany) e.companyName,
                e.username ?? '-',
                Fmt.dateTime(e.at),
                if (e.deviceLabel != null) e.deviceLabel!,
              ].join(' · ')),
              trailing: e.failed ? Pill('${e.status}', color: p.danger, dense: true) : null,
            ),
          if (_items.length < _total)
            Center(
              child: TextButton.icon(
                onPressed: _loading ? null : () => _load(),
                icon: _loading ? const ButtonSpinner() : const Icon(Icons.expand_more_rounded),
                label: Text('saMoreN'.trParams({'n': '${_total - _items.length}'})),
              ),
            ),
        ],
      ],
    );
  }
}

/// Sehemu ya "Shughuli": kampuni zinazotumia mfumo sasa + mlisho wa kila kinachoendelea.
class SaActivity extends StatefulWidget {
  final ValueChanged<String> onOpenCompany;

  const SaActivity({super.key, required this.onOpenCompany});

  @override
  State<SaActivity> createState() => _SaActivityState();
}

class _SaActivityState extends State<SaActivity> {
  int _hours = 24;
  int _version = 0;

  Future<List<Map<String, dynamic>>> _live() async {
    final body = await PlatformApi.get('activity/live', query: {'hours': _hours});
    return (body is List ? body : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      onRefresh: () async => setState(() => _version++),
      children: [
        SaHeader(title: 'saActivity'.tr, subtitle: 'saActivitySub'.tr),
        SectionCard(
          title: 'saLiveCompanies'.tr,
          subtitle: 'saLiveCompaniesSub'.tr,
          icon: Icons.sensors_rounded,
          trailing: DropdownButton<int>(
            value: _hours,
            underline: const SizedBox.shrink(),
            items: [
              for (final h in const [1, 24, 168, 720])
                DropdownMenuItem(value: h, child: Text(h == 1 ? 'saLastHour'.tr : 'saLastDaysN'.trParams({'n': '${h ~/ 24}'}))),
            ],
            onChanged: (v) => setState(() {
              _hours = v ?? _hours;
              _version++;
            }),
          ),
          child: SaLoader<List<Map<String, dynamic>>>(
            key: ValueKey('live$_hours$_version'),
            load: _live,
            builder: (context, rows, reload) => rows.isEmpty
                ? Text('saNoLive'.tr, style: TextStyle(color: p.muted))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in rows)
                        ActionChip(
                          avatar: Icon(Icons.circle, size: 10, color: p.success),
                          label: Text('${J.str(r['name'])} · ${'saActionsN'.trParams({'n': '${J.integer(r['actions'])}'})}'),
                          tooltip: Fmt.dateTime(J.date(r['lastAt'])),
                          onPressed: () => widget.onOpenCompany(J.str(r['id'])),
                        ),
                    ],
                  ),
          ),
        ),
        SectionCard(
          title: 'saAllActivity'.tr,
          subtitle: 'saAllActivitySub'.tr,
          icon: Icons.timeline_rounded,
          child: ActivityFeed(key: ValueKey('feed$_version'), pageSize: 100),
        ),
      ],
    );
  }
}
