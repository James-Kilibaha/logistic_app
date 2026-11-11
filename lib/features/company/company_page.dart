import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../core/branding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/states.dart';
import '../../data/models/company.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

enum _Kind { text, multiline, integer, decimal, toggle, secret }

class _Setting {
  final String key;
  final String label;
  final _Kind kind;
  final String? hint;

  const _Setting(this.key, this.label, this.kind, [this.hint]);
}

const _business = [
  _Setting('COMPANY_ORIGIN', 'setOrigin', _Kind.text, 'Guangzhou China'),
  _Setting('COMPANY_PAYMENT_INFO', 'setPaymentInfo', _Kind.multiline, 'CRDB [TSh]\n0150...\nM-Pesa 6870...'),
  _Setting('DAYS_TO_CHARGE', 'setFreeDays', _Kind.integer),
  _Setting('STORAGE_CHARGE_USD', 'setStorageCharge', _Kind.decimal),
  _Setting('DEFAULT_CREDIT_LIMIT', 'setCreditLimit', _Kind.decimal),
  _Setting('ETA_AIR_DAYS', 'setEtaAir', _Kind.integer),
  _Setting('ETA_SEA_DAYS', 'setEtaSea', _Kind.integer),
  _Setting('PUBLIC_TRACKING', 'setPublicTracking', _Kind.toggle),
  _Setting('REMINDERS_ENABLED', 'setReminders', _Kind.toggle),
  _Setting('REMINDER_EVERY_DAYS', 'setReminderEvery', _Kind.integer),
  _Setting('STORAGE_WARN_DAYS', 'setStorageWarn', _Kind.integer),
  _Setting('TIMEZONE', 'setTimezone', _Kind.text, 'Africa/Dar_es_Salaam'),
];

const _sms = [
  _Setting('SMS_SOURCE_NAME', 'setSmsSender', _Kind.text, 'MYCOMPANY'),
  _Setting('SMS_AUTO_SEND', 'setSmsAuto', _Kind.toggle),
  _Setting('SMS_CLIENT_ID', 'setSmsClientId', _Kind.text),
  _Setting('SMS_CLIENT_SECRET', 'setSmsSecret', _Kind.secret),
  _Setting('SMS_BALANCE_API', 'setSmsBalanceApi', _Kind.text),
  _Setting('SMS_LOW_BALANCE', 'setSmsLow', _Kind.integer),
];

/// Rangi za haraka za kuchagua (au andika #RRGGBB).
const _swatches = [
  Color(0xFF1F4FD8), Color(0xFF0A7A3E), Color(0xFFB91C1C), Color(0xFF7C3AED), Color(0xFF0E7490),
  Color(0xFFC2410C), Color(0xFF0F172A), Color(0xFFBE185D), Color(0xFF4D7C0F), Color(0xFFA16207),
];

/// "Kampuni yetu": jina, logo, rangi (branding) na mipangilio ya biashara (SMS, stoo, WhatsApp ...).
class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  CompanyProfile? _profile;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  bool _saving = false;

  final _name = TextEditingController();
  final _legal = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _country = TextEditingController();
  final _tin = TextEditingController();
  final _primary = TextEditingController();
  final _accent = TextEditingController();

  final Map<String, TextEditingController> _text = {};
  final Map<String, bool?> _toggles = {};

  bool get _canEdit => AppController.to.can(AppModule.setting, AppAction.update);

  @override
  void initState() {
    super.initState();
    for (final s in [..._business, ..._sms]) {
      if (s.kind != _Kind.toggle) _text[s.key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _legal, _phone, _email, _address, _country, _tin, _primary, _accent, ..._text.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final profile = await CompanyRepo.profile();
      _fill(profile);
      setState(() {
        _profile = profile;
        _status = LoadStatus.ready;
      });
    } catch (e) {
      setState(() {
        _status = LoadStatus.error;
        _error = e.toString();
      });
    }
  }

  void _fill(CompanyProfile c) {
    _name.text = c.name;
    _legal.text = c.legalName ?? '';
    _phone.text = c.phone ?? '';
    _email.text = c.email ?? '';
    _address.text = c.address ?? '';
    _country.text = c.country ?? '';
    _tin.text = c.tin ?? '';
    _primary.text = c.primary == null ? '' : colorHex(c.primary!);
    _accent.text = c.accent == null ? '' : colorHex(c.accent!);
    for (final s in [..._business, ..._sms]) {
      final v = c.settings[s.key];
      if (s.kind == _Kind.toggle) {
        _toggles[s.key] = v is bool ? v : null;
      } else {
        _text[s.key]!.text = v == null ? '' : _plain(v);
      }
    }
  }

  static String _plain(dynamic v) {
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  String? _hex(String raw) {
    final v = raw.trim().toUpperCase();
    if (v.isEmpty) return null;
    final h = v.startsWith('#') ? v : '#$v';
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(h) ? h : null;
  }

  Future<void> _saveProfile() async {
    if (_name.text.trim().length < 2) {
      Toast.warning('fieldRequired'.tr, title: 'companyName'.tr);
      return;
    }
    for (final c in [_primary, _accent]) {
      if (c.text.trim().isNotEmpty && _hex(c.text) == null) {
        Toast.warning('colorInvalid'.tr);
        return;
      }
    }
    setState(() => _saving = true);
    final ok = await runGuarded(() async {
      await CompanyRepo.updateProfile({
        'name': _name.text.trim(),
        'legalName': _legal.text.trim().isEmpty ? null : _legal.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'country': _country.text.trim().isEmpty ? null : _country.text.trim(),
        'tin': _tin.text.trim().isEmpty ? null : _tin.text.trim(),
        'primaryColor': _hex(_primary.text),
        'accentColor': _hex(_accent.text),
      });
      await BrandingController.to.refreshCompany();
    }, success: 'saved'.tr);
    if (mounted) setState(() => _saving = false);
    if (ok) await _load();
  }

  Future<void> _saveSettings(List<_Setting> group) async {
    final values = <String, dynamic>{};
    for (final s in group) {
      if (s.kind == _Kind.toggle) {
        values[s.key] = _toggles[s.key];
      } else {
        values[s.key] = _text[s.key]!.text.trim();
      }
    }
    setState(() => _saving = true);
    final ok = await runGuarded(() => CompanyRepo.updateSettings(values), success: 'saved'.tr);
    if (mounted) setState(() => _saving = false);
    if (ok) await _load();
  }

  Future<void> _uploadLogo() async {
    final picked = await pickImage(camera: false);
    if (picked == null) return;
    final ok = await runGuarded(() async {
      await CompanyRepo.uploadLogo(picked.bytes, picked.name);
      await BrandingController.to.refreshCompany();
    }, success: 'logoSaved'.tr);
    if (ok) await _load();
  }

  Future<void> _removeLogo() async {
    final sure = await confirmAction(
      title: 'removeLogo'.tr,
      message: 'removeLogoMsg'.tr,
      confirmText: 'delete'.tr,
      icon: Icons.hide_image_outlined,
      danger: true,
    );
    if (!sure) return;
    final ok = await runGuarded(() async {
      await CompanyRepo.deleteLogo();
      await BrandingController.to.refreshCompany();
    }, success: 'deleted'.tr);
    if (ok) await _load();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'companyProfile'.tr,
      subtitle: 'companyProfileSub'.tr,
      showBack: true,
      actions: [
        IconButton(tooltip: 'refresh'.tr, onPressed: _status == LoadStatus.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded)),
      ],
      body: _profile == null
          ? (_status == LoadStatus.error
              ? ErrorState(message: _error ?? 'errUnknown'.tr, onRetry: _load)
              : const LoadingList())
          : _content(context, _profile!),
    );
  }

  Widget _content(BuildContext context, CompanyProfile c) {
    final cards = <Widget>[
      _identityCard(context, c),
      _profileCard(context),
      _settingsCard(context, 'businessSettings'.tr, 'businessSettingsSub'.tr, Icons.tune_rounded, _business, c),
      _settingsCard(
        context,
        'smsSettings'.tr,
        c.ownSms ? 'smsOwnGateway'.tr : (c.platformSms ? 'smsPlatformGateway'.tr : 'smsNoGateway'.tr),
        Icons.sms_outlined,
        _sms,
        c,
      ),
      SectionCard(
        title: 'whatsappSettings'.tr,
        subtitle: 'waCardSub'.tr,
        icon: Icons.chat_outlined,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => Get.toNamed(Routes.whatsapp),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text('waManage'.tr),
          ),
        ),
      ),
      SectionCard(
        title: 'payMobileTitle'.tr,
        subtitle: 'payCardSub'.tr,
        icon: Icons.phone_iphone_rounded,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => Get.toNamed(Routes.onlinePay),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text('payManage'.tr),
          ),
        ),
      ),
      SectionCard(
        title: 'exportData'.tr,
        subtitle: 'exportDataSub'.tr,
        icon: Icons.archive_outlined,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => saveZip(CompanyRepo.exportData, '${c.slug}_data'),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('exportDownload'.tr),
          ),
        ),
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 900) return PageScroll(children: cards);
      final left = <Widget>[cards[0], cards[1], cards[5]], right = <Widget>[cards[2], cards[3], cards[4], cards[6]];
      Widget column(List<Widget> items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (int i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i]]],
          );
      return PageScroll(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: column(left)),
          const SizedBox(width: 16),
          Expanded(child: column(right)),
        ]),
      ]);
    });
  }

  Widget _identityCard(BuildContext context, CompanyProfile c) {
    final p = context.palette;
    final url = c.branding.appUrl;
    return SectionCard(
      title: 'companyIdentity'.tr,
      subtitle: 'companyIdentitySub'.tr,
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandLogo(size: 72, elevated: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 4),
                    Text('logoHelp'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
                    if (_canEdit) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: _uploadLogo,
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: Text('uploadLogo'.tr),
                        ),
                        if (c.branding.logoUrl != null)
                          TextButton.icon(
                            onPressed: _removeLogo,
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: p.danger),
                            label: Text('removeLogo'.tr, style: TextStyle(color: p.danger)),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InfoRow(
            label: 'companyCode'.tr,
            value: c.slug,
            icon: Icons.tag_rounded,
            trailing: IconButton(
              tooltip: 'copy'.tr,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: c.slug));
                Toast.success(c.slug, title: 'copied'.tr);
              },
            ),
          ),
          if (url != null)
            InfoRow(
              label: 'appAddress'.tr,
              value: url,
              icon: Icons.language_rounded,
              trailing: IconButton(
                tooltip: 'copy'.tr,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Toast.success(url, title: 'copied'.tr);
                },
              ),
            ),
          const SizedBox(height: 8),
          Text('companyCodeShare'.tr, style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(Routes.subscription),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: Text('subscription'.tr),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context) {
    final enabled = _canEdit;
    return SectionCard(
      title: 'companyDetails'.tr,
      subtitle: 'companyDetailsSub'.tr,
      icon: Icons.apartment_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(controller: _name, label: 'companyName'.tr, required: true, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _legal, label: 'legalName'.tr, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _phone, label: 'companyPhones'.tr, hint: '0670 000 000 / 0753 000 000',
              helper: 'companyPhonesHelp'.tr, icon: Icons.call_outlined, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _email, label: 'email'.tr, icon: Icons.alternate_email_rounded, enabled: enabled),
          const SizedBox(height: 14),
          AppField(controller: _address, label: 'address'.tr, icon: Icons.place_outlined, enabled: enabled),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppField(controller: _country, label: 'country'.tr, enabled: enabled)),
            const SizedBox(width: 12),
            Expanded(child: AppField(controller: _tin, label: 'tin'.tr, enabled: enabled)),
          ]),
          const SizedBox(height: 18),
          _colorField(context, 'primaryColor'.tr, _primary, enabled),
          const SizedBox(height: 14),
          _colorField(context, 'accentColor'.tr, _accent, enabled),
          if (enabled) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving ? const ButtonSpinner() : const Icon(Icons.save_outlined, size: 18),
              label: Text('save'.tr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorField(BuildContext context, String label, TextEditingController controller, bool enabled) {
    final p = context.palette;
    final current = _hex(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: current == null ? p.surfaceAlt : Color(int.parse('FF${current.substring(1)}', radix: 16)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: current == null ? Icon(Icons.palette_outlined, color: p.muted, size: 20) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: '#1F4FD8 (${'defaultColor'.tr})'),
              ),
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _swatches)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => controller.text = colorHex(c)),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: current == colorHex(c) ? p.text : Colors.white, width: 2),
                    ),
                  ),
                ),
              TextButton(onPressed: () => setState(() => controller.clear()), child: Text('defaultColor'.tr)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _settingsCard(BuildContext context, String title, String subtitle, IconData icon, List<_Setting> group,
      CompanyProfile c) {
    final p = context.palette;
    final enabled = _canEdit;
    return SectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in group) ...[
            if (s.kind == _Kind.toggle)
              _toggleRow(context, s, c, enabled)
            else
              AppField(
                controller: _text[s.key],
                label: s.label.tr,
                hint: s.hint ?? _defaultHint(c, s.key),
                helper: c.defaults[s.key] != null && s.kind != _Kind.secret
                    ? 'defaultValue'.trParams({'v': _plain(c.defaults[s.key])})
                    : null,
                obscure: s.kind == _Kind.secret,
                enabled: enabled,
                maxLines: s.kind == _Kind.multiline ? 4 : 1,
                minLines: s.kind == _Kind.multiline ? 3 : null,
                keyboardType: switch (s.kind) {
                  _Kind.integer => TextInputType.number,
                  _Kind.decimal => const TextInputType.numberWithOptions(decimal: true),
                  _Kind.multiline => TextInputType.multiline,
                  _ => TextInputType.text,
                },
              ),
            const SizedBox(height: 12),
          ],
          Text('settingsEmptyDefault'.tr, style: TextStyle(color: p.muted, fontSize: 12.5)),
          if (enabled) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveSettings(group),
              icon: _saving ? const ButtonSpinner() : const Icon(Icons.save_outlined, size: 18),
              label: Text('save'.tr),
            ),
          ],
        ],
      ),
    );
  }

  String? _defaultHint(CompanyProfile c, String key) {
    final v = c.defaults[key];
    return v == null ? null : _plain(v);
  }

  Widget _toggleRow(BuildContext context, _Setting s, CompanyProfile c, bool enabled) {
    final p = context.palette;
    final value = _toggles[s.key];
    final fallback = c.defaults[s.key] == true;
    final effective = value ?? fallback;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.label.tr, style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
              if (value == null)
                Text('usingDefault'.tr, style: TextStyle(color: p.muted, fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: effective,
          onChanged: enabled ? (v) => setState(() => _toggles[s.key] = v) : null,
        ),
      ],
    );
  }
}
