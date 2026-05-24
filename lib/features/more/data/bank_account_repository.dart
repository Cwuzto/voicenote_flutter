import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class BankAccountVm {
  const BankAccountVm({
    required this.id,
    required this.bankName,
    required this.number,
    required this.holder,
    required this.isDefault,
  });

  final String id;
  final String bankName;
  final String number;
  final String holder;
  final bool isDefault;

  BankAccountVm copyWith({
    String? bankName,
    String? number,
    String? holder,
    bool? isDefault,
  }) {
    return BankAccountVm(
      id: id,
      bankName: bankName ?? this.bankName,
      number: number ?? this.number,
      holder: holder ?? this.holder,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class BankAccountRepository {
  BankAccountRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  static final List<BankAccountVm> _localAccounts = [
    const BankAccountVm(
      id: 'local-1',
      bankName: 'Vietcombank',
      number: '0123456789',
      holder: 'NGUYEN VAN A',
      isDefault: true,
    ),
    const BankAccountVm(
      id: 'local-2',
      bankName: 'MB Bank',
      number: '9876543210',
      holder: 'NGUYEN VAN A',
      isDefault: false,
    ),
  ];

  Future<List<BankAccountVm>> fetchAccounts() async {
    if (!SupabaseBootstrap.isInitialized) {
      return List<BankAccountVm>.from(_localAccounts);
    }

    final storeId = await _resolveStoreId();
    final data = await _supabase
        .from('bank_accounts')
        .select('id, bank_name, account_number, account_holder, is_default')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data).map((row) {
      return BankAccountVm(
        id: row['id'].toString(),
        bankName: (row['bank_name'] ?? '').toString(),
        number: (row['account_number'] ?? '').toString(),
        holder: (row['account_holder'] ?? '').toString(),
        isDefault: row['is_default'] == true,
      );
    }).toList();
  }

  Future<BankAccountVm> createAccount({
    required String bankName,
    required String number,
    required String holder,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final hasDefault = _localAccounts.any((e) => e.isDefault);
      final item = BankAccountVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bankName: bankName,
        number: number,
        holder: holder,
        isDefault: !hasDefault,
      );
      _localAccounts.insert(0, item);
      return item;
    }

    final storeId = await _resolveStoreId();
    final hasDefault = await _hasAnyDefaultAccount(storeId);
    final inserted = await _supabase
        .from('bank_accounts')
        .insert({
          'store_id': storeId,
          'bank_name': bankName,
          'account_number': number,
          'account_holder': holder,
          'is_default': !hasDefault,
          'is_active': true,
        })
        .select('id, bank_name, account_number, account_holder, is_default')
        .single();

    return BankAccountVm(
      id: inserted['id'].toString(),
      bankName: (inserted['bank_name'] ?? '').toString(),
      number: (inserted['account_number'] ?? '').toString(),
      holder: (inserted['account_holder'] ?? '').toString(),
      isDefault: inserted['is_default'] == true,
    );
  }

  Future<BankAccountVm> updateAccount({
    required String id,
    required String bankName,
    required String number,
    required String holder,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final index = _localAccounts.indexWhere((e) => e.id == id);
      if (index < 0) {
        throw const BankAccountFlowException('Không tìm thấy tài khoản.');
      }
      final updated = _localAccounts[index].copyWith(
        bankName: bankName,
        number: number,
        holder: holder,
      );
      _localAccounts[index] = updated;
      return updated;
    }

    final updated = await _supabase
        .from('bank_accounts')
        .update({
          'bank_name': bankName,
          'account_number': number,
          'account_holder': holder,
        })
        .eq('id', id)
        .select('id, bank_name, account_number, account_holder, is_default')
        .single();

    return BankAccountVm(
      id: updated['id'].toString(),
      bankName: (updated['bank_name'] ?? '').toString(),
      number: (updated['account_number'] ?? '').toString(),
      holder: (updated['account_holder'] ?? '').toString(),
      isDefault: updated['is_default'] == true,
    );
  }

  Future<void> setDefaultAccount(String id) async {
    if (!SupabaseBootstrap.isInitialized) {
      final index = _localAccounts.indexWhere((e) => e.id == id);
      if (index < 0) {
        throw const BankAccountFlowException('Không tìm thấy tài khoản.');
      }
      for (var i = 0; i < _localAccounts.length; i++) {
        _localAccounts[i] = _localAccounts[i].copyWith(isDefault: i == index);
      }
      return;
    }

    final storeId = await _resolveStoreId();
    await _supabase
        .from('bank_accounts')
        .update({'is_default': false})
        .eq('store_id', storeId)
        .eq('is_active', true);
    await _supabase
        .from('bank_accounts')
        .update({'is_default': true})
        .eq('id', id);
  }

  Future<void> deleteAccount(String id) async {
    if (!SupabaseBootstrap.isInitialized) {
      _localAccounts.removeWhere((e) => e.id == id);
      if (_localAccounts.isNotEmpty &&
          !_localAccounts.any((e) => e.isDefault)) {
        _localAccounts[0] = _localAccounts[0].copyWith(isDefault: true);
      }
      return;
    }

    final target = await _supabase
        .from('bank_accounts')
        .select('store_id, is_default')
        .eq('id', id)
        .maybeSingle();
    await _supabase
        .from('bank_accounts')
        .update({'is_active': false})
        .eq('id', id);

    if (target == null || target['is_default'] != true) {
      return;
    }
    final storeId = target['store_id']?.toString();
    if (storeId == null || storeId.isEmpty) {
      return;
    }
    final replacement = await _supabase
        .from('bank_accounts')
        .select('id')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (replacement == null) {
      return;
    }
    await _supabase
        .from('bank_accounts')
        .update({'is_default': true})
        .eq('id', replacement['id']);
  }

  Future<bool> _hasAnyDefaultAccount(String storeId) async {
    final row = await _supabase
        .from('bank_accounts')
        .select('id')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .eq('is_default', true)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  Future<String> _resolveStoreId() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const BankAccountFlowException(
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

    throw const BankAccountFlowException(
      'Chưa tìm thấy cửa hàng cho tài khoản hiện tại.',
    );
  }
}

class BankAccountFlowException implements Exception {
  const BankAccountFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
