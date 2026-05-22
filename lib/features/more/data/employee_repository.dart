import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class EmployeeVm {
  const EmployeeVm({
    required this.employeeId,
    required this.userId,
    required this.name,
    required this.email,
    required this.isActive,
  });

  final String employeeId;
  final String userId;
  final String name;
  final String email;
  final bool isActive;

  EmployeeVm copyWith({String? name, String? email, bool? isActive}) {
    return EmployeeVm(
      employeeId: employeeId,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
    );
  }
}

class EmployeeRepository {
  EmployeeRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  static final List<EmployeeVm> _localEmployees = [
    const EmployeeVm(
      employeeId: 'local-1',
      userId: 'u-local-1',
      name: 'Hoang Ngoc',
      email: 'hoangngoc@demo.local',
      isActive: true,
    ),
    const EmployeeVm(
      employeeId: 'local-2',
      userId: 'u-local-2',
      name: 'Tran Minh',
      email: 'tranminh@demo.local',
      isActive: true,
    ),
  ];

  Future<List<EmployeeVm>> fetchEmployees() async {
    if (!SupabaseBootstrap.isInitialized) {
      return List<EmployeeVm>.from(_localEmployees);
    }

    final storeId = await _resolveStoreId();
    final employeeRows = await _supabase
        .from('employees')
        .select('id, user_id, is_active')
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    final employees = List<Map<String, dynamic>>.from(employeeRows);
    if (employees.isEmpty) {
      return [];
    }

    final userIds = employees
        .map((e) => e['user_id'].toString())
        .toSet()
        .toList();
    final userRows = await _supabase
        .from('users')
        .select('id, full_name, email')
        .inFilter('id', userIds);
    final userMap = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(userRows)) {
      userMap[row['id'].toString()] = row;
    }

    return employees.map((row) {
      final userId = row['user_id'].toString();
      final user = userMap[userId];
      return EmployeeVm(
        employeeId: row['id'].toString(),
        userId: userId,
        name: (user?['full_name'] ?? '').toString().trim().isEmpty
            ? 'Nhân viên'
            : user!['full_name'].toString(),
        email: (user?['email'] ?? '').toString(),
        isActive: row['is_active'] == true,
      );
    }).toList();
  }

  Future<EmployeeVm> addEmployee({
    required String fullName,
    required String email,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final item = EmployeeVm(
        employeeId: DateTime.now().microsecondsSinceEpoch.toString(),
        userId: 'u-${DateTime.now().millisecondsSinceEpoch}',
        name: fullName,
        email: email,
        isActive: true,
      );
      _localEmployees.add(item);
      return item;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final storeId = await _resolveStoreId();
    final user = await _supabase
        .from('users')
        .select('id, full_name, email')
        .eq('email', normalizedEmail)
        .maybeSingle();
    if (user == null) {
      throw const EmployeeFlowException(
        'Email chưa tồn tại. Hãy tạo tài khoản cho nhân viên trước.',
      );
    }

    final userId = user['id'].toString();
    if (fullName.trim().isNotEmpty && fullName.trim() != user['full_name']) {
      await _supabase
          .from('users')
          .update({'full_name': fullName.trim()})
          .eq('id', userId);
    }

    final existing = await _supabase
        .from('employees')
        .select('id, is_active')
        .eq('store_id', storeId)
        .eq('user_id', userId)
        .maybeSingle();

    String employeeId;
    bool isActive = true;
    if (existing != null) {
      employeeId = existing['id'].toString();
      await _supabase
          .from('employees')
          .update({'is_active': true})
          .eq('id', employeeId);
    } else {
      final inserted = await _supabase
          .from('employees')
          .insert({'store_id': storeId, 'user_id': userId, 'is_active': true})
          .select('id')
          .single();
      employeeId = inserted['id'].toString();
    }

    return EmployeeVm(
      employeeId: employeeId,
      userId: userId,
      name: fullName.trim().isEmpty
          ? (user['full_name'] ?? '').toString()
          : fullName.trim(),
      email: (user['email'] ?? '').toString(),
      isActive: isActive,
    );
  }

  Future<EmployeeVm> updateEmployee({
    required EmployeeVm employee,
    required String fullName,
    required bool isActive,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final index = _localEmployees.indexWhere(
        (e) => e.employeeId == employee.employeeId,
      );
      if (index < 0) {
        throw const EmployeeFlowException('Không tìm thấy nhân viên.');
      }
      final updated = _localEmployees[index].copyWith(
        name: fullName,
        isActive: isActive,
      );
      _localEmployees[index] = updated;
      return updated;
    }

    await _supabase
        .from('users')
        .update({'full_name': fullName})
        .eq('id', employee.userId);
    await _supabase
        .from('employees')
        .update({'is_active': isActive})
        .eq('id', employee.employeeId);

    return employee.copyWith(name: fullName, isActive: isActive);
  }

  Future<void> deleteEmployee(String employeeId) async {
    if (!SupabaseBootstrap.isInitialized) {
      _localEmployees.removeWhere((e) => e.employeeId == employeeId);
      return;
    }
    await _supabase.from('employees').delete().eq('id', employeeId);
  }

  Future<String> _resolveStoreId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const EmployeeFlowException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      );
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

    throw const EmployeeFlowException(
      'Chưa tìm thấy cửa hàng cho tài khoản hiện tại.',
    );
  }
}

class EmployeeFlowException implements Exception {
  const EmployeeFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
