import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant.dart';

final selectedTenantProvider = StateProvider<Tenant?>((ref) => null);

final selectedTenantIdProvider = Provider<String?>((ref) {
  return ref.watch(selectedTenantProvider)?.id;
});
