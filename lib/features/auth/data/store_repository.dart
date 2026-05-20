import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class StoreRepository {
  StoreRepository({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<void> createOwnerStore({required String name, String? address}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const StoreFlowException(
        'Phien dang nhap da het han. Vui long dang nhap lai.',
      );
    }

    await _client.from('stores').insert({
      'owner_id': userId,
      'name': name,
      'address': address?.trim().isEmpty ?? true ? null : address!.trim(),
    });
  }
}

class StoreFlowException implements Exception {
  const StoreFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
