import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/branding.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/help.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/lookups.dart';
import '../../data/models/misc.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import '../auth/change_password_page.dart';
import '../auth/server_dialog.dart';
import '../company/subscription_page.dart';
import '../sms/sms_page.dart';
import 'auto_sms_card.dart';
import 'ops_cards.dart';
import 'popup_card.dart';
import 'rate_forms.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _lookups = Lookups.to;
  List<SmsSetting> _sms = const [];
  List<Currency> _allCurrencies = const []; // pamoja na viwango vya zamani (historia)
  bool _loading = false;

  bool get _business => AppController.to.can(AppModule.setting);

  bool get _canAdd => AppController.to.can(AppModule.setting, AppAction.insert);

  /// Bei na viwango vya fedha vina ruhusa yake (PRICE).
  bool get _prices => AppController.to.can(AppModule.price);

  bool get _canPrice => AppController.to.can(AppModule.price, AppAction.insert);

  // Sarafu/bei: ruhusa ya PRICE au ya SETTING (kama backend).
  bool get _canPriceEdit =>
      AppController.to.can(AppModule.price, AppAction.update) || AppController.to.can(AppModule.setting, AppAction.update);

  bool get _canPriceDelete =>
      AppController.to.can(AppModule.price, AppAction.delete) || AppController.to.can(AppModule.setting, AppAction.delete);

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  bool get _canDelete => AppController.to.can(AppModule.setting, AppAction.delete);

  @override
  void initState() {
    super.initState();
    if (_business || _prices) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        if (_prices) _lookups.loadCurrencies(force: true),
        if (_prices) _lookups.loadPrices(force: true),
        if (_business) _lookups.loadInstitutes(force: true),
        if (_business) _lookups.loadOffices(force: true),
      ]);
      if (_business) _sms = await SettingsRepo.smsSettings();
      if (_prices) _allCurrencies = await SettingsRepo.currencies();
    } catch (e) {
      Toast.error(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ------------------------------------------------------------- fomu

  Future<void> _addCurrency({String? code}) async {
    if (await showCurrencyForm(currency: code)) await _load();
  }

  Future<void> _addPrice({Price? current}) async {
    if (await showPriceForm(current: current)) await _load();
  }

  Future<void> _addInstitute({Institute? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final account = TextEditingController(text: current?.accountNo ?? '');
    final currency = TextEditingController(text: current?.currencyType ?? 'TSH');
    final ok = await showFormSheet(
      help: 'settings',
      title: current == null ? 'newInstitute'.tr : 'editInstitute'.tr,
      subtitle: 'newInstituteSub'.tr,
      icon: Icons.account_balance_outlined,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: name, label: 'instituteName'.tr, hint: 'CRDB, NMB, M-Pesa...', required: true),
          const SizedBox(height: 16),
          AppField(controller: account, label: 'accountNo'.tr, icon: Icons.numbers_rounded, required: true),
          const SizedBox(height: 16),
          AppField(controller: currency, label: 'currency'.tr, icon: Icons.attach_money_rounded, required: true),
        ],
      ),
      onSubmit: () => current == null
          ? SettingsRepo.createInstitute(name: name.text, accountNo: account.text, currencyType: currency.text)
          : SettingsRepo.updateInstitute(
              id: current.id, name: name.text, accountNo: account.text, currencyType: currency.text),
    );
    if (ok) {
      Toast.success(name.text, title: 'saved'.tr);
      await _load();
    }
  }

  Future<void> _addOffice({Office? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final location = TextEditingController(text: current?.location ?? '');
    final phone = TextEditingController(text: current?.phoneNumber ?? '');
    final ok = await showFormSheet(
      help: 'settings',
      title: current == null ? 'newOffice'.tr : 'editOffice'.tr,
      icon: Icons.store_mall_directory_outlined,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: name, label: 'officeName'.tr, hint: 'Kariakoo', required: true),
          const SizedBox(height: 16),
          AppField(controller: location, label: 'location'.tr, hint: 'Dar es Salaam', icon: Icons.place_outlined, required: true),
          const SizedBox(height: 16),
          PhoneField(controller: phone),
        ],
      ),
      onSubmit: () => current == null
          ? SettingsRepo.createOffice(name: name.text, location: location.text, phone: Phone.forApi(phone.text))
          : SettingsRepo.updateOffice(
              id: current.id, name: name.text, location: location.text, phone: Phone.forApi(phone.text)),
    );
    if (ok) {
      Toast.success(name.text, title: 'saved'.tr);
      await _load();
    }
  }

  Future<void> _deleteOffice(Office o) async {
    final ok = await confirmAction(
      title: 'deleteOffice'.tr,
      message: 'deleteOfficeMsg'.trParams({'name': o.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    try {
      final archived = await SettingsRepo.deleteOffice(o.id);
      Toast.success(archived ? 'archivedNote'.tr : o.name, title: 'deleted'.tr);
      await _load();
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _deleteInstitute(Institute i) async {
    final ok = await confirmAction(
      title: 'deleteInstitute'.tr,
      message: 'deleteInstituteMsg'.trParams({'name': i.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    try {
      final archived = await SettingsRepo.deleteInstitute(i.id);
      Toast.success(archived ? 'archivedNote'.tr : i.name, title: 'deleted'.tr);
      await _load();
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _deleteCurrency(Currency c) async {
    final ok = await confirmAction(
      title: 'deleteCurrency'.tr,
      message: 'deleteCurrencyMsg'.trParams({'name': c.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    if (await runGuarded(() => SettingsRepo.deleteCurrency(c.id), success: 'deleted'.tr)) await _load();
  }

  /// Kiwango kilichokosewa: kinafutwa na cha awali kinarudi kutumika.
  Future<void> _deleteRate(Currency c, Currency? previous) async {
    final ok = await confirmAction(
      title: 'deleteRate'.tr,
      message: previous == null
          ? 'deleteRateOnlyMsg'.trParams({'code': c.name})
          : 'deleteRateMsg'.trParams({
              'code': c.name,
              'rate': Fmt.tsh(c.buy),
              'previous': Fmt.tsh(previous.buy),
            }),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    try {
      final restored = await SettingsRepo.deleteCurrencyRate(c.id);
      Toast.success(restored == null ? c.name : '1 ${c.name} = ${Fmt.tsh(restored)}', title: 'deleted'.tr);
      await Future.wait([_lookups.loadCurrencies(force: true), _lookups.loadPrices(force: true)]);
      await _load();
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _deletePrice(Price pr) async {
    final ok = await confirmAction(
      title: 'deletePrice'.tr,
      message: 'deletePriceMsg'.trParams(
          {'price': '${currencySymbol(pr.name)}${Fmt.number(pr.cost)} / ${Fmt.number(pr.weight)} ${pr.unitLabel}'}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return;
    if (await runGuarded(() => SettingsRepo.deletePrice(pr.id), success: 'deleted'.tr)) await _load();
  }

  Future<void> _toggleSms(SmsSetting s) async {
    try {
      final updated = await SettingsRepo.toggleSms(s.id);
      setState(() => _sms = [for (final e in _sms) e.id == s.id ? updated : e]);
    } catch (e) {
      Toast.error(e);
    }
  }

  // -------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (_business) const _CompanyCard(),
      const _AccountCard(),
      const _AppearanceCard(),
      if (_prices) ...[
        Obx(() => _RatesCard(
              currencies: _lookups.currencies.toList(),
              history: _allCurrencies,
              onAdd: _canPrice ? () => _addCurrency() : null,
              onChange: _canPrice ? (c) => _addCurrency(code: c.name) : null,
              onCorrect: _canPriceEdit
                  ? (c) async {
                      if (await showCorrectRateForm(c)) await _load();
                    }
                  : null,
              onDelete: _canPriceDelete ? _deleteCurrency : null,
              onDeleteRate: _canPriceDelete ? _deleteRate : null,
            )),
        Obx(() => _PricesCard(
              prices: _lookups.prices.toList(),
              onAdd: _canPrice ? () => _addPrice() : null,
              onChange: _canPrice ? (pr) => _addPrice(current: pr) : null,
              onDelete: _canPriceDelete ? _deletePrice : null,
            )),
      ],
      if (_business) ...[
        Obx(() => _ListCard(
              title: 'institutes'.tr,
              subtitle: 'institutesSub'.tr,
              icon: Icons.account_balance_outlined,
              onAdd: _canAdd ? _addInstitute : null,
              empty: 'noInstitutes'.tr,
              rows: [
                for (final i in _lookups.institutes)
                  _Row(
                    title: i.name,
                    subtitle: '${i.accountNo} · ${'accKind_${i.kind}'.tr} · ${i.currencyType.toUpperCase()}',
                    icon: Icons.account_balance_outlined,
                    onEdit: _canEdit ? () => _addInstitute(current: i) : null,
                    onDelete: _canDelete ? () => _deleteInstitute(i) : null,
                  ),
              ],
            )),
        Obx(() => _ListCard(
              title: 'offices'.tr,
              subtitle: 'officesSub'.tr,
              icon: Icons.store_mall_directory_outlined,
              onAdd: _canAdd ? _addOffice : null,
              empty: 'noOffices'.tr,
              rows: [
                for (final o in _lookups.offices)
                  _Row(
                    title: o.name,
                    subtitle: [o.location, if (o.phoneNumber != null) Fmt.phone(o.phoneNumber)].join(' · '),
                    icon: Icons.place_outlined,
                    onEdit: _canEdit ? () => _addOffice(current: o) : null,
                    onDelete: _canDelete ? () => _deleteOffice(o) : null,
                  ),
              ],
            )),
        _SmsCard(items: _sms, onToggle: AppController.to.can(AppModule.setting, AppAction.update) ? _toggleSms : null),
        const AutoSmsCard(),
        const PopupRulesCard(),
        // Backup na hali ya server sasa ni za mtoa huduma (admin panel ya mfumo), si za kila kampuni.
        if (AppController.to.can(AppModule.dataImport, AppAction.insert)) const ImportCard(),
      ],
    ];

    return AppPage(
      help: 'settings',
      title: 'navSettings'.tr,
      subtitle: 'hintSettings'.tr,
      actions: [
        if (_business || _prices)
          IconButton(
            tooltip: 'refresh'.tr,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 900) return PageScroll(children: cards);
        // Safu mbili kwenye kompyuta.
        final left = <Widget>[], right = <Widget>[];
        for (int i = 0; i < cards.length; i++) {
          (i.isEven ? left : right).add(cards[i]);
        }
        Widget column(List<Widget> items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i]],
              ],
            );
        return PageScroll(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: column(left)),
                const SizedBox(width: 16),
                Expanded(child: column(right)),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Kampuni yetu: branding (jina, logo, rangi), mipangilio ya biashara na subscription.
class _CompanyCard extends StatelessWidget {
  const _CompanyCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final brand = BrandingController.to.current.value;
      final st = BrandingController.to.subscription.value;
      return SectionCard(
        title: 'companyProfile'.tr,
        subtitle: 'companyCardSub'.tr,
        icon: Icons.apartment_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandLogo(size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(brand.displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text)),
                      Text('${'companyCode'.tr}: ${brand.slug}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (st != null)
                  Builder(builder: (context) {
                    final (Color color, String label) = subscriptionLook(p, st.status);
                    return Pill(st.plan == null ? label : '${st.plan!.name} · $label', color: color, dense: true);
                  }),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Get.toNamed(Routes.company),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text('companyEdit'.tr),
                ),
                OutlinedButton.icon(
                  onPressed: () => Get.toNamed(Routes.subscription),
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text('subscription'.tr),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Obx(() {
      final u = AppController.to.user.value;
      return SectionCard(
        title: 'account'.tr,
        icon: Icons.person_outline_rounded,
        child: Column(
          children: [
            Row(
              children: [
                Initials(u?.initials ?? '?', size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u?.fullName ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text)),
                      Text('@${u?.username ?? ''} · ${Fmt.phone(u?.phoneNumber)}', style: TextStyle(color: p.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showServerDialog(),
                    icon: const Icon(Icons.dns_outlined, size: 20),
                    label: Text('server'.tr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: .4))),
                    onPressed: () async {
                      final ok = await confirmAction(
                        title: 'logout'.tr,
                        message: 'logoutConfirm'.tr,
                        confirmText: 'logout'.tr,
                        icon: Icons.logout_rounded,
                        danger: true,
                      );
                      if (ok) await AppController.to.logout();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: Text('logout'.tr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => Get.to(() => const HelpCenterPage()),
                icon: const Icon(Icons.menu_book_outlined, size: 20),
                label: Text('helpCenter'.tr),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: ChangePasswordPage.open,
                    icon: const Icon(Icons.password_rounded, size: 20),
                    label: Text('changePassword'.tr),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await confirmAction(
                        title: 'logoutEverywhere'.tr,
                        message: 'logoutEverywhereMsg'.tr,
                        confirmText: 'logoutEverywhere'.tr,
                        icon: Icons.devices_other_rounded,
                        danger: true,
                      );
                      if (!ok) return;
                      if (await runGuarded(AccountRepo.logoutEverywhere)) await AppController.to.logout();
                    },
                    icon: const Icon(Icons.devices_other_rounded, size: 20),
                    label: Text('logoutEverywhere'.tr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(Session.server, style: TextStyle(color: p.muted, fontSize: 12)),
          ],
        ),
      );
    });
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final app = AppController.to;
    return SectionCard(
      title: 'appearance'.tr,
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel('theme'.tr),
          Obx(() => SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text('light'.tr)),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text('dark'.tr)),
                  ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text('system'.tr)),
                ],
                selected: {app.themeMode.value},
                onSelectionChanged: (v) => app.setTheme(v.first),
              )),
          const SizedBox(height: 18),
          FieldLabel('language'.tr),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'sw', label: Text('Kiswahili')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {Get.locale?.languageCode == 'en' ? 'en' : 'sw'},
            onSelectionChanged: (v) =>
                app.setLocale(v.first == 'en' ? const Locale('en', 'US') : const Locale('sw', 'TZ')),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _Row({required this.title, required this.subtitle, required this.icon, this.onEdit, this.onDelete});
}

/// Vitufe vya kuhariri / kufuta mwishoni mwa mstari (vinaonekana kwa wenye ruhusa tu).
class _RowActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? editTooltip;

  const _RowActions({this.onEdit, this.onDelete}) : editTooltip = null;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            tooltip: editTooltip ?? 'edit'.tr,
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: p.primary, size: 20),
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'delete'.tr,
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: p.danger, size: 20),
          ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAdd;
  final String empty;
  final List<_Row> rows;

  const _ListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
    required this.empty,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      trailing: onAdd == null
          ? null
          : TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20), label: Text('add'.tr)),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(empty, style: TextStyle(color: p.muted)),
            )
          : Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(rows[i].icon, size: 20, color: p.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rows[i].title, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                              if (rows[i].subtitle.isNotEmpty)
                                Text(rows[i].subtitle, style: TextStyle(color: p.muted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        _RowActions(onEdit: rows[i].onEdit, onDelete: rows[i].onDelete),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Mpangilio wa aina za SMS kwenye Mipangilio (kama ulivyo kwenye SmsKind: mizigo, vikumbusho, za mkono, usalama).
int _smsOrder(String code) {
  final k = SmsKind.fromCode(code);
  return k == null ? 999 : k.index;
}

class _SmsCard extends StatelessWidget {
  final List<SmsSetting> items;
  final void Function(SmsSetting)? onToggle;

  const _SmsCard({required this.items, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: 'smsTypes'.tr,
      subtitle: 'smsTypesSub'.tr,
      icon: Icons.sms_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('loading'.tr, style: TextStyle(color: p.muted)),
            )
          : Column(
              children: [
                for (final s in [...items]..sort((a, b) => _smsOrder(a.name).compareTo(_smsOrder(b.name))))
                  SwitchListTile(
                    contentPadding: const EdgeInsets.only(right: 4),
                    value: s.enabled,
                    onChanged: onToggle == null ? null : (_) => onToggle!(s),
                    title: Text(smsKindLabel(SmsKind.fromCode(s.name)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('smsDesc_${s.name}'.tr),
                  ),
              ],
            ),
    );
  }
}


/// Viwango vya sarafu: kiwango cha sasa, cha awali na mabadiliko (%).
class _RatesCard extends StatelessWidget {
  final List<Currency> currencies;
  final List<Currency> history;
  final VoidCallback? onAdd;
  final void Function(Currency c)? onChange;
  final void Function(Currency c)? onCorrect;
  final void Function(Currency c)? onDelete;
  final void Function(Currency c, Currency? previous)? onDeleteRate;

  const _RatesCard({
    required this.currencies,
    required this.history,
    this.onAdd,
    this.onChange,
    this.onCorrect,
    this.onDelete,
    this.onDeleteRate,
  });

  Currency? _previous(Currency c) {
    final older = history
        .where((h) => h.name.toUpperCase() == c.name.toUpperCase() && h.id != c.id)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return older.isEmpty ? null : older.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: 'exchangeRates'.tr,
      subtitle: 'exchangeRatesSub'.tr,
      icon: Icons.currency_exchange_rounded,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      trailing: onAdd == null
          ? null
          : TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20), label: Text('add'.tr)),
      child: currencies.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('noRates'.tr, style: TextStyle(color: p.muted)),
            )
          : Column(
              children: [
                for (int i = 0; i < currencies.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  Builder(builder: (context) {
                    final c = currencies[i];
                    final prev = _previous(c);
                    final double? change = prev == null || prev.buy <= 0 ? null : (c.buy - prev.buy) / prev.buy * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              currencySymbol(c.name),
                              style: TextStyle(color: p.primary, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('1 ${c.name} = ${Fmt.tsh(c.buy)}',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 15)),
                                Text(
                                  prev == null
                                      ? '${'since'.tr} ${Fmt.date(c.createdAt)}'
                                      : '${'previousRate'.tr}: ${Fmt.tsh(prev.buy)} · ${'since'.tr} ${Fmt.date(c.createdAt)}',
                                  style: TextStyle(color: p.muted, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          if (change != null && change.abs() >= .05)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Pill(
                                '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                                color: change > 0 ? p.danger : p.success,
                                icon: change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                dense: true,
                              ),
                            ),
                          if (onChange != null)
                            IconButton(
                              tooltip: 'changeRate'.tr,
                              onPressed: () => onChange!(c),
                              icon: Icon(Icons.edit_outlined, color: p.primary, size: 20),
                            ),
                          if (onDeleteRate != null)
                            IconButton(
                              tooltip: 'deleteRate'.tr,
                              onPressed: () => onDeleteRate!(c, prev),
                              icon: Icon(Icons.delete_outline_rounded, color: p.danger, size: 20),
                            ),
                          if (onCorrect != null || onDelete != null)
                            PopupMenuButton<String>(
                              tooltip: 'more'.tr,
                              icon: Icon(Icons.more_vert_rounded, color: p.muted, size: 20),
                              onSelected: (v) => v == 'correct' ? onCorrect?.call(c) : onDelete?.call(c),
                              itemBuilder: (_) => [
                                if (onCorrect != null)
                                  PopupMenuItem(
                                    value: 'correct',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.build_outlined, size: 20),
                                      title: Text('correctRate'.tr),
                                    ),
                                  ),
                                if (onDelete != null)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.delete_outline_rounded, size: 20, color: p.danger),
                                      title: Text('deleteCurrency'.tr, style: TextStyle(color: p.danger)),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}

/// Bei za usafirishaji, pamoja na thamani kwa shilingi kwa kilo.
class _PricesCard extends StatelessWidget {
  final List<Price> prices;
  final VoidCallback? onAdd;
  final void Function(Price p)? onChange;
  final void Function(Price p)? onDelete;

  const _PricesCard({required this.prices, this.onAdd, this.onChange, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: 'shippingPrices'.tr,
      subtitle: 'shippingPricesSub'.tr,
      icon: Icons.sell_outlined,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      trailing: onAdd == null
          ? null
          : TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 20), label: Text('add'.tr)),
      child: prices.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('noPrices'.tr, style: TextStyle(color: p.muted)),
            )
          : Column(
              children: [
                for (int i = 0; i < prices.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.scale_outlined, color: p.muted, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${currencySymbol(prices[i].name)}${Fmt.number(prices[i].cost)} / '
                                '${Fmt.number(prices[i].weight)} ${prices[i].unitLabel}',
                                style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
                              ),
                              Text(
                                '≈ ${Fmt.tsh(prices[i].costPerKgLocal)} / ${prices[i].unitLabel} · '
                                '1 ${prices[i].name} = ${Fmt.tsh(prices[i].currency?.buy)}',
                                style: TextStyle(color: p.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        if (onChange != null)
                          IconButton(
                            tooltip: 'changePrice'.tr,
                            onPressed: () => onChange!(prices[i]),
                            icon: Icon(Icons.edit_outlined, color: p.primary, size: 20),
                          ),
                        if (onDelete != null)
                          IconButton(
                            tooltip: 'deletePrice'.tr,
                            onPressed: () => onDelete!(prices[i]),
                            icon: Icon(Icons.delete_outline_rounded, color: p.danger, size: 20),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
