import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class ProfileVm {
  const ProfileVm({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String role;
}

class StoreInfoVm {
  const StoreInfoVm({
    required this.storeId,
    required this.storeName,
    required this.address,
    required this.ownerName,
  });

  final String storeId;
  final String storeName;
  final String address;
  final String ownerName;
}

class ProfileStoreRepository {
  ProfileStoreRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  Future<ProfileVm> fetchProfile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw const ProfileFlowException('Phiên đăng nhập hết hạn.');
    }
    final userRow = await _supabase
        .from('users')
        .select('id, full_name, email, role')
        .eq('id', currentUser.id)
        .single();

    final storeId = await _resolveStoreId();
    final store = await _supabase
        .from('stores')
        .select('phone')
        .eq('id', storeId)
        .maybeSingle();

    return ProfileVm(
      userId: currentUser.id,
      fullName: (userRow['full_name'] ?? '').toString(),
      email: (userRow['email'] ?? currentUser.email ?? '').toString(),
      phone: (store?['phone'] ?? '').toString(),
      role: (userRow['role'] ?? '').toString().toUpperCase(),
    );
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? newPassword,
    String? oldPassword,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw const ProfileFlowException('Phiên đăng nhập hết hạn.');
    }

    await _supabase
        .from('users')
        .update({'full_name': fullName.trim()})
        .eq('id', currentUser.id);

    final storeId = await _resolveStoreId();
    await _supabase
        .from('stores')
        .update({'phone': phone.trim().isEmpty ? null : phone.trim()})
        .eq('id', storeId);

    final password = newPassword?.trim();
    if (password != null && password.isNotEmpty) {
      final currentEmail = (_supabase.auth.currentUser?.email ?? '').trim();
      final oldPass = oldPassword?.trim() ?? '';
      if (oldPass.isEmpty) {
        throw const ProfileFlowException('Vui lòng nhập mật khẩu cũ.');
      }
      if (currentEmail.isEmpty) {
        throw const ProfileFlowException(
          'Không tìm thấy email để xác minh mật khẩu cũ.',
        );
      }
      try {
        await _supabase.auth.signInWithPassword(
          email: currentEmail,
          password: oldPass,
        );
      } on AuthException {
        throw const ProfileFlowException('Mật khẩu cũ không đúng.');
      }
      if (password.length < 6) {
        throw const ProfileFlowException(
          'Mật khẩu mới phải có ít nhất 6 ký tự.',
        );
      }
      await _supabase.auth.updateUser(UserAttributes(password: password));
    }
  }

  Future<StoreInfoVm> fetchStoreInfo() async {
    final storeId = await _resolveStoreId();
    final store = await _supabase
        .from('stores')
        .select('id, name, address, owner_id')
        .eq('id', storeId)
        .single();
    final ownerId = (store['owner_id'] ?? '').toString();
    String ownerName = 'Chủ cửa hàng';
    if (ownerId.isNotEmpty) {
      final owner = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', ownerId)
          .maybeSingle();
      ownerName = (owner?['full_name'] ?? ownerName).toString();
    }
    return StoreInfoVm(
      storeId: store['id'].toString(),
      storeName: (store['name'] ?? '').toString(),
      address: (store['address'] ?? '').toString(),
      ownerName: ownerName,
    );
  }

  Future<void> updateStoreInfo({
    required String storeName,
    required String address,
  }) async {
    final storeId = await _resolveStoreId();
    await _supabase
        .from('stores')
        .update({
          'name': storeName.trim(),
          'address': address.trim().isEmpty ? null : address.trim(),
        })
        .eq('id', storeId);
  }

  Future<String> _resolveStoreId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const ProfileFlowException('Phiên đăng nhập hết hạn.');
    }

    final ownerStore = await _supabase
        .from('stores')
        .select('id')
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (ownerStore != null) {
      return ownerStore['id'].toString();
    }

    final employeeRow = await _supabase
        .from('employees')
        .select('store_id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (employeeRow != null) {
      return employeeRow['store_id'].toString();
    }

    throw const ProfileFlowException(
      'Chưa tìm thấy cửa hàng của tài khoản này.',
    );
  }
}

class ProfileFlowException implements Exception {
  const ProfileFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
