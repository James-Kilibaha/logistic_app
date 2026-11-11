import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/company.dart';
import '../../data/models/json.dart';
import '../company/subscription_page.dart' show subscriptionLook;
import 'platform_api.dart';
import 'platform_models.dart';
import 'sa_activity.dart';
import 'sa_audit.dart';
import 'sa_common.dart';
import 'sa_payments.dart' show openSubscriptionReceipt, reviewPayment;

const _methods = ['M-PESA', 'TIGO PESA', 'AIRTEL MONEY', 'HALOPESA', 'BANK', 'CASH'];

/// Kampuni moja: taarifa, subscription (malipo, kuongeza siku, mpango), watumiaji, kuzuia, kufuta.
class SaCompanyDetailPage extends StatefulWidget {
  final String companyId;

  const SaCompanyDetailPage({super.key, required this.companyId});

  @override
  State<SaCompanyDetailPage> createState() => _SaCompanyDetailPageState();
}

class _SaCompanyDetailPageState extends State<SaCompanyDetailPage> {
  int _version = 0;

  Future<CompanyDetail> _fetch() async =>
      CompanyDetail.fromJson(Map<String, dynamic>.from((await PlatformApi.get('companies/${widget.companyId}')) as Map));

  void _refresh() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text('saCompany'.tr),
        actions: [
          IconButton(tooltip: 'refresh'.tr, onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: SaLoader<CompanyDetail>(
        key: ValueKey(_version),
        load: _fetch,
        builder: (context, d, reload) => _Body(detail: d, reload: reload, onDeleted: () => Navigator.of(context).pop()),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CompanyDetail detail;
  final Future<void> Function() reload;
  final VoidCallback onDeleted;

  const _Body({required this.detail, required this.reload, required this.onDeleted});

  PlatformCompany get c => detail.company;

  // ------------------------------------------------------------------ vitendo

  Future<void> _edit() async {
    final name = TextEditingController(text: c.name);
    final slug = TextEditingController(text: c.slug);
    final legal = TextEditingController(text: c.legalName ?? '');
    final phone = TextEditingController(text: c.phone ?? '');
    final email = TextEditingController(text: c.email ?? '');
    final address = TextEditingController(text: c.address ?? '');
    final country = TextEditingController(text: c.country ?? '');
    final tin = TextEditingController(text: c.tin ?? '');
    final domain = TextEditingController(text: c.domain ?? '');
    final owner = TextEditingController(text: c.ownerName ?? '');
    final ownerPhone = TextEditingController(text: c.ownerPhone ?? '');
    final primary = TextEditingController(text: c.primaryColor ?? '');
    final accent = TextEditingController(text: c.accentColor ?? '');
    final notes = TextEditingController(text: c.notes ?? '');
    String? opt(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();
    String? color(TextEditingController t) {
      final v = t.text.trim().toUpperCase();
      if (v.isEmpty) return null;
      return v.startsWith('#') ? v : '#$v';
    }

    final ok = await showFormSheet(
      title: 'saEditCompany'.tr,
      icon: Icons.edit_outlined,
      maxWidth: 620,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: name, label: 'companyName'.tr, required: true, validator: Validators.required),
          const SizedBox(height: 14),
          AppField(controller: slug, label: 'companyCode'.tr, helper: 'saSlugChangeHelp'.tr, required: true,
              validator: Validators.minLength(3), icon: Icons.tag_rounded),
          const SizedBox(height: 14),
          AppField(controller: domain, label: 'saDomain'.tr, hint: 'ymg.co.tz', helper: 'saDomainHelp'.tr,
              icon: Icons.language_rounded),
          const SizedBox(height: 14),
          AppField(controller: legal, label: 'legalName'.tr),
          const SizedBox(height: 14),
          AppField(controller: phone, label: 'companyPhones'.tr, icon: Icons.call_outlined),
          const SizedBox(height: 14),
          AppField(controller: email, label: 'email'.tr, icon: Icons.alternate_email_rounded),
          const SizedBox(height: 14),
          AppField(controller: address, label: 'address'.tr),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppField(controller: country, label: 'country'.tr)),
            const SizedBox(width: 12),
            Expanded(child: AppField(controller: tin, label: 'tin'.tr)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppField(controller: owner, label: 'saOwner'.tr)),
            const SizedBox(width: 12),
            Expanded(child: PhoneField(controller: ownerPhone, label: 'saOwnerPhone'.tr)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppField(controller: primary, label: 'primaryColor'.tr, hint: '#1F4FD8')),
            const SizedBox(width: 12),
            Expanded(child: AppField(controller: accent, label: 'accentColor'.tr, hint: '#F59E0B')),
          ]),
          const SizedBox(height: 14),
          AppField(controller: notes, label: 'saNotes'.tr, helper: 'saNotesHelp'.tr, maxLines: 4, minLines: 2),
        ],
      ),
      onSubmit: () => PlatformApi.put('companies', {
        ...c.toUpdate(),
        'name': name.text.trim(),
        'slug': slug.text.trim().toLowerCase(),
        'legalName': opt(legal),
        'phone': opt(phone),
        'email': opt(email),
        'address': opt(address),
        'country': opt(country),
        'tin': opt(tin),
        'domain': opt(domain),
        'ownerName': opt(owner),
        'ownerPhone': opt(ownerPhone),
        'primaryColor': color(primary),
        'accentColor': color(accent),
        'notes': opt(notes),
      }),
    );
    if (ok) {
      Toast.success('saved'.tr);
      await reload();
    }
  }

  Future<void> _toggleStatus() async {
    final reason = TextEditingController();
    final suspend = !c.suspended;
    final ok = await showFormSheet(
      title: suspend ? 'saSuspendTitle'.tr : 'saActivateTitle'.tr,
      subtitle: suspend ? 'saSuspendMsg'.tr : 'saActivateMsg'.tr,
      icon: suspend ? Icons.block_rounded : Icons.check_circle_outline_rounded,
      danger: suspend,
      submitLabel: suspend ? 'saSuspend'.tr : 'saActivate'.tr,
      builder: (context, setState) =>
          AppField(controller: reason, label: 'saReason'.tr, maxLines: 3, minLines: 2),
      onSubmit: () => PlatformApi.put('companies/status', {
        'id': c.id,
        'status': suspend ? 'SUSPENDED' : 'ACTIVE',
        if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim(),
      }),
    );
    if (ok) await reload();
  }

  Future<void> _logo() async {
    final picked = await pickImage(camera: false);
    if (picked == null) return;
    if (await runGuarded(() => PlatformApi.upload('companies/${c.id}/logo', picked.bytes, picked.name),
        success: 'logoSaved'.tr)) {
      await reload();
    }
  }

  Future<void> _recordPayment() async {
    final plans = await _plans();
    if (plans == null) return;
    Plan plan = plans.firstWhere((pl) => pl.id == detail.subscription.plan?.id, orElse: () => plans.first);
    int periods = 1;
    String method = _methods.first;
    final amount = TextEditingController(text: Fmt.number(plan.price));
    final reference = TextEditingController();
    final note = TextEditingController();
    void recalc() => amount.text = Fmt.number(plan.price * periods);

    final ok = await showFormSheet(
      title: 'saRecordPayment'.tr,
      subtitle: 'saRecordPaymentSub'.tr,
      icon: Icons.payments_outlined,
      builder: (context, setState) => Column(
        children: [
          AppDropdown<Plan>(
            label: 'plan'.tr,
            value: plan,
            items: plans,
            itemLabel: (pl) => '${pl.name} - ${money(pl.currency, pl.price)}',
            onChanged: (v) => setState(() {
              if (v != null) plan = v;
              recalc();
            }),
          ),
          const SizedBox(height: 14),
          AppDropdown<int>(
            label: 'subPeriods'.tr,
            value: periods,
            items: const [1, 2, 3, 6, 12],
            itemLabel: (n) => 'subPeriodN'.trParams({'n': '$n', 'm': '${n * plan.months}'}),
            onChanged: (v) => setState(() {
              if (v != null) periods = v;
              recalc();
            }),
          ),
          const SizedBox(height: 14),
          AppField(controller: amount, label: 'amountPaid'.tr, required: true, validator: Validators.number,
              keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 14),
          AppDropdown<String>(
            label: 'paymentMethod'.tr,
            value: method,
            items: _methods,
            itemLabel: (m) => m,
            onChanged: (v) => setState(() => method = v ?? method),
          ),
          const SizedBox(height: 14),
          AppField(controller: reference, label: 'transactionRef'.tr),
          const SizedBox(height: 14),
          AppField(controller: note, label: 'note'.tr, maxLines: 3, minLines: 2),
        ],
      ),
      onSubmit: () => PlatformApi.post('subscriptions/payments', {
        'company_id': c.id,
        'plan_id': plan.id,
        'periods': periods,
        'amount': Fmt.parse(amount.text) ?? 0,
        'currency': plan.currency,
        'method': method,
        if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim(),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      }),
    );
    if (ok) {
      Toast.success('saPaymentRecorded'.tr);
      await reload();
    }
  }

  Future<void> _extend() async {
    final plans = await _plans();
    if (plans == null) return;
    Plan? plan = plans.where((pl) => pl.id == detail.subscription.plan?.id).firstOrNull;
    String status = 'ACTIVE';
    final days = TextEditingController(text: '30');
    final note = TextEditingController();
    final ok = await showFormSheet(
      title: 'saExtend'.tr,
      subtitle: 'saExtendSub'.tr,
      icon: Icons.more_time_rounded,
      builder: (context, setState) => Column(
        children: [
          AppField(controller: days, label: 'saDays'.tr, required: true, validator: Validators.positive,
              keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          AppDropdown<String>(
            label: 'saPeriodType'.tr,
            value: status,
            items: const ['ACTIVE', 'TRIAL'],
            itemLabel: (s) => s == 'TRIAL' ? 'subTrial'.tr : 'subActive'.tr,
            onChanged: (v) => setState(() => status = v ?? status),
          ),
          const SizedBox(height: 14),
          AppDropdown<Plan>(
            label: 'plan'.tr,
            value: plan,
            items: plans,
            required: false,
            hint: 'saCurrentPlanHint'.tr,
            itemLabel: (pl) => pl.name,
            onChanged: (v) => setState(() => plan = v),
          ),
          const SizedBox(height: 14),
          AppField(controller: note, label: 'note'.tr),
        ],
      ),
      onSubmit: () => PlatformApi.post('subscriptions/extend', {
        'company_id': c.id,
        if (plan != null) 'plan_id': plan!.id,
        'days': int.tryParse(days.text.trim()) ?? 0,
        'status': status,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      }),
    );
    if (ok) {
      Toast.success('saved'.tr);
      await reload();
    }
  }

  Future<void> _changePlan() async {
    final plans = await _plans();
    if (plans == null) return;
    Plan? plan = plans.where((pl) => pl.id == detail.subscription.plan?.id).firstOrNull ?? plans.first;
    final ok = await showFormSheet(
      title: 'saChangePlan'.tr,
      subtitle: 'saChangePlanSub'.tr,
      icon: Icons.swap_vert_rounded,
      builder: (context, setState) => AppDropdown<Plan>(
        label: 'plan'.tr,
        value: plan,
        items: plans,
        itemLabel: (pl) => '${pl.name} - ${money(pl.currency, pl.price)}',
        onChanged: (v) => setState(() => plan = v),
      ),
      onSubmit: () => PlatformApi.put('subscriptions/change-plan', {'company_id': c.id, 'plan_id': plan!.id}),
    );
    if (ok) {
      Toast.success('saved'.tr);
      await reload();
    }
  }

  Future<void> _cancelPeriod(SubscriptionPeriod period) async {
    final sure = await confirmAction(
      title: 'saCancelPeriod'.tr,
      message: 'saCancelPeriodMsg'.trParams({'from': Fmt.date(period.startsAt), 'to': Fmt.date(period.endsAt)}),
      confirmText: 'saCancelPeriod'.tr,
      icon: Icons.event_busy_outlined,
      danger: true,
    );
    if (!sure) return;
    if (await runGuarded(() => PlatformApi.put('subscriptions/${period.id}/cancel'), success: 'saved'.tr)) {
      await reload();
    }
  }

  Future<void> _resetPassword([TenantUser? user]) async {
    if (detail.users.isEmpty) return;
    TenantUser selected = user ?? detail.users.first;
    final password = TextEditingController();
    final ok = await showFormSheet(
      title: 'saResetPassword'.tr,
      subtitle: 'saResetPasswordSub'.tr,
      icon: Icons.lock_reset_rounded,
      builder: (context, setState) => Column(
        children: [
          AppDropdown<TenantUser>(
            label: 'username'.tr,
            value: selected,
            items: detail.users,
            itemLabel: (u) => '${u.username} - ${u.name}',
            onChanged: (v) => setState(() => selected = v ?? selected),
          ),
          const SizedBox(height: 14),
          AppField(controller: password, label: 'saNewPassword'.tr, required: true, helper: 'passwordPolicy'.tr,
              validator: Validators.minLength(8)),
        ],
      ),
      onSubmit: () => PlatformApi.post('companies/${c.id}/reset-password',
          {'username': selected.username, 'newPassword': password.text}),
    );
    if (ok) Toast.success('saResetDoneMsg'.trParams({'user': selected.username}), title: 'saved'.tr);
  }

  /// Kufungua app ya kampuni kama mtumiaji wake - KUANGALIA TU (kila kitu wanachoona, bila kubadilisha).
  Future<void> _viewAs() async {
    TenantUser? selected;
    Map<String, dynamic>? session;
    final ok = await showFormSheet(
      title: 'saViewAs'.tr,
      subtitle: 'saViewAsSub'.tr,
      icon: Icons.visibility_outlined,
      submitLabel: 'saViewAsOpen'.tr,
      builder: (context, setState) => AppDropdown<TenantUser>(
        label: 'saViewAsUser'.tr,
        value: selected,
        items: detail.users.where((u) => u.active).toList(),
        required: false,
        hint: 'saViewAsDefaultUser'.tr,
        itemLabel: (u) => '${u.name} (${u.username})',
        onChanged: (v) => setState(() => selected = v),
      ),
      onSubmit: () async {
        final res = await PlatformApi.post('companies/${c.id}/impersonate', {
          if (selected != null) 'user_id': selected!.id,
          'minutes': 60,
        });
        session = Map<String, dynamic>.from(res as Map);
      },
    );
    // (baada ya fomu kufungwa - kubadilisha ukurasa fomu ikiwa wazi kungeharibu navigation)
    if (!ok || session == null) return;
    await AppController.to.startViewAs(session!);
    Toast.info('saViewAsStarted'.trParams({'company': c.name}));
  }

  /// Kuthibitisha kampuni iliyojisajili: inafunguliwa na majaribio yanaanza leo.
  Future<void> _approve() async {
    final plans = await _plans();
    if (plans == null) return;
    Plan plan = plans.firstWhere((pl) => pl.id == c.signupPlanId, orElse: () => plans.first);
    final trial = TextEditingController(text: '14');
    final note = TextEditingController();
    final ok = await showFormSheet(
      title: 'saApproveTitle'.tr,
      subtitle: 'saApproveSub'.trParams({'name': c.name}),
      icon: Icons.how_to_reg_rounded,
      submitLabel: 'saApprove'.tr,
      builder: (context, setState) => Column(
        children: [
          AppDropdown<Plan>(
            label: 'plan'.tr,
            value: plan,
            items: plans,
            itemLabel: (pl) => '${pl.name} - ${money(pl.currency, pl.price)}'
                '${pl.id == c.signupPlanId ? ' (${'saRequested'.tr})' : ''}',
            onChanged: (v) => setState(() => plan = v ?? plan),
          ),
          const SizedBox(height: 14),
          AppField(controller: trial, label: 'saTrialDays'.tr, helper: 'saTrialDaysHelp'.tr,
              icon: Icons.hourglass_top_rounded, keyboardType: TextInputType.number, validator: Validators.number),
          const SizedBox(height: 14),
          AppField(controller: note, label: 'note'.tr, helper: 'saNotesHelp'.tr),
        ],
      ),
      onSubmit: () => PlatformApi.put('companies/${c.id}/approve', {
        'plan_id': plan.id,
        'trialDays': int.tryParse(trial.text.trim()) ?? 0,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      }),
    );
    if (ok) {
      Toast.success('saApprovedMsg'.trParams({'name': c.name}), title: 'saApproved'.tr);
      await reload();
    }
  }

  Future<void> _reject() async {
    final reason = TextEditingController();
    final ok = await showFormSheet(
      title: 'saRejectTitle'.tr,
      subtitle: 'saRejectSub'.tr,
      icon: Icons.cancel_outlined,
      danger: true,
      submitLabel: 'saReject'.tr,
      builder: (context, setState) => AppField(controller: reason, label: 'saReason'.tr, maxLines: 3, minLines: 2),
      onSubmit: () => PlatformApi.put('companies/${c.id}/reject',
          {if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim()}),
    );
    if (ok) await reload();
  }

  /// Nafasi za ziada juu ya mpango (watumiaji, ofisi, ankara) - kawaida ni 0 (kama mpango).
  Future<void> _limits() async {
    final users = TextEditingController(text: '${c.extraUsers}');
    final offices = TextEditingController(text: '${c.extraOffices}');
    final invoices = TextEditingController(text: '${c.extraInvoicesPerMonth}');
    final plan = detail.subscription.plan;
    String base(int? effective, int extra) => effective == null ? '∞' : '${effective - extra}';
    final ok = await showFormSheet(
      title: 'saExtraLimits'.tr,
      subtitle: 'saExtraLimitsSub'.tr,
      icon: Icons.group_add_outlined,
      builder: (context, setState) => Column(
        children: [
          AppField(
            controller: users,
            label: 'saExtraUsers'.tr,
            helper: 'saPlanGives'.trParams({'n': base(plan?.maxUsers, c.extraUsers)}),
            icon: Icons.person_add_alt_rounded,
            keyboardType: TextInputType.number,
            validator: Validators.number,
          ),
          const SizedBox(height: 14),
          AppField(
            controller: offices,
            label: 'saExtraOffices'.tr,
            helper: 'saPlanGives'.trParams({'n': base(plan?.maxOffices, c.extraOffices)}),
            icon: Icons.store_mall_directory_outlined,
            keyboardType: TextInputType.number,
            validator: Validators.number,
          ),
          const SizedBox(height: 14),
          AppField(
            controller: invoices,
            label: 'saExtraInvoices'.tr,
            helper: 'saPlanGives'.trParams({'n': base(plan?.maxInvoicesPerMonth, c.extraInvoicesPerMonth)}),
            icon: Icons.receipt_long_outlined,
            keyboardType: TextInputType.number,
            validator: Validators.number,
          ),
        ],
      ),
      onSubmit: () => PlatformApi.put('companies/${c.id}/limits', {
        'extraUsers': int.tryParse(users.text.trim()) ?? 0,
        'extraOffices': int.tryParse(offices.text.trim()) ?? 0,
        'extraInvoicesPerMonth': int.tryParse(invoices.text.trim()) ?? 0,
      }),
    );
    if (ok) {
      Toast.success('saved'.tr);
      await reload();
    }
  }

  Future<void> _delete() async {
    final confirm = TextEditingController();
    final ok = await showFormSheet(
      title: 'saDeleteCompany'.tr,
      subtitle: 'saDeleteCompanyMsg'.trParams({'code': c.slug}),
      icon: Icons.delete_forever_rounded,
      danger: true,
      submitLabel: 'delete'.tr,
      builder: (context, setState) => AppField(
        controller: confirm,
        label: 'saTypeCode'.trParams({'code': c.slug}),
        required: true,
        validator: (v) => (v ?? '').trim().toLowerCase() == c.slug ? null : 'saTypeCodeWrong'.tr,
      ),
      onSubmit: () => PlatformApi.delete('companies/${c.id}', query: {'confirm': confirm.text.trim().toLowerCase()}),
    );
    if (ok) {
      Toast.success(c.name, title: 'deleted'.tr);
      onDeleted();
    }
  }

  static Future<List<Plan>?> _plans() async {
    try {
      final plans = await loadPlans();
      if (plans.isEmpty) {
        Toast.warning('saNoPlans'.tr);
        return null;
      }
      return plans;
    } catch (e) {
      Toast.error(e);
      return null;
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = detail.subscription;
    final plan = st.plan;
    final (Color color, String label) = subscriptionLook(p, st.status);
    final logo = detail.logoUrl == null ? null : Session.absoluteUrl(detail.logoUrl!);
    final pending = detail.payments.where((x) => x.status == 'PENDING').toList();

    void copy(String text) {
      Clipboard.setData(ClipboardData(text: text));
      Toast.success(text, title: 'copied'.tr);
    }

    final approval = !c.awaitingApproval
        ? null
        : SectionCard(
            title: c.status == 'PENDING' ? 'saAwaitingApproval'.tr : 'saRejected'.tr,
            subtitle: c.status == 'PENDING' ? 'saApprovalCardSub'.tr : 'saRejectedCardSub'.tr,
            icon: Icons.how_to_reg_outlined,
            trailing: CompanyStatusPill(c.status),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: 'saRegistered'.tr, value: Fmt.dateTime(c.createdAt), icon: Icons.event_outlined),
                InfoRow(label: 'saOwner'.tr, value: [c.ownerName, c.ownerPhone].whereType<String>().join(' · ').ifEmpty('-'),
                    icon: Icons.person_outline_rounded),
                if (detail.users.isNotEmpty)
                  InfoRow(label: 'username'.tr, value: detail.users.map((u) => u.username).join(', '),
                      icon: Icons.admin_panel_settings_outlined),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _approve,
                      style: FilledButton.styleFrom(backgroundColor: p.success),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                      label: Text('saApprove'.tr),
                    ),
                    if (c.status == 'PENDING')
                      OutlinedButton.icon(
                        onPressed: _reject,
                        style: OutlinedButton.styleFrom(foregroundColor: p.danger),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text('saReject'.tr),
                      ),
                  ],
                ),
              ],
            ),
          );

    final info = SectionCard(
      title: c.name,
      subtitle: c.legalName,
      icon: Icons.apartment_rounded,
      trailing: CompanyStatusPill(c.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: logo == null
                    ? Icon(Icons.image_outlined, color: p.muted)
                    : Image.network(logo, fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: p.muted)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: _logo, icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text('uploadLogo'.tr)),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'companyCode'.tr, value: c.slug, icon: Icons.tag_rounded,
              trailing: IconButton(icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () => copy(c.slug))),
          if (detail.appUrl != null)
            InfoRow(label: 'appAddress'.tr, value: detail.appUrl!, icon: Icons.language_rounded,
                trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () => copy(detail.appUrl!))),
          InfoRow(label: 'companyPhones'.tr, value: c.phone ?? '-', icon: Icons.call_outlined),
          InfoRow(label: 'email'.tr, value: c.email ?? '-', icon: Icons.alternate_email_rounded),
          InfoRow(label: 'saOwner'.tr, value: [c.ownerName, c.ownerPhone].whereType<String>().join(' · ').ifEmpty('-'),
              icon: Icons.person_outline_rounded),
          InfoRow(label: 'saRegistered'.tr, value: '${Fmt.date(c.createdAt)} · ${c.source ?? '-'}',
              icon: Icons.event_outlined),
          InfoRow(
            label: 'WhatsApp',
            value: detail.whatsapp['ok'] == true
                ? [J.str(detail.whatsapp['displayPhone']), J.str(detail.whatsapp['verifiedName'])]
                        .where((x) => x.isNotEmpty)
                        .join(' · ') +
                    (detail.whatsapp['enabled'] == true ? '' : ' (${'waOff'.tr})')
                : (J.strOrNull(detail.whatsapp['error']) ?? 'waNotConnected'.tr),
            icon: Icons.chat_outlined,
          ),
          if (c.notes != null) ...[
            const SizedBox(height: 8),
            Text(c.notes!, style: TextStyle(color: p.muted, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: !c.isActive || detail.users.isEmpty ? null : _viewAs,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text('saViewAs'.tr),
              ),
              OutlinedButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('saEditCompany'.tr)),
              OutlinedButton.icon(
                onPressed: detail.users.isEmpty ? null : () => _resetPassword(),
                icon: const Icon(Icons.lock_reset_rounded, size: 18),
                label: Text('saResetPassword'.tr),
              ),
              if (!c.awaitingApproval)
                OutlinedButton.icon(
                  onPressed: _toggleStatus,
                  style: OutlinedButton.styleFrom(foregroundColor: c.suspended ? p.success : p.warning),
                  icon: Icon(c.suspended ? Icons.check_circle_outline_rounded : Icons.block_rounded, size: 18),
                  label: Text(c.suspended ? 'saActivate'.tr : 'saSuspend'.tr),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmAction(
                    title: 'saLogoutCompany'.tr,
                    message: 'saLogoutCompanyMsg'.trParams({'company': c.name}),
                    icon: Icons.logout_rounded,
                    danger: true,
                  );
                  if (ok) {
                    await runGuarded(() => PlatformApi.post('companies/${c.id}/logout-all'),
                        success: 'saLogoutCompanyDone'.tr);
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('saLogoutCompany'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () => saveZip(() => PlatformApi.getBytes('companies/${c.id}/export'), '${c.slug}_data'),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: Text('exportData'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () => Get.to(() => Scaffold(
                      appBar: AppBar(title: Text('${'saAudit'.tr} · ${c.name}')),
                      body: SaAudit(companyId: c.id, onOpenCompany: (_) {}),
                    )),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('saAudit'.tr),
              ),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: p.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text('saDeleteCompany'.tr),
              ),
            ],
          ),
        ],
      ),
    );

    final subscription = SectionCard(
      title: plan?.name ?? 'subNoPlan'.tr,
      subtitle: 'subscription'.tr,
      icon: Icons.workspace_premium_outlined,
      trailing: Pill(label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (st.endsAt != null)
            InfoRow(label: st.readOnly || st.status == 'GRACE' ? 'subEndedOn'.tr : 'subEndsOn'.tr,
                value: Fmt.date(st.endsAt), icon: Icons.event_outlined),
          if (st.daysLeft != null)
            InfoRow(label: 'subDaysLeft'.tr, value: '${st.daysLeft}', icon: Icons.hourglass_bottom_rounded,
                emphasize: (st.daysLeft ?? 99) <= 7),
          if (st.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('saReadOnlyNote'.tr, style: TextStyle(color: p.danger, fontSize: 13)),
            ),
          const SizedBox(height: 12),
          Text('subUsage'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 6),
          InfoRow(label: 'users'.tr, value: _limit(detail.usage.users, plan?.maxUsers, c.extraUsers),
              icon: Icons.people_outline),
          InfoRow(label: 'offices'.tr, value: _limit(detail.usage.offices, plan?.maxOffices, c.extraOffices),
              icon: Icons.store_mall_directory_outlined),
          InfoRow(label: 'subInvoicesMonth'.tr,
              value: _limit(detail.usage.invoicesThisMonth, plan?.maxInvoicesPerMonth, c.extraInvoicesPerMonth),
              icon: Icons.receipt_long_outlined),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: _recordPayment, icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text('saRecordPayment'.tr)),
              OutlinedButton.icon(onPressed: _extend, icon: const Icon(Icons.more_time_rounded, size: 18),
                  label: Text('saExtend'.tr)),
              OutlinedButton.icon(onPressed: _changePlan, icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: Text('saChangePlan'.tr)),
              OutlinedButton.icon(onPressed: _limits, icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text('saExtraLimits'.tr)),
            ],
          ),
        ],
      ),
    );

    final payments = SectionCard(
      title: 'subPayments'.tr,
      icon: Icons.receipt_long_outlined,
      trailing: pending.isEmpty ? null : Pill('subPendingMsg'.trParams({'n': '${pending.length}'}), color: p.warning, dense: true),
      child: detail.payments.isEmpty
          ? Text('subNoPayments'.tr, style: TextStyle(color: p.muted))
          : Column(
              children: [
                for (final pay in detail.payments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${money(pay.currency, pay.amount)} · ${pay.planName} x${pay.periods}'),
                    subtitle: Text([
                      Fmt.dateTime(pay.createdAt),
                      if (pay.method != null) pay.method!,
                      if (pay.reference != null) pay.reference!,
                    ].join(' · ')),
                    trailing: pay.status == 'PENDING'
                        ? Wrap(spacing: 4, children: [
                            IconButton(
                              tooltip: 'saConfirm'.tr,
                              icon: Icon(Icons.check_circle_rounded, color: p.success),
                              onPressed: () async {
                                if (await reviewPayment(pay.id, confirm: true)) await reload();
                              },
                            ),
                            IconButton(
                              tooltip: 'saReject'.tr,
                              icon: Icon(Icons.cancel_rounded, color: p.danger),
                              onPressed: () async {
                                if (await reviewPayment(pay.id, confirm: false)) await reload();
                              },
                            ),
                          ])
                        : pay.status == 'CONFIRMED'
                            ? IconButton(
                                tooltip: 'subReceipt'.tr,
                                icon: Icon(Icons.receipt_rounded, color: p.success),
                                onPressed: () => openSubscriptionReceipt(pay.id, reference: pay.reference),
                              )
                            : Text('subRejected'.tr, style: TextStyle(color: p.danger, fontSize: 12.5)),
                  ),
              ],
            ),
    );

    final history = SectionCard(
      title: 'subHistory'.tr,
      icon: Icons.history_rounded,
      child: detail.history.isEmpty
          ? Text('saNoHistory'.tr, style: TextStyle(color: p.muted))
          : Column(
              children: [
                for (final h in detail.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${h.planName} · ${h.status == 'CANCELLED' ? 'saCancelled'.tr : subscriptionLook(p, h.status).$2}'),
                    subtitle: Text('${Fmt.date(h.startsAt)} → ${Fmt.date(h.endsAt)}${h.note == null ? '' : ' · ${h.note}'}'),
                    trailing: h.status == 'CANCELLED'
                        ? null
                        : IconButton(
                            tooltip: 'saCancelPeriod'.tr,
                            icon: Icon(Icons.event_busy_outlined, color: p.muted),
                            onPressed: () => _cancelPeriod(h),
                          ),
                  ),
              ],
            ),
    );

    final overview = _OverviewCard(companyId: c.id);

    final activity = SectionCard(
      title: 'saCompanyActivity'.tr,
      subtitle: 'saCompanyActivitySub'.tr,
      icon: Icons.timeline_rounded,
      child: ActivityFeed(companyId: c.id, pageSize: 30, showCompany: false),
    );

    final users = SectionCard(
      title: 'users'.tr,
      subtitle: 'saUsersSub'.tr,
      icon: Icons.people_alt_outlined,
      child: Column(
        children: [
          for (final u in detail.users)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(u.active ? Icons.person_outline_rounded : Icons.person_off_outlined,
                  color: u.active ? p.primary : p.muted),
              title: Text('${u.name} (${u.username})'),
              subtitle: u.phone == null ? null : Text(Fmt.phone(u.phone)),
              trailing: IconButton(
                tooltip: 'saResetPassword'.tr,
                icon: const Icon(Icons.lock_reset_rounded),
                onPressed: () => _resetPassword(u),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 900) {
        return PageScroll(onRefresh: reload, children: [
          if (approval != null) approval,
          info, overview, subscription, activity, payments, history, users,
        ]);
      }
      Widget column(List<Widget> items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (int i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 16), items[i]]],
          );
      return PageScroll(onRefresh: reload, children: [
        if (approval != null) approval,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: column([info, overview, users])),
          const SizedBox(width: 16),
          Expanded(child: column([subscription, activity, payments, history])),
        ]),
      ]);
    });
  }

  /// "2 / 5 (+2 za ziada)": matumizi / kikomo halisi (mpango + nafasi za ziada).
  static String _limit(int used, int? max, [int extra = 0]) {
    if (max == null) return '$used / ∞';
    return extra > 0 ? '$used / $max (${'saPlusExtra'.trParams({'n': '$extra'})})' : '$used / $max';
  }
}

/// Takwimu za kampuni: wanachofanya kwenye mfumo.
class _OverviewCard extends StatelessWidget {
  final String companyId;

  const _OverviewCard({required this.companyId});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(
      title: 'saOverview'.tr,
      subtitle: 'saOverviewSub'.tr,
      icon: Icons.insights_rounded,
      child: SaLoader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from((await PlatformApi.get('companies/$companyId/overview')) as Map),
        builder: (context, d, reload) {
          final c = J.map(d['counts']) ?? const {};
          final m = J.map(d['money']) ?? const {};
          final lastLogin = J.map(d['lastLogin']);
          final lastAction = J.map(d['lastActivity']);
          int n(String k) => J.integer(c[k]);
          Widget stat(String label, String value, IconData icon, [String? hint]) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: p.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text)),
                          Text(label, style: TextStyle(color: p.muted, fontSize: 12)),
                          if (hint != null) Text(hint, style: TextStyle(color: p.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          String month(int v) => 'saThisMonthN'.trParams({'n': '$v'});
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveGrid(
                minItemWidth: 170,
                children: [
                  stat('saStatCustomers'.tr, '${n('customers')}', Icons.people_alt_outlined, month(n('customersMonth'))),
                  stat('saStatInvoices'.tr, '${n('invoices')}', Icons.receipt_long_outlined, month(n('invoicesMonth'))),
                  stat('saStatBoxes'.tr, '${n('boxes')}', Icons.inventory_2_outlined, month(n('boxesMonth'))),
                  stat('saStatPayments'.tr, money(J.str(m['currency'], 'TZS'), J.dbl(m['paidMonth'])),
                      Icons.payments_outlined, 'saStatPaymentsHint'.trParams({'n': '${n('paymentsMonth')}'})),
                  stat('saStatSms'.tr, '${n('smsMonth')}', Icons.sms_outlined, 'saStatSmsHint'.trParams({'n': '${n('sms')}'})),
                  stat('saStatActions'.tr, '${n('actionsWeek')}', Icons.bolt_rounded,
                      '${'users'.tr}: ${n('users')} · ${'offices'.tr}: ${n('offices')}'),
                ],
              ),
              const SizedBox(height: 12),
              InfoRow(
                label: 'saLastLoginCompany'.tr,
                value: lastLogin == null ? '-' : '${Fmt.dateTime(J.date(lastLogin['at']))} · ${J.str(lastLogin['username'])}',
                icon: Icons.login_rounded,
              ),
              InfoRow(
                label: 'saLastActivity'.tr,
                value: lastAction == null
                    ? '-'
                    : '${Fmt.dateTime(J.date(lastAction['at']))} · ${J.str(lastAction['username'])} · ${J.str(lastAction['summary'])}',
                icon: Icons.history_toggle_off_rounded,
              ),
              InfoRow(
                label: 'saPaidTotal'.tr,
                value: money(J.str(m['currency'], 'TZS'), J.dbl(m['paidTotal'])),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
