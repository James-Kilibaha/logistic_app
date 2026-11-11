import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/data_list.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/admin.dart';
import '../../data/repositories.dart';

/// Kumbukumbu za vitendo (audit log): nani alifanya nini, lini na kutoka wapi.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  static const int _pageSize = 50;

  final _search = TextEditingController();
  final List<AuditEntry> _items = [];
  List<String> _modules = const [];
  int _total = 0;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _loadingMore = false;

  String? _module;
  bool _failedOnly = false;

  /// null = zote, APP = app (simu/kompyuta), WEB = browser
  String? _client;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
    AuditRepo.modules().then((m) {
      if (mounted) setState(() => _modules = m);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? _day(DateTime? d) =>
      d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<AuditResult> _fetch(int offset) => AuditRepo.search(
        module: _module,
        failed: _failedOnly ? true : null,
        client: _client,
        query: _search.text,
        startDate: _day(_range?.start),
        endDate: _day(_range?.end),
        offset: offset,
        limit: _pageSize,
      );

  Future<void> _load() async {
    setState(() => _status = LoadStatus.loading);
    try {
      final page = await _fetch(0);
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _status = LoadStatus.ready;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_items.length);
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  Color _actionColor(AppPalette p, AuditEntry e) {
    if (e.failed) return p.danger;
    return switch (e.action) {
      'DELETE' => p.danger,
      'BLOCK' => p.warning,
      'CREATE' || 'LOGIN' => p.success,
      _ => p.info,
    };
  }

  String _actionLabel(String action) {
    final key = 'act$action';
    final t = key.tr;
    return t == key ? action : t;
  }

  void _open(AuditEntry e) {
    final p = context.palette;
    String detail = e.detail ?? '';
    try {
      if (detail.isNotEmpty) detail = const JsonEncoder.withIndent('  ').convert(jsonDecode(detail));
    } catch (_) {}
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            shrinkWrap: true,
            children: [
              Text(e.summary ?? '${_actionLabel(e.action)} · ${e.module}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 14),
              InfoRow(label: 'auditWho'.tr, value: e.username ?? '—', icon: Icons.person_outline_rounded),
              InfoRow(label: 'auditWhen'.tr, value: Fmt.dateTime(e.createdAt), icon: Icons.schedule_rounded),
              InfoRow(label: 'auditAction'.tr, value: _actionLabel(e.action), icon: Icons.bolt_rounded),
              InfoRow(label: 'auditModule'.tr, value: e.module, icon: Icons.widgets_outlined),
              InfoRow(
                label: 'auditResult'.tr,
                value: e.failed ? '${'auditFailed'.tr} (${e.statusCode})' : 'auditOk'.tr,
                icon: e.failed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              ),
              if (e.deviceLabel != null)
                InfoRow(
                  label: 'auditDevice'.tr,
                  value: e.deviceLabel!,
                  icon: e.client == 'APP' ? Icons.phone_android_rounded : Icons.language_rounded,
                ),
              if (e.ip != null) InfoRow(label: 'IP', value: e.ip!, icon: Icons.router_outlined),
              if (e.entityId != null) InfoRow(label: 'ID', value: e.entityId!, icon: Icons.tag_rounded),
              InfoRow(label: 'API', value: '${e.method} ${e.path}', icon: Icons.link_rounded),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                FieldLabel('auditData'.tr),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: SelectableText(detail, style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: p.text)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppPage(
      help: 'audit',
      title: 'navAudit'.tr,
      subtitle: 'hintAudit'.tr,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
      body: Column(
        children: [
          ListToolbar(
            search: SearchBox(
              controller: _search,
              hint: 'auditSearchHint'.tr,
              onChanged: (_) {},
              trailing: IconButton(onPressed: _load, icon: const Icon(Icons.search_rounded)),
            ),
            filters: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<String?>(
                  tooltip: 'auditModule'.tr,
                  onSelected: (m) {
                    setState(() => _module = m);
                    _load();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String?>(value: null, child: Text('all'.tr)),
                    for (final m in _modules) PopupMenuItem<String?>(value: m, child: Text(m)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.widgets_outlined, size: 18),
                    label: Text(_module ?? '${'auditModule'.tr}: ${'all'.tr}'),
                  ),
                ),
                InputChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(_range == null
                      ? 'allDates'.tr
                      : '${Fmt.date(_range!.start)} – ${Fmt.date(_range!.end)}'),
                  onPressed: _pickRange,
                  onDeleted: _range == null
                      ? null
                      : () {
                          setState(() => _range = null);
                          _load();
                        },
                ),
                for (final c in const ['APP', 'WEB'])
                  FilterChip(
                    avatar: Icon(c == 'APP' ? Icons.phone_android_rounded : Icons.language_rounded, size: 18),
                    label: Text(c == 'APP' ? 'auditViaApp'.tr : 'auditViaWeb'.tr),
                    selected: _client == c,
                    onSelected: (v) {
                      setState(() => _client = v ? c : null);
                      _load();
                    },
                  ),
                FilterChip(
                  label: Text('auditFailedOnly'.tr),
                  selected: _failedOnly,
                  onSelected: (v) {
                    setState(() => _failedOnly = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              status: _status,
              error: _error,
              isEmpty: _items.isEmpty,
              onRetry: _load,
              empty: EmptyState(icon: Icons.history_rounded, title: 'auditEmpty'.tr),
              builder: () => DataList<AuditEntry>(
                items: _items,
                onRefresh: _load,
                onTap: _open,
                columns: [
                  ColumnSpec('auditWhen'.tr, flex: 2),
                  ColumnSpec('auditWho'.tr, flex: 2),
                  ColumnSpec('auditDevice'.tr, flex: 3),
                  ColumnSpec('auditAction'.tr, flex: 2),
                  ColumnSpec('auditWhat'.tr, flex: 5),
                ],
                cells: (context, e) => [
                  CellText(Fmt.dateTime(e.createdAt), sub: e.ip),
                  CellText(e.username ?? '—', bold: true),
                  CellText(
                    e.client == 'APP' ? 'auditViaApp'.tr : (e.client == 'WEB' ? 'auditViaWeb'.tr : (e.client ?? '—')),
                    sub: e.device,
                  ),
                  Pill(_actionLabel(e.action), color: _actionColor(p, e), dense: true),
                  CellText(e.summary ?? e.module, sub: e.summary == null ? e.path : e.module),
                ],
                card: (context, e) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _actionColor(p, e).withValues(alpha: .12),
                    child: Icon(e.failed ? Icons.error_outline_rounded : Icons.history_rounded, color: _actionColor(p, e)),
                  ),
                  title: Text(e.summary ?? '${_actionLabel(e.action)} · ${e.module}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    e.username ?? '—',
                    Fmt.dateTime(e.createdAt),
                    if (e.deviceLabel != null) e.deviceLabel!,
                  ].join(' · ')),
                ),
                footer: _items.length < _total
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: _loadingMore ? null : _more,
                            icon: _loadingMore
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.expand_more_rounded),
                            label: Text('loadMore'.trParams({'n': '${_items.length}', 'total': '$_total'})),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
