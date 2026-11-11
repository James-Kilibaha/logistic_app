import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/popup.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

/// SMS za moja kwa moja: deni, mkopo, onyo la stoo, mzigo umekaa stoo muda mrefu.
/// Kila aina: washa/zima, ianze baada ya siku ngapi, ijirudie kila siku ngapi, itumwe yenyewe au isubiri, saa ngapi.
class AutoSmsCard extends StatefulWidget {
  const AutoSmsCard({super.key});

  @override
  State<AutoSmsCard> createState() => _AutoSmsCardState();
}

class _AutoSmsCardState extends State<AutoSmsCard> {
  static const _days = [0, 1, 2, 3, 4, 5, 7, 10, 14, 21, 30, 45, 60, 90];
  static const _repeat = [0, 1, 2, 3, 5, 7, 10, 14, 21, 30];

  List<AutoSmsRule>? _rules;
  String? _saving;
  bool _running = false;

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  bool get _canRun => AppController.to.can(AppModule.broadcast, AppAction.insert);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules = await PopupRepo.autoSms();
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _save(AutoSmsRule r) async {
    setState(() => _saving = r.kind);
    try {
      final rules = await PopupRepo.saveAutoSms(r);
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _saving = null);
  }

  Future<void> _runNow() async {
    final ok = await confirmAction(
      title: 'autoSmsRunNow'.tr,
      message: 'autoSmsRunNowMsg'.tr,
      confirmText: 'autoSmsRunNow'.tr,
      icon: Icons.play_arrow_rounded,
    );
    if (!ok) return;
    setState(() => _running = true);
    try {
      final r = await AnalyticsRepo.runReminders();
      final n = r.values.fold<int>(0, (s, v) => s + v);
      Toast.success('autoSmsPrepared'.trParams({'n': '$n'}));
      AppController.to.notifyChanged();
      await _load();
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _running = false);
  }

  static String _after(String kind, int d) {
    if (kind == 'STORAGE_WARN') return 'autoWarnBefore'.trParams({'n': '$d'});
    if (kind == 'STORAGE_OVERDUE') return d == 0 ? 'autoOverdueNow'.tr : 'autoOverdueAfter'.trParams({'n': '$d'});
    return d == 0 ? 'popAfterNow'.tr : 'popAfterNDays'.trParams({'n': '$d'});
  }

  static String _every(int d) => d == 0 ? 'autoOnce'.tr : 'everyNDays'.trParams({'n': '$d'});

  static String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rules = _rules;
    return SectionCard(
      title: 'autoSms'.tr,
      subtitle: 'autoSmsSub'.tr,
      icon: Icons.schedule_send_outlined,
      trailing: _canRun
          ? TextButton.icon(
              onPressed: _running ? null : _runNow,
              icon: _running
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text('autoSmsRunNow'.tr),
            )
          : null,
      child: rules == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('loading'.tr, style: TextStyle(color: p.muted)),
            )
          : Column(
              children: [
                for (final r in rules) ...[
                  _row(context, r),
                  if (r != rules.last) Divider(height: 1, color: p.border),
                ],
              ],
            ),
    );
  }

  Widget _row(BuildContext context, AutoSmsRule r) {
    final p = context.palette;
    final busy = _saving == r.kind;
    final edit = _canEdit && !busy;
    final days = {..._days, r.afterDays}.toList()..sort();
    final repeat = {..._repeat, r.everyDays}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sms_outlined, color: r.enabled ? p.primary : p.muted, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('auto_${r.kind}'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('autoDesc_${r.kind}'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                    if (r.lastRunOn != null)
                      Text('autoLastRun'.trParams({'date': Fmt.date(r.lastRunOn)}),
                          style: TextStyle(color: p.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Switch(value: r.enabled, onChanged: edit ? (v) => _save(r.copyWith(enabled: v)) : null),
            ],
          ),
          if (r.enabled)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _choice<int>(context,
                      label: 'popStartLabel'.tr,
                      value: r.afterDays,
                      values: days,
                      text: (d) => _after(r.kind, d),
                      onChanged: edit ? (v) => _save(r.copyWith(afterDays: v)) : null),
                  if (r.kind != 'STORAGE_WARN')
                    _choice<int>(context,
                        label: 'popRepeatLabel'.tr,
                        value: r.everyDays,
                        values: repeat,
                        text: _every,
                        onChanged: edit ? (v) => _save(r.copyWith(everyDays: v)) : null),
                  _choice<int>(context,
                      label: 'autoHourLabel'.tr,
                      value: r.hour,
                      values: [for (var h = 0; h < 24; h++) h],
                      text: _hour,
                      onChanged: edit ? (v) => _save(r.copyWith(hour: v)) : null),
                  _choice<bool>(context,
                      label: 'autoSendLabel'.tr,
                      value: r.autoSend,
                      values: const [true, false],
                      text: (v) => v ? 'autoSendYes'.tr : 'autoSendNo'.tr,
                      onChanged: edit ? (v) => _save(r.copyWith(autoSend: v)) : null),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _choice<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required void Function(T)? onChanged,
  }) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(color: p.muted, fontSize: 13)),
        DropdownButton<T>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [for (final v in values) DropdownMenuItem(value: v, child: Text(text(v)))],
          onChanged: onChanged == null
              ? null
              : (v) {
                  if (v != null) onChanged(v);
                },
        ),
      ],
    );
  }
}
