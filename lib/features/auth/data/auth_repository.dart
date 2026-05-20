import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

enum PostLoginRoute { main, createStore }

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<void> signUpOwner({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _client.auth.signUp(
      email: normalizedEmail,
      password: password,
    );

    final userId = response.user?.id ?? _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFlowException(
        'Dang ky thanh cong nhung chua co session. Hay tat email confirmation de demo nhanh.',
      );
    }

    await _client.from('users').upsert({
      'id': userId,
      'full_name': fullName,
      'email': normalizedEmail,
      'role': 'OWNER',
      'is_active': true,
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<PostLoginRoute> resolvePostLoginRoute() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFlowException('Khong tim thay session dang nhap.');
    }

    final user = await _client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = (user?['role'] ?? '').toString().toUpperCase();
    if (role != 'OWNER') {
      return PostLoginRoute.main;
    }

    final ownerStore = await _client
        .from('stores')
        .select('id')
        .eq('owner_id', userId)
        .limit(1)
        .maybeSingle();
    if (ownerStore == null) {
      return PostLoginRoute.createStore;
    }
    return PostLoginRoute.main;
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
