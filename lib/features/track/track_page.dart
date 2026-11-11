import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/api/api_client.dart';
import '../../core/branding.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/media.dart';
import '../../data/models/json.dart';

/// Ukurasa wa umma (bila kuingia): mteja anafuatilia mzigo wake kwa track number au pickup code.
/// Web: https://app.domain/#/track?code=XXXX
class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _data;

  static const _stages = ['RECEIVED', 'SHIPPING', 'ARRIVED', 'COLLECTED'];

  @override
  void initState() {
    super.initState();
    final initial = Get.parameters['code'] ?? Uri.base.queryParameters['code'];
    if (initial != null && initial.trim().isNotEmpty) {
      _code.text = initial.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'trackEnterCode'.tr);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await Api.get('public/track/${Uri.encodeComponent(code)}');
      setState(() => _data = body is Map ? Map<String, dynamic>.from(body) : null);
    } on ApiException catch (e) {
      setState(() {
        _data = null;
        _error = switch (e.status) {
          404 => 'trackNotFound'.trParams({'code': code}),
          429 => 'trackTooMany'.tr,
          _ => e.message,
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await scanCode(title: 'trackCargo'.tr);
    if (code == null) return;
    _code.text = code;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const BrandLogo(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() => Text(BrandingController.to.current.value.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Text('trackCargo'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        leading: Navigator.of(context).canPop()
            ? null
            : IconButton(
                tooltip: 'login'.tr,
                onPressed: () => Get.offAllNamed(Session.isLoggedIn ? Routes.home : Routes.login),
                icon: const Icon(Icons.login_rounded),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text('trackIntro'.tr, style: TextStyle(color: p.muted, height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'trackHint'.tr,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: canScanWithCamera
                              ? IconButton(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _busy ? null : _search,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('trackGo'.tr),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: p.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.search_off_rounded, color: p.danger),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: TextStyle(color: p.danger))),
                      ],
                    ),
                  ),
                ],
                if (_data != null) ...[const SizedBox(height: 18), _result(context, _data!)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stageLabel(String s) => 'trk$s'.tr;

  IconData _stageIcon(String s) => switch (s) {
        'RECEIVED' => Icons.inventory_2_outlined,
        'SHIPPING' => Icons.local_shipping_outlined,
        'ARRIVED' => Icons.warehouse_outlined,
        _ => Icons.handshake_outlined,
      };

  Widget _result(BuildContext context, Map<String, dynamic> d) {
    final p = context.palette;
    final stage = J.str(d['stage'], 'RECEIVED');
    final index = _stages.indexOf(stage);
    final events = {for (final e in (d['events'] as List? ?? const [])) J.str((e as Map)['stage']): J.date(e['at'])};
    final items = (d['items'] as List? ?? const []).whereType<Map>().toList();
    final store = J.map(d['store']);
    final pay = J.map(d['payment']);
    final collected = J.map(d['collected']);
    final eta = J.date(J.map(d['box'])?['eta']);
    final company = J.map(d['company']) ?? const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_stageIcon(stage), color: p.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_stageLabel(stage), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                          Text('${'invoice'.tr} #${J.str(d['invoiceNumber'])} · ${J.str(d['customer'])}',
                              style: TextStyle(color: p.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (int i = 0; i < _stages.length; i++)
                  _StepRow(
                    label: _stageLabel(_stages[i]),
                    icon: _stageIcon(_stages[i]),
                    done: i <= index,
                    current: i == index,
                    last: i == _stages.length - 1,
                    when: events[_stages[i]],
                  ),
              ],
            ),
          ),
        ),
        if (eta != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _info(p, 'trkEta'.tr, Fmt.date(eta), color: const Color(0xFF0891B2)),
            ),
          ),
        ],
        if (store != null || pay != null || collected != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (store != null) ...[
                    _info(p, 'trkArrivedAt'.tr, Fmt.dateTime(J.date(store['arrivedAt']))),
                    _info(p, 'trkDaysInStore'.tr, '${J.integer(store['days'])}'),
                    if (J.integer(store['freeDaysLeft']) > 0)
                      _info(p, 'trkFreeDaysLeft'.tr, '${J.integer(store['freeDaysLeft'])}', color: p.success)
                    else
                      _info(p, 'trkStorageCharging'.tr,
                          '\$${J.dbl(store['chargePerDayUsd']).toStringAsFixed(2)} / ${'day'.tr}', color: p.warning),
                  ],
                  if (pay != null) ...[
                    if (J.dbl(pay['storageCharge']) > 0) _info(p, 'trkStorageCharge'.tr, Fmt.tsh(J.dbl(pay['storageCharge']))),
                    _info(
                      p,
                      'balanceDue'.tr,
                      J.str(pay['status']) == 'PAID' ? 'fullyPaid'.tr : Fmt.tsh(J.dbl(pay['balance'])),
                      color: J.str(pay['status']) == 'PAID' ? p.success : p.danger,
                    ),
                  ],
                  if (collected != null)
                    _info(p, 'trkCollectedBy'.tr,
                        '${J.str(collected['by'])} · ${Fmt.dateTime(J.date(collected['at']))}'),
                ],
              ),
            ),
          ),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final it in items)
                  ListTile(
                    leading: Icon(
                      J.str(it['carrier']).toUpperCase() == 'SEA' ? Icons.directions_boat_outlined : Icons.flight_rounded,
                      color: p.primary,
                    ),
                    title: Text(J.str(it['description'])),
                    subtitle: Text([
                      if (J.strOrNull(it['trackNumber']) != null) J.str(it['trackNumber']),
                      '${Fmt.number(J.dbl(it['quantities']))} ${'ctn'.tr}',
                      Fmt.kg(J.dbl(it['weight'])),
                    ].join(' · ')),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '${J.str(company['name'])} · ${J.str(company['phones'])}',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _info(AppPalette p, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: p.muted))),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? p.text)),
          ],
        ),
      );
}

class _StepRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool done;
  final bool current;
  final bool last;
  final DateTime? when;

  const _StepRow({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
    required this.last,
    this.when,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = done ? p.primary : p.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? p.primary : p.surfaceAlt,
                  boxShadow: current ? [BoxShadow(color: p.primary.withValues(alpha: .35), blurRadius: 10)] : null,
                ),
                child: Icon(done && !current ? Icons.check_rounded : icon, size: 16, color: done ? Colors.white : p.muted),
              ),
              if (!last) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontWeight: current ? FontWeight.w700 : FontWeight.w500, color: done ? p.text : p.muted)),
                  if (when != null) Text(Fmt.dateTime(when), style: TextStyle(color: p.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
