import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/lookups.dart';
import '../../data/models/claim.dart';
import '../../data/models/invoice.dart';
import '../../data/models/settings.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

const List<String> claimTypes = ['DAMAGED', 'LOST', 'SHORT'];

String claimTypeLabel(String t) => 'claim_$t'.tr;

String claimStatusLabel(String s) => 'claimSt_$s'.tr;

Color claimStatusColor(AppPalette p, String s) => switch (s) {
      'OPEN' => p.warning,
      'APPROVED' || 'SETTLED' => p.success,
      _ => p.danger,
    };

class ClaimFlows {
  ClaimFlows._();

  /// Kuripoti mzigo ulioharibika / kupotea / katoni pungufu.
  static Future<bool> report(Invoice invoice) async {
    String type = 'DAMAGED';
    Product? product = invoice.products.length == 1 ? invoice.products.first : null;
    final cartons = TextEditingController();
    final description = TextEditingController();
    PickedImage? photo;
    final ok = await showFormSheet(
      help: 'formClaim',
      title: 'reportCargoProblem'.tr,
      subtitle: '${'invoice'.tr} ${invoice.number} · ${invoice.customer?.name ?? ''}',
      icon: Icons.report_problem_outlined,
      builder: (context, setState) {
        final p = context.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel('problemType'.tr, required: true),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final t in claimTypes) ButtonSegment(value: t, label: Text(claimTypeLabel(t)))],
              selected: {type},
              onSelectionChanged: (v) => setState(() => type = v.first),
            ),
            const SizedBox(height: 16),
            if (invoice.products.isNotEmpty)
              AppDropdown<Product?>(
                label: 'cargoItem'.tr,
                value: product,
                items: [null, ...invoice.products],
                required: false,
                icon: Icons.inventory_2_outlined,
                itemLabel: (x) => x == null ? 'wholeInvoice'.tr : '${x.description} (${Fmt.number(x.quantities)} ${'ctn'.tr})',
                onChanged: (v) => setState(() => product = v),
              ),
            const SizedBox(height: 16),
            AppField.number(controller: cartons, label: 'cartonsAffected'.tr, icon: Icons.layers_outlined),
            const SizedBox(height: 16),
            AppField(
              controller: description,
              label: 'whatHappened'.tr,
              icon: Icons.notes_rounded,
              required: true,
              maxLines: 3,
              minLines: 2,
              capitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final img = await pickImage();
                    if (img != null) setState(() => photo = img);
                  },
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(photo == null ? 'addPhoto'.tr : 'retakePhoto'.tr),
                ),
                if (photo != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(photo!.bytes, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  IconButton(onPressed: () => setState(() => photo = null), icon: Icon(Icons.close_rounded, color: p.muted)),
                ],
              ],
            ),
          ],
        );
      },
      onSubmit: () => ClaimRepo.create(
        invoiceId: invoice.id,
        productId: product?.id,
        type: type,
        cartons: Fmt.parse(cartons.text),
        description: description.text,
        photo: photo?.bytes,
        photoName: photo?.name,
      ),
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(claimTypeLabel(type), title: 'claimRecorded'.tr);
    }
    return ok;
  }

  /// Uamuzi: kukubali (na fidia) au kukataa.
  static Future<bool> resolve(CargoClaim claim) async {
    List<Institute> institutes = const [];
    try {
      institutes = await Lookups.to.loadInstitutes();
    } catch (_) {}
    String status = 'APPROVED';
    String settlement = 'DISCOUNT';
    Institute? institute = institutes.isEmpty ? null : institutes.first;
    final amount = TextEditingController();
    final resolution = TextEditingController();
    final ok = await showFormSheet(
      help: 'formClaim',
      title: 'resolveClaim'.tr,
      subtitle: '${claimTypeLabel(claim.type)} · ${'invoice'.tr} #${claim.invoiceNumber ?? ''}',
      icon: Icons.gavel_rounded,
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(claim.description, style: TextStyle(color: context.palette.muted)),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'APPROVED', icon: const Icon(Icons.check_rounded), label: Text('approve'.tr)),
              ButtonSegment(value: 'REJECTED', icon: const Icon(Icons.close_rounded), label: Text('reject'.tr)),
            ],
            selected: {status},
            onSelectionChanged: (v) => setState(() => status = v.first),
          ),
          if (status == 'APPROVED') ...[
            const SizedBox(height: 16),
            AppField.money(controller: amount, label: 'compensationTsh'.tr, required: false, helper: 'compensationHelp'.tr),
            const SizedBox(height: 12),
            FieldLabel('compensationHow'.tr),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'DISCOUNT', label: Text('settleDiscount'.tr)),
                ButtonSegment(value: 'REFUND', label: Text('settleRefund'.tr)),
              ],
              selected: {settlement},
              onSelectionChanged: (v) => setState(() => settlement = v.first),
            ),
            if (settlement == 'REFUND' && institutes.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppDropdown<Institute>(
                label: 'refundThrough'.tr,
                value: institute,
                items: institutes,
                icon: Icons.account_balance_outlined,
                itemLabel: (i) => '${i.name} · ${i.accountNo}',
                onChanged: (v) => setState(() => institute = v),
              ),
            ],
          ],
          const SizedBox(height: 16),
          AppField(controller: resolution, label: 'decisionNote'.tr, icon: Icons.notes_rounded, required: true, maxLines: 2),
        ],
      ),
      onSubmit: () {
        final comp = status == 'APPROVED' ? (Fmt.parse(amount.text) ?? 0) : 0.0;
        return ClaimRepo.resolve(
          claim.id,
          status: status,
          compensation: comp,
          settlement: comp > 0 ? settlement : 'NONE',
          instituteId: comp > 0 && settlement == 'REFUND' ? institute?.id : null,
          resolution: resolution.text,
        );
      },
    );
    if (ok) {
      AppController.to.notifyChanged();
      Toast.success(claimStatusLabel(status), title: 'changesSaved'.tr);
    }
    return ok;
  }

  static Future<void> showPhoto(CargoClaim claim) async {
    try {
      final Uint8List bytes = await ClaimRepo.photo(claim.id);
      await Get.dialog<void>(Dialog(child: InteractiveViewer(child: Image.memory(bytes))));
    } catch (e) {
      Toast.error(e);
    }
  }
}

/// Dai moja (kwenye orodha au ndani ya ankara).
class ClaimTile extends StatelessWidget {
  final CargoClaim claim;
  final bool showInvoice;

  const ClaimTile({super.key, required this.claim, this.showInvoice = true});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canResolve = claim.isOpen && AppController.to.can(AppModule.claim, AppAction.update);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Pill(claimTypeLabel(claim.type), color: p.danger, dense: true),
            const SizedBox(width: 6),
            Pill(claimStatusLabel(claim.status), color: claimStatusColor(p, claim.status), dense: true),
            const Spacer(),
            Text(Fmt.date(claim.createdAt), style: TextStyle(color: p.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        if (showInvoice)
          Text('#${claim.invoiceNumber ?? ''} · ${claim.customerName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          [
            if (claim.productName != null) claim.productName!,
            if (claim.cartons != null) '${Fmt.number(claim.cartons)} ${'ctn'.tr}',
          ].join(' · '),
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
        Text(claim.description),
        if (!claim.isOpen && claim.resolution != null) ...[
          const SizedBox(height: 4),
          Text(
            '${'decision'.tr}: ${claim.resolution}'
            '${claim.compensation > 0 ? ' · ${Fmt.tsh(claim.compensation)} (${'settle_${claim.settlement}'.tr})' : ''}'
            '${claim.resolvedByName != null ? ' · ${claim.resolvedByName}' : ''}',
            style: TextStyle(color: claimStatusColor(p, claim.status), fontSize: 12.5),
          ),
        ],
        Row(
          children: [
            if (claim.hasPhoto)
              TextButton.icon(
                onPressed: () => ClaimFlows.showPhoto(claim),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text('photo'.tr),
              ),
            const Spacer(),
            if (canResolve)
              FilledButton.tonalIcon(
                onPressed: () => ClaimFlows.resolve(claim),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: Text('resolveClaim'.tr),
              ),
          ],
        ),
      ],
    );
  }
}
