import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';
import '../../data/models/company.dart';
import '../../data/models/json.dart';
import 'platform_api.dart';
import 'platform_models.dart';
import 'sa_common.dart';
import 'sa_company_detail.dart';

/// Kampuni zote (wateja wako): kutafuta, kusajili mpya, kufungua moja.
class SaCompanies extends StatefulWidget {
  /// Kampuni ya kufungua moja kwa moja (kutoka dashboard).
  final String? openCompanyId;

  /// Kichujio cha kuanzia (mf. 'PENDING' = zinazosubiri kuthibitishwa).
  final String? initialStatus;

  const SaCompanies({super.key, this.openCompanyId, this.initialStatus});

  @override
  State<SaCompanies> createState() => _SaCompaniesState();
}

class _SaCompaniesState extends State<SaCompanies> {
  final _search = TextEditingController();
  Timer? _debounce;
  late String? _status = widget.initialStatus;
  List<PlatformCompany> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    final open = widget.openCompanyId;
    if (open != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(open));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await PlatformApi.get('companies',
          query: {'q': _search.text.trim(), 'status': _status, 'limit': 500});
      final map = Map<String, dynamic>.from(body as Map);
      setState(() {
        _items = J.list(map['items'], PlatformCompany.fromJson);
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
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaCompanyDetailPage(companyId: id)));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final created = await showCreateCompany();
    if (created != null && mounted) {
      await _load();
      await _open(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PageScroll(
      onRefresh: _load,
      children: [
        SaHeader(
          title: 'saCompanies'.tr,
          subtitle: 'saCompaniesCount'.trParams({'n': '$_total'}),
          actions: [
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text('saNewCompany'.tr),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: _search,
                onChanged: (_) => _searchSoon(),
                decoration: InputDecoration(
                  hintText: 'saSearchCompanies'.tr,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            for (final (String? value, String label) in [
              (null, 'saAll'.tr),
              ('PENDING', 'saPending'.tr),
              ('ACTIVE', 'saActive'.tr),
              ('SUSPENDED', 'saSuspended'.tr),
              ('REJECTED', 'saRejected'.tr),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _status == value,
                onSelected: (_) {
                  setState(() => _status = value);
                  _load();
                },
              ),
          ],
        ),
        if (_loading && _items.isEmpty)
          const LoadingList()
        else if (_error != null && _items.isEmpty)
          ErrorState(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
            icon: Icons.apartment_rounded,
            title: 'saNoCompanies'.tr,
            message: 'saNoCompaniesMsg'.tr,
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: Text('saNewCompany'.tr),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  _CompanyTile(company: _items[i], onTap: () => _open(_items[i].id)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CompanyTile extends StatelessWidget {
  final PlatformCompany company;
  final VoidCallback onTap;

  const _CompanyTile({required this.company, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = company;
    final sub = c.subscription;
    final details = [
      c.slug,
      if (c.domain != null) c.domain!,
      if (c.phone != null) c.phone!,
      if (sub?.plan != null) sub!.plan!.name,
      if (c.createdAt != null) Fmt.date(c.createdAt),
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: p.primarySoft,
        child: Text(c.name.isEmpty ? '?' : c.name.substring(0, 1).toUpperCase(),
            style: TextStyle(color: p.primary, fontWeight: FontWeight.w800)),
      ),
      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!c.isActive) CompanyStatusPill(c.status) else SubscriptionPill(sub),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// Fomu ya kusajili kampuni mpya. Inarudisha id ya kampuni iliyoundwa (au `null`).
Future<String?> showCreateCompany() async {
  List<Plan> plans = [];
  try {
    plans = (await loadPlans()).where((pl) => pl.code.isNotEmpty).toList();
  } catch (e) {
    Toast.error(e);
    return null;
  }
  final name = TextEditingController();
  final slug = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final domain = TextEditingController();
  final trial = TextEditingController(text: '14');
  final first = TextEditingController();
  final last = TextEditingController();
  final username = TextEditingController(text: 'admin');
  final password = TextEditingController();
  final adminPhone = TextEditingController();
  Plan? plan = plans.isEmpty ? null : plans.first;
  bool slugEdited = false;
  String? createdId;

  String suggest(String v) {
    final s = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return s.length > 30 ? s.substring(0, 30) : s;
  }

  final ok = await showFormSheet(
    title: 'saNewCompany'.tr,
    subtitle: 'saNewCompanySub'.tr,
    icon: Icons.add_business_rounded,
    maxWidth: 620,
    submitLabel: 'saRegister'.tr,
    builder: (context, setState) {
      final p = context.palette;
      Widget section(String text) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: p.primary)),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('signupCompany'.tr),
          AppField(
            controller: name,
            label: 'companyName'.tr,
            required: true,
            validator: Validators.required,
            capitalization: TextCapitalization.words,
            onChanged: (v) {
              if (!slugEdited) slug.text = suggest(v);
            },
          ),
          const SizedBox(height: 14),
          AppField(
            controller: slug,
            label: 'companyCode'.tr,
            hint: 'companyCodeHint'.tr,
            helper: 'companyCodeSignupHelp'.tr,
            icon: Icons.tag_rounded,
            required: true,
            validator: Validators.minLength(3),
            onChanged: (_) => slugEdited = true,
          ),
          const SizedBox(height: 14),
          PhoneField(controller: phone, label: 'companyPhone'.tr),
          const SizedBox(height: 14),
          AppField(controller: email, label: 'email'.tr, icon: Icons.alternate_email_rounded),
          const SizedBox(height: 14),
          AppField(
            controller: domain,
            label: 'saDomain'.tr,
            hint: 'ymg.co.tz',
            helper: 'saDomainHelp'.tr,
            icon: Icons.language_rounded,
          ),
          const SizedBox(height: 8),
          section('subscription'.tr),
          if (plans.isNotEmpty)
            AppDropdown<Plan>(
              label: 'plan'.tr,
              value: plan,
              items: plans,
              itemLabel: (pl) => '${pl.name} - ${money(pl.currency, pl.price)}',
              onChanged: (v) => setState(() => plan = v),
            ),
          const SizedBox(height: 14),
          AppField(
            controller: trial,
            label: 'saTrialDays'.tr,
            helper: 'saTrialDaysHelp'.tr,
            icon: Icons.hourglass_top_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          section('signupAdmin'.tr),
          Row(
            children: [
              Expanded(
                child: AppField(controller: first, label: 'firstName'.tr, required: true,
                    validator: Validators.required, capitalization: TextCapitalization.words),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppField(controller: last, label: 'lastName'.tr, required: true,
                    validator: Validators.required, capitalization: TextCapitalization.words),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppField(controller: username, label: 'username'.tr, icon: Icons.person_outline_rounded, required: true,
              validator: Validators.minLength(3)),
          const SizedBox(height: 14),
          AppField(controller: password, label: 'password'.tr, icon: Icons.lock_outline_rounded, required: true,
              helper: 'passwordPolicy'.tr, validator: Validators.minLength(8)),
          const SizedBox(height: 14),
          PhoneField(controller: adminPhone, label: 'saAdminPhone'.tr),
        ],
      );
    },
    onSubmit: () async {
      final res = await PlatformApi.post('companies', {
        'name': name.text.trim(),
        'slug': slug.text.trim().toLowerCase(),
        if (phone.text.trim().isNotEmpty) 'phone': Phone.normalize(phone.text) ?? phone.text.trim(),
        if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
        if (domain.text.trim().isNotEmpty) 'domain': domain.text.trim(),
        if (plan != null) 'plan_id': plan!.id,
        'trialDays': int.tryParse(trial.text.trim()) ?? 0,
        'admin': {
          'firstName': first.text.trim(),
          'lastName': last.text.trim(),
          'username': username.text.trim(),
          'password': password.text,
          if (adminPhone.text.trim().isNotEmpty) 'phoneNumber': Phone.normalize(adminPhone.text) ?? adminPhone.text,
        },
      });
      createdId = res is Map ? res['id']?.toString() : null;
    },
  );
  if (ok) {
    Toast.success('saCompanyCreatedMsg'.trParams({'code': slug.text.trim().toLowerCase(), 'user': username.text.trim()}),
        title: 'saCompanyCreated'.tr);
  }
  return ok ? createdId : null;
}
