import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/popup.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../popup/popup_alerts.dart';

/// Mipangilio ya taarifa za pop-up: kila aina - washa/zima, ianze baada ya siku ngapi, ijirudie kila baada ya muda gani.
class PopupRulesCard extends StatefulWidget {
  const PopupRulesCard({super.key});

  @override
  State<PopupRulesCard> createState() => _PopupRulesCardState();
}

class _PopupRulesCardState extends State<PopupRulesCard> {
  static const _days = [0, 1, 2, 3, 4, 5, 7, 10, 14, 21, 30, 45, 60, 90];
  static const _minutes = [5, 15, 30, 60, 120, 180, 240, 360, 480, 720, 1440, 2880, 10080];

  List<PopupRule>? _rules;
  String? _saving;

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules = await PopupRepo.rules();
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _save(PopupRule r) async {
    setState(() => _saving = r.kind);
    try {
      final rules = await PopupRepo.saveRule(r);
      if (mounted) setState(() => _rules = rules);
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _saving = null);
  }

  PopupRule _copy(PopupRule r, {bool? enabled, int? afterDays, int? everyMinutes}) => PopupRule(
        kind: r.kind,
        module: r.module,
        enabled: enabled ?? r.enabled,
        afterDays: afterDays ?? r.afterDays,
        everyMinutes: everyMinutes ?? r.everyMinutes,
      );

  static String every(int m) {
    if (m % 1440 == 0) return 'everyNDays'.trParams({'n': '${m ~/ 1440}'});
    if (m % 60 == 0) return 'everyNHours'.trParams({'n': '${m ~/ 60}'});
    return 'everyNMinutes'.trParams({'n': '$m'});
  }

  static String after(int d) => d == 0 ? 'popAfterNow'.tr : 'popAfterNDays'.trParams({'n': '$d'});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rules = _rules;
    return SectionCard(
      title: 'popupRules'.tr,
      subtitle: 'popupRulesSub'.tr,
      icon: Icons.notifications_active_outlined,
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

  Widget _row(BuildContext context, PopupRule r) {
    final p = context.palette;
    final busy = _saving == r.kind;
    final edit = _canEdit && !busy;
    final days = {..._days, r.afterDays}.toList()..sort();
    final minutes = {..._minutes, r.everyMinutes}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(popupIcon(r.kind), color: r.enabled ? p.primary : p.muted, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(popupTitle(r.kind), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(popupDesc(r.kind), style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Switch(value: r.enabled, onChanged: edit ? (v) => _save(_copy(r, enabled: v)) : null),
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
                  if (r.kind != 'SMS_LOW_BALANCE')
                    _choice<int>(
                      context,
                      label: 'popStartLabel'.tr,
                      value: r.afterDays,
                      values: days,
                      text: after,
                      onChanged: edit ? (v) => _save(_copy(r, afterDays: v)) : null,
                    ),
                  _choice<int>(
                    context,
                    label: 'popRepeatLabel'.tr,
                    value: r.everyMinutes,
                    values: minutes,
                    text: every,
                    onChanged: edit ? (v) => _save(_copy(r, everyMinutes: v)) : null,
                  ),
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
