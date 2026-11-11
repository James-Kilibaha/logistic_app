import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Kumbukumbu za vitendo vya wasimamizi wa mfumo (wewe na wasaidizi): nani, alifanya nini, lini, kwa kampuni ipi.
class SaAudit extends StatefulWidget {
  final ValueChanged<String> onOpenCompany;

  /// Kuonyesha kampuni moja tu (ukurasa wa kampuni).
  final String? companyId;

  const SaAudit({super.key, required this.onOpenCompany, this.companyId});

  @override
  State<SaAudit> createState() => _SaAuditState();
}

class _SaAuditState extends State<SaAudit> {
  final _admin = TextEditingController();
  String? _action;
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  static const _actions = [
    'LOGIN', 'LOGIN_FAILED', 'LOGIN_2FA_FAILED', 'VIEW_AS', 'COMPANY_APPROVE', 'COMPANY_REJECT', 'COMPANY_STATUS',
    'COMPANY_LIMITS', 'COMPANY_EXPORT', 'COMPANY_DELETE', 'TENANT_PASSWORD', 'PAYMENT_RECORD', 'PAYMENT_CONFIRM',
    'PAYMENT_REJECT', 'SUBSCRIPTION_EXTEND', 'SUBSCRIPTION_PLAN', 'ADMIN_CREATE', 'ADMIN_UPDATE', '2FA_ENABLED',
    '2FA_DISABLED', '2FA_RESET',
  ];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _admin.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _items.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await PlatformApi.get('audit', query: {
        'page': '$_page',
        'size': '50',
        if (widget.companyId != null) 'company_id': widget.companyId,
        if (_admin.text.trim().isNotEmpty) 'admin': _admin.text.trim(),
        if (_action != null) 'action': _action,
      });
      final m = body is Map ? body : const {};
      if (!mounted) return;
      setState(() {
        _items.addAll((m['items'] is List ? m['items'] as List : const []).whereType<Map>().map(Map<String, dynamic>.from));
        _total = J.integer(m['total']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      onRefresh: () => _load(reset: true),
      children: [
        if (widget.companyId == null) SaHeader(title: 'saAudit'.tr, subtitle: 'saAuditSub'.tr),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: SearchBox(
                controller: _admin,
                hint: 'saAuditByAdmin'.tr,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () => _load(reset: true));
                },
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                value: _action,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'saAuditAction'.tr, isDense: true),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text('all'.tr)),
                  for (final a in _actions) DropdownMenuItem<String?>(value: a, child: Text(_label(a))),
                ],
                onChanged: (v) {
                  _action = v;
                  _load(reset: true);
                },
              ),
            ),
            Text('saAuditTotal'.trParams({'n': '$_total'}), style: TextStyle(color: p.muted)),
          ],
        ),
        if (_error != null)
          ErrorState(message: _error!, onRetry: () => _load(reset: true))
        else if (_items.isEmpty && !_loading)
          EmptyState(icon: Icons.history_toggle_off_rounded, title: 'saAuditEmpty'.tr)
        else
          SectionCard(
            child: Column(
              children: [
                for (final e in _items) _row(context, e),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                else if (_items.length < _total)
                  TextButton.icon(
                    onPressed: () {
                      _page += 1;
                      _load();
                    },
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('loadMore'.trParams({'n': '${_items.length}', 'total': '$_total'})),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _label(String action) {
    final key = 'saAct_$action';
    final t = key.tr;
    return t == key ? action : t;
  }

  Widget _row(BuildContext context, Map<String, dynamic> e) {
    final p = context.palette;
    final failed = J.integer(e['statusCode']) >= 400;
    final company = J.strOrNull(e['companyName']);
    final detail = J.strOrNull(e['detail']);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(40, 0, 8, 12),
      leading: Icon(_icon(J.str(e['action'])), color: failed ? p.danger : p.primary),
      title: Text(J.str(e['summary'], J.str(e['action'])), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([
        J.str(e['username'], '-'),
        Fmt.dateTime(J.date(e['at'])),
        if (company != null) '$company (${J.str(e['companySlug'])})',
      ].join(' · '), style: TextStyle(color: p.muted, fontSize: 12.5)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(label: 'saAuditAction'.tr, value: _label(J.str(e['action']))),
              if (J.strOrNull(e['path']) != null) InfoRow(label: 'API', value: '${J.str(e['method'])} ${J.str(e['path'])}'),
              if (J.strOrNull(e['ip']) != null) InfoRow(label: 'IP', value: J.str(e['ip'])),
              if (detail != null) ...[
                const SizedBox(height: 6),
                SelectableText(detail, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: p.muted)),
              ],
              if (J.strOrNull(e['companyId']) != null && widget.companyId == null)
                TextButton.icon(
                  onPressed: () => widget.onOpenCompany(J.str(e['companyId'])),
                  icon: const Icon(Icons.apartment_rounded, size: 18),
                  label: Text('saOpenCompany'.tr),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _icon(String action) {
    if (action.startsWith('LOGIN')) return Icons.login_rounded;
    if (action.startsWith('2FA')) return Icons.verified_user_outlined;
    if (action == 'VIEW_AS') return Icons.visibility_outlined;
    if (action.startsWith('PAYMENT') || action.startsWith('SUBSCRIPTION')) return Icons.payments_outlined;
    if (action.startsWith('COMPANY')) return Icons.apartment_rounded;
    if (action.startsWith('ADMIN')) return Icons.shield_outlined;
    return Icons.history_rounded;
  }
}
