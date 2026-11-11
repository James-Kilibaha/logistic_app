import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/inputs.dart';
import '../../data/models/customer.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';
import 'customer_detail_page.dart';

class CustomerFlows {
  CustomerFlows._();

  static Future<void> open(Customer customer) async {
    await Get.to(() => CustomerDetailPage(customer: customer), preventDuplicates: false);
  }

  /// Kusajili mteja mpya ([customer] == null) au kubadilisha taarifa zake.
  static Future<Customer?> edit({Customer? customer, String? initialName}) async {
    final name = TextEditingController(text: customer?.name ?? initialName ?? '');
    final phone = TextEditingController(text: customer?.phoneNumber ?? '');
    final limit = TextEditingController(
        text: customer?.creditLimit == null ? '' : Fmt.money(customer!.creditLimit));
    final canCredit = AppController.to.can(AppModule.credit, AppAction.update);
    Customer? saved;

    final ok = await showFormSheet(
      help: 'formCustomer',
      title: customer == null ? 'newCustomer'.tr : 'editCustomer'.tr,
      subtitle: customer == null ? 'newCustomerSub'.tr : customer.name,
      icon: customer == null ? Icons.person_add_alt_1_outlined : Icons.edit_outlined,
      submitLabel: customer == null ? 'register'.tr : 'saveChanges'.tr,
      builder: (context, setState) => Column(
        children: [
          AppField(
            controller: name,
            label: 'fullName'.tr,
            hint: 'fullNameHint'.tr,
            icon: Icons.person_outline_rounded,
            required: true,
            autofocus: customer == null,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          PhoneField(controller: phone, textInputAction: TextInputAction.done),
          if (canCredit) ...[
            const SizedBox(height: 16),
            AppField.money(
              controller: limit,
              label: 'creditLimitOptional'.tr,
              hint: 'creditLimitHint'.tr,
              helper: 'creditLimitHelper'.tr,
              icon: Icons.credit_score_outlined,
              required: false,
              validator: Validators.number,
            ),
          ],
        ],
      ),
      onSubmit: () async {
        saved = customer == null
            ? await CustomerRepo.create(name: name.text, phone: Phone.forApi(phone.text))
            : await CustomerRepo.update(id: customer.id, name: name.text, phone: Phone.forApi(phone.text));
        final double? wanted = limit.text.trim().isEmpty ? null : Fmt.parse(limit.text);
        if (canCredit && saved != null && wanted != (customer?.creditLimit)) {
          saved = await CustomerRepo.setCreditLimit(saved!.id, wanted);
        }
      },
    );

    // Controllers hazifutwi hapa: fomu bado inaweza kuwa ikifungwa (animation).
    if (!ok) return null;
    AppController.to.notifyChanged();
    Toast.success(saved?.name ?? '', title: customer == null ? 'customerRegistered'.tr : 'changesSaved'.tr);
    return saved;
  }

  static Future<bool> toggleBlock(Customer customer) async {
    final blocking = customer.isActive;
    final ok = await confirmAction(
      title: blocking ? 'blockCustomer'.tr : 'unblockCustomer'.tr,
      message: (blocking ? 'blockCustomerMsg' : 'unblockCustomerMsg').trParams({'name': customer.name}),
      confirmText: blocking ? 'block'.tr : 'unblock'.tr,
      icon: blocking ? Icons.block_rounded : Icons.lock_open_rounded,
      danger: blocking,
    );
    if (!ok) return false;
    final done = await runGuarded(
      () => CustomerRepo.toggleBlock(customer.id),
      success: blocking ? 'customerBlocked'.tr : 'customerUnblocked'.tr,
    );
    if (done) AppController.to.notifyChanged();
    return done;
  }

  static Future<bool> delete(Customer customer) async {
    final ok = await confirmAction(
      title: 'deleteCustomer'.tr,
      message: 'deleteCustomerMsg'.trParams({'name': customer.name}),
      confirmText: 'delete'.tr,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!ok) return false;
    final done = await runGuarded(() => CustomerRepo.delete(customer.id), success: 'deleted'.tr);
    if (done) AppController.to.notifyChanged();
    return done;
  }
}
