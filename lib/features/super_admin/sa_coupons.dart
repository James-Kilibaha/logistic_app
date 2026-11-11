import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Coupon za punguzo za subscription (mf. KARIBU20 = 20% kwa malipo ya kwanza).
class SaCoupons extends StatefulWidget {
  const SaCoupons({super.key});

  @override
  State<SaCoupons> createState() => _SaCouponsState();
}

class _SaCouponsState extends State<SaCoupons> {
  int _version = 0;

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _load() async {
    final coupons = await PlatformApi.get('coupons');
    final plans = await PlatformApi.get('plans');
    List<Map<String, dynamic>> maps(dynamic b) =>
        b is List ? b.whereType<Map>().map(Map<String, dynamic>.from).toList() : <Map<String, dynamic>>[];
    return (maps(coupons), maps(plans));
  }

  Future<void> _edit(List<Map<String, dynamic>> plans, [Map<String, dynamic>? c]) async {
    final code = TextEditingController(text: J.str(c?['code']));
    final description = TextEditingController(text: J.str(c?['description']));
    final value = TextEditingController(text: c == null ? '' : Fmt.number(J.dbl(c['value'])));
    final maxUses = TextEditingController(text: c?['maxUses'] == null ? '' : '${J.integer(c!['maxUses'])}');
    final perCompany = TextEditingController(text: '${J.integer(c?['maxPerCompany'], 1)}');
    String kind = J.str(c?['kind'], 'PERCENT');
    bool active = J.boolean(c?['active'], true);
    DateTime? until = J.date(c?['validUntil']);
    final selected = <String>{for (final p in (c?['planIds'] as List? ?? const [])) '$p'};

    final ok = await showFormSheet(
      title: c == null ? 'saNewCoupon'.tr : 'saEditCoupon'.tr,
      icon: Icons.local_offer_outlined,
      builder: (context, setState) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              controller: code,
              label: 'saCouponCode'.tr,
              hint: 'KARIBU20',
              required: true,
              capitalization: TextCapitalization.characters,
              validator: Validators.minLength(3),
            ),
            const SizedBox(height: 14),
            AppField(controller: description, label: 'saCouponDesc'.tr),
            const SizedBox(height: 14),
            AppDropdown<String>(
              label: 'saCouponKind'.tr,
              value: kind,
              items: const ['PERCENT', 'AMOUNT'],
              itemLabel: (k) => k == 'PERCENT' ? 'saCouponPercent'.tr : 'saCouponAmount'.tr,
              onChanged: (v) => setState(() => kind = v ?? kind),
            ),
            const SizedBox(height: 14),
            AppField(
              controller: value,
              label: kind == 'PERCENT' ? 'saCouponValuePct'.tr : 'saCouponValueTzs'.tr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: true,
              validator: (v) {
                final n = Fmt.parse(v ?? '') ?? 0;
                if (n <= 0) return 'fieldRequired'.tr;
                if (kind == 'PERCENT' && n > 100) return 'saCouponMax100'.tr;
                return null;
              },
            ),
            const SizedBox(height: 14),
            Text('saCouponPlans'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final pl in plans)
                  FilterChip(
                    label: Text(J.str(pl['name'])),
                    selected: selected.contains(J.str(pl['id'])),
                    onSelected: (v) => setState(() => v ? selected.add(J.str(pl['id'])) : selected.remove(J.str(pl['id']))),
                  ),
              ],
            ),
            Text(selected.isEmpty ? 'saCouponAllPlans'.tr : '', style: TextStyle(color: p.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppField(
                    controller: maxUses,
                    label: 'saCouponMaxUses'.tr,
                    hint: 'saCouponUnlimited'.tr,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppField(
                    controller: perCompany,
                    label: 'saCouponPerCompany'.tr,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    required: true,
                    validator: Validators.required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text('saCouponUntil'.tr),
              subtitle: Text(until == null ? 'saCouponNoExpiry'.tr : Fmt.date(until)),
              trailing: until == null
                  ? null
                  : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => until = null)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: until ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 1100)),
                );
                if (picked != null) setState(() => until = DateTime(picked.year, picked.month, picked.day, 23, 59));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('saActive'.tr),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
          ],
        );
      },
      onSubmit: () {
        final body = {
          if (c != null) 'id': c['id'],
          'code': code.text.trim(),
          'description': description.text.trim().isEmpty ? null : description.text.trim(),
          'kind': kind,
          'value': Fmt.parse(value.text) ?? 0,
          'planIds': selected.isEmpty ? null : selected.toList(),
          'maxUses': int.tryParse(maxUses.text.trim()),
          'maxPerCompany': int.tryParse(perCompany.text.trim()) ?? 1,
          'validUntil': until?.toUtc().toIso8601String(),
          'active': active,
        };
        return c == null ? PlatformApi.post('coupons', body) : PlatformApi.put('coupons', body);
      },
    );
    if (ok) {
      Toast.success(code.text.trim().toUpperCase(), title: 'saved'.tr);
      setState(() => _version++);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await confirmAction(
      title: 'saDeleteCoupon'.tr,
      message: 'saDeleteCouponMsg'.trParams({'code': J.str(c['code'])}),
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (ok && await runGuarded(() => PlatformApi.delete('coupons/${J.str(c['id'])}'))) {
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SaLoader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, data, reload) {
        final (coupons, plans) = data;
        final p = context.palette;
        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(
              title: 'saCoupons'.tr,
              subtitle: 'saCouponsSub'.tr,
              actions: [
                FilledButton.icon(
                  onPressed: () => _edit(plans),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('saNewCoupon'.tr),
                ),
              ],
            ),
            if (coupons.isEmpty)
              EmptyState(icon: Icons.local_offer_outlined, title: 'saNoCoupons'.tr)
            else
              SectionCard(
                child: Column(
                  children: [
                    for (final c in coupons)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.local_offer_rounded, color: J.boolean(c['active']) ? p.success : p.muted),
                        title: Text(
                          '${J.str(c['code'])} · ${J.str(c['kind']) == 'PERCENT' ? '${Fmt.number(J.dbl(c['value']))}%' : money('TZS', J.dbl(c['value']))}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text([
                          if (J.strOrNull(c['description']) != null) J.str(c['description']),
                          'saCouponUsed'.trParams({
                            'n': '${J.integer(c['used'])}',
                            'max': c['maxUses'] == null ? '∞' : '${J.integer(c['maxUses'])}',
                          }),
                          if (J.date(c['validUntil']) != null) '${'saCouponUntil'.tr}: ${Fmt.date(J.date(c['validUntil']))}',
                        ].join(' · ')),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (!J.boolean(c['active'])) Pill('saInactive'.tr, color: p.muted, dense: true),
                            IconButton(
                              tooltip: 'edit'.tr,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(plans, c),
                            ),
                            IconButton(
                              tooltip: 'delete'.tr,
                              icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
