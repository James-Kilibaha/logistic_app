import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/json.dart';
import '../../data/models/ops.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../reports/analytics_tabs.dart';

/// Hali ya server: database, diski, backup, SMS/WhatsApp, kazi za scheduler na matatizo.
class SystemHealthCard extends StatefulWidget {
  const SystemHealthCard({super.key});

  @override
  State<SystemHealthCard> createState() => _SystemHealthCardState();
}

class _SystemHealthCardState extends State<SystemHealthCard> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await HealthRepo.details();
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    await runGuarded(HealthRepo.testAlert, success: 'testAlertSent'.tr);
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = _d;
    Widget line(IconData icon, String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color ?? p.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(color: p.muted))),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? p.text)),
              ),
            ],
          ),
        );
    final problems = (d?['problems'] as List? ?? const []).whereType<Map>().toList();
    final db = J.map(d?['database']) ?? const {};
    final sms = J.map(d?['sms']) ?? const {};
    final wa = J.map(d?['whatsapp']) ?? const {};
    final backup = J.map(d?['backup']) ?? const {};
    final disks = J.map(d?['disk']) ?? const {};
    return SectionCard(
      title: 'systemHealth'.tr,
      subtitle: d == null ? null : 'v${J.str(d['version'])} · ${'uptime'.tr} ${J.dbl(d['uptimeHours']).toStringAsFixed(1)}h',
      icon: Icons.monitor_heart_outlined,
      trailing: IconButton(tooltip: 'refresh'.tr, onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      child: _error != null
          ? Text(_error!, style: TextStyle(color: p.danger))
          : d == null
              ? const LinearProgressIndicator()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (problems.isEmpty ? p.success : p.danger).withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            problems.isEmpty ? 'allSystemsOk'.tr : 'problemsFound'.trParams({'n': '${problems.length}'}),
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: problems.isEmpty ? p.success : p.danger),
                          ),
                          for (final pr in problems)
                            Text('• ${J.str(pr['message'])}', style: TextStyle(color: p.danger, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    line(Icons.storage_rounded, 'Database',
                        J.boolean(db['ok']) ? '${J.dbl(db['latencyMs']).toStringAsFixed(0)} ms' : 'down',
                        color: J.boolean(db['ok']) ? null : p.danger),
                    for (final e in disks.entries)
                      line(Icons.sd_storage_outlined, '${'disk'.tr} (${e.key})',
                          '${J.dbl((e.value as Map)['freeGb']).toStringAsFixed(1)} GB ${'free'.tr}'),
                    line(Icons.backup_outlined, 'backup'.tr,
                        backup['ageHours'] == null ? '—' : 'hoursAgo'.trParams({'n': J.dbl(backup['ageHours']).toStringAsFixed(0)})),
                    line(Icons.sms_outlined, 'SMS',
                        '${J.boolean(sms['configured']) ? 'configured'.tr : 'notConfigured'.tr} · ${'pendingN'.trParams({'n': '${J.integer(sms['pending'])}'})}',
                        color: J.boolean(sms['configured']) ? null : p.warning),
                    line(Icons.chat_outlined, 'WhatsApp',
                        J.boolean(wa['enabled']) ? 'enabledLower'.tr : (J.boolean(wa['configured']) ? 'configured'.tr : 'notConfigured'.tr)),
                    if (AppController.to.can(AppModule.setting, AppAction.update)) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _test,
                          icon: const Icon(Icons.campaign_outlined, size: 18),
                          label: Text('sendTestAlert'.tr),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

/// Kuingiza wateja au madeni ya zamani kutoka Excel (kwanza kukagua, kisha kuhifadhi).
class ImportCard extends StatefulWidget {
  const ImportCard({super.key});

  @override
  State<ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<ImportCard> {
  String _kind = 'customers';
  bool _busy = false;

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() => _busy = true);
    try {
      final check = await ImportRepo.run(_kind, bytes, file.name, dryRun: true);
      if (!mounted) return;
      final ok = await _confirm(check);
      if (ok) {
        final res = await ImportRepo.run(_kind, bytes, file.name, dryRun: false);
        if (res.saved) {
          AppController.to.notifyChanged();
          Toast.success('importDone'.trParams({'n': '${res.created}', 's': '${res.skipped}'}), title: 'saved'.tr);
        } else {
          Toast.warning('importNothingSaved'.tr);
        }
      }
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirm(ImportResult r) async {
    final p = context.palette;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('importPreview'.tr),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('importRows'.trParams({'n': '${r.rows}'})),
                Text('importWillCreate'.trParams({'n': '${r.created}'}), style: TextStyle(color: p.success)),
                if (r.skipped > 0) Text('importWillSkip'.trParams({'n': '${r.skipped}'}), style: TextStyle(color: p.muted)),
                if (r.errors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('importErrors'.trParams({'n': '${r.errors.length}'}),
                      style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
                  for (final (row, msg) in r.errors.take(30)) Text('${'row'.tr} $row: $msg', style: TextStyle(color: p.danger)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr)),
          FilledButton(
            onPressed: r.errors.isEmpty && r.created > 0 ? () => Navigator.pop(context, true) : null,
            child: Text('importNow'.tr),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'importData'.tr,
      subtitle: 'importDataSub'.tr,
      icon: Icons.upload_file_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'customers', icon: const Icon(Icons.people_alt_outlined), label: Text('navCustomers'.tr)),
              ButtonSegment(value: 'debts', icon: const Icon(Icons.account_balance_outlined), label: Text('oldDebts'.tr)),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 8),
          Text(_kind == 'customers' ? 'importCustomersHelp'.tr : 'importDebtsHelp'.tr,
              style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => saveExcel(() => ImportRepo.template(_kind), 'template_$_kind'),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text('downloadTemplate'.tr),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text('chooseExcel'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
