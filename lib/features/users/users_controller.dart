import 'package:get/get.dart';

import '../../app/app_controller.dart';
import '../../core/list_controller.dart';
import '../../core/utils/format.dart';
import '../../data/models/role.dart';
import '../../data/models/user.dart';
import '../../data/repositories.dart';

class UsersController extends ListController<AppUser> {
  /// Role zote (kwa jina la role la kila mtumiaji na fomu).
  final RxList<Role> roles = <Role>[].obs;

  @override
  Future<List<AppUser>> fetch() async {
    final users = await UserRepo.all();
    if (AppController.to.can(AppModule.permission)) {
      try {
        roles.assignAll(await RoleRepo.all());
      } catch (_) {}
    }
    return users;
  }

  String? roleName(String? id) {
    if (id == null) return null;
    for (final r in roles) {
      if (r.id == id) return r.name;
    }
    return null;
  }

  @override
  bool matches(AppUser u, String q) =>
      u.fullName.toLowerCase().contains(q) ||
      u.username.toLowerCase().contains(q) ||
      Phone.matches(u.phoneNumber, q) ||
      (roleName(u.roleId) ?? '').toLowerCase().contains(q);
}
