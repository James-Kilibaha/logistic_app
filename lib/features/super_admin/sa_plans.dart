import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/company.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'sa_common.dart';

/// Mipango ya subscription: bei, muda, mipaka na huduma za ziada.
class SaPlans extends StatefulWidget {
  const SaPlans({super.key});

  @override
  State<SaPlans> createState() => _SaPlansState();
}

class _SaPlansState extends State<SaPlans> {
  int _version = 0;

  Future<(List<Map<String, dynamic>>, List<String>)> _load() async {
    final plans = await PlatformApi.get('plans');
    final modules = await PlatformApi.get('plans/modules');
    return (
      (plans is List ? plans : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      (modules is List ? modules : const []).map((e) => e.toString()).toList(),
    );
  }

  void _reload() => setState(() => _version++);

  Future<void> _edit(List<String> allModules, [Map<String, dynamic>? current]) async {
    String text(String k) => current?[k] == null ? '' : _plain(current![k]);
    final code = TextEditingController(text: text('code'));
    final name = TextEditingController(text: text('name'));
    final description = TextEditingController(text: text('description'));
    final price = TextEditingController(text: text('price'));
    final currency = TextEditingController(text: current == null ? 'TZS' : text('currency'));
    final months = TextEditingController(text: current == null ? '1' : text('months'));
    final maxUsers = TextEditingController(text: text('maxUsers'));
    final maxOffices = TextEditingController(text: text('maxOffices'));
    final maxInvoices = TextEditingController(text: text('maxInvoicesPerMonth'));
    final sort = TextEditingController(text: current == null ? '0' : text('sortOrder'));
    final existing = current?['modules'];
    bool allFeatures = current != null && existing == null;
    final selected = <String>{if (existing is List) ...existing.map((e) => e.toString())};
    bool isPublic = current == null ? true : J.boolean(current['isPublic'], true);
    bool isActive = current == null ? true : J.boolean(current['isActive'], true);
    int? opt(TextEditingController t) => t.text.trim().isEmpty ? null : int.tryParse(t.text.trim());

    final ok = await showFormSheet(
      title: current == null ? 'saNewPlan'.tr : 'saEditPlan'.tr,
      icon: Icons.layers_outlined,
      maxWidth: 600,
      builder: (context, setState) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: AppField(controller: code, label: 'saPlanCode'.tr, hint: 'business', required: true,
                  validator: Validators.minLength(2))),
              const SizedBox(width: 12),
              Expanded(child: AppField(controller: name, label: 'saPlanName'.tr, hint: 'Business', required: true,
                  validator: Validators.minLength(2))),
            ]),
            const SizedBox(height: 14),
            AppField(controller: description, label: 'saPlanDescription'.tr, maxLines: 2),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                flex: 2,
                child: AppField(controller: price, label: 'price'.tr, required: true, validator: Validators.number,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 12),
              Expanded(child: AppField(controller: currency, label: 'currency'.tr, required: true,
                  validator: Validators.required)),
              const SizedBox(width: 12),
              Expanded(child: AppField(controller: months, label: 'saMonths'.tr, required: true,
                  validator: Validators.positive, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            Text('saLimits'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
            Text('saLimitsHelp'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: AppField(controller: maxUsers, label: 'users'.tr, keyboardType: TextInputType.number,
                  validator: Validators.number)),
              const SizedBox(width: 12),
              Expanded(child: AppField(controller: maxOffices, label: 'offices'.tr,
                  keyboardType: TextInputType.number, validator: Validators.number)),
              const SizedBox(width: 12),
              Expanded(child: AppField(controller: maxInvoices, label: 'saInvoicesPerMonth'.tr,
                  keyboardType: TextInputType.number, validator: Validators.number)),
            ]),
            const SizedBox(height: 16),
            Text('saModules'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('allFeatures'.tr),
              value: allFeatures,
              onChanged: (v) => setState(() => allFeatures = v),
            ),
            if (!allFeatures)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in allModules)
                    FilterChip(
                      label: Text('module_$m'.tr),
                      selected: selected.contains(m),
                      onSelected: (v) => setState(() => v ? selected.add(m) : selected.remove(m)),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('saPlanPublic'.tr),
              subtitle: Text('saPlanPublicHelp'.tr),
              value: isPublic,
              onChanged: (v) => setState(() => isPublic = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('saPlanActive'.tr),
              value: isActive,
              onChanged: (v) => setState(() => isActive = v),
            ),
            AppField(controller: sort, label: 'saSortOrder'.tr, keyboardType: TextInputType.number),
          ],
        );
      },
      onSubmit: () {
        final data = {
          if (current != null) 'id': current['id'],
          'code': code.text.trim(),
          'name': name.text.trim(),
          'description': description.text.trim().isEmpty ? null : description.text.trim(),
          'price': Fmt.parse(price.text) ?? 0,
          'currency': currency.text.trim().toUpperCase(),
          'months': int.tryParse(months.text.trim()) ?? 1,
          'maxUsers': opt(maxUsers),
          'maxOffices': opt(maxOffices),
          'maxInvoicesPerMonth': opt(maxInvoices),
          'modules': allFeatures ? null : selected.toList(),
          'isPublic': isPublic,
          'isActive': isActive,
          'sortOrder': int.tryParse(sort.text.trim()) ?? 0,
        };
        return current == null ? PlatformApi.post('plans', data) : PlatformApi.put('plans', data);
      },
    );
    if (ok) {
      Toast.success(name.text, title: 'saved'.tr);
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> plan) async {
    final sure = await confirmAction(
      title: 'saDeletePlan'.tr,
      message: 'saDeletePlanMsg'.trParams({'name': J.str(plan['name'])}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!sure) return;
    if (await runGuarded(() => PlatformApi.delete('plans/${plan['id']}'), success: 'deleted'.tr)) _reload();
  }

  static String _plain(dynamic v) {
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SaLoader<(List<Map<String, dynamic>>, List<String>)>(
      key: ValueKey(_version),
      load: _load,
      builder: (context, data, reload) {
        final p = context.palette;
        final (plans, modules) = data;
        return PageScroll(
          onRefresh: reload,
          children: [
            SaHeader(
              title: 'subPlans'.tr,
              subtitle: 'saPlansSub'.tr,
              actions: [
                FilledButton.icon(
                  onPressed: () => _edit(modules),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('saNewPlan'.tr),
                ),
              ],
            ),
            ResponsiveGrid(
              minItemWidth: 260,
              children: [
                for (final raw in plans)
                  Builder(builder: (context) {
                    final plan = Plan.fromJson(raw);
                    final active = J.boolean(raw['isActive'], true);
                    final public = J.boolean(raw['isPublic'], true);
                    String limit(int? n) => n == null ? '∞' : '$n';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(plan.name,
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text)),
                              ),
                              if (!active) Pill('saInactive'.tr, color: p.muted, dense: true),
                              if (active && !public) Pill('saHidden'.tr, color: p.warning, dense: true),
                            ]),
                            Text(plan.code, style: TextStyle(color: p.muted, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(money(plan.currency, plan.price),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: p.primary)),
                            Text(plan.months == 1 ? 'perMonth'.tr : 'perMonths'.trParams({'n': '${plan.months}'}),
                                style: TextStyle(color: p.muted, fontSize: 12.5)),
                            const SizedBox(height: 8),
                            Text('${'users'.tr}: ${limit(plan.maxUsers)} · ${'offices'.tr}: ${limit(plan.maxOffices)} · '
                                '${'saInvoicesPerMonth'.tr}: ${limit(plan.maxInvoicesPerMonth)}',
                                style: TextStyle(color: p.text, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              plan.modules == null
                                  ? 'allFeatures'.tr
                                  : (plan.modules!.isEmpty
                                      ? 'saCoreOnly'.tr
                                      : plan.modules!.map((m) => 'module_$m'.tr).join(', ')),
                              style: TextStyle(color: p.muted, fontSize: 12.5),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              OutlinedButton.icon(
                                onPressed: () => _edit(modules, raw),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text('edit'.tr),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'delete'.tr,
                                onPressed: () => _delete(raw),
                                icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        );
      },
    );
  }
}
