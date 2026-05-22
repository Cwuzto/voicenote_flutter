import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class BankAccountVm {
  const BankAccountVm({
    required this.id,
    required this.bankName,
    required this.number,
    required this.holder,
  });

  final String id;
  final String bankName;
  final String number;
  final String holder;

  BankAccountVm copyWith({String? bankName, String? number, String? holder}) {
    return BankAccountVm(
      id: id,
      bankName: bankName ?? this.bankName,
      number: number ?? this.number,
      holder: holder ?? this.holder,
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
    ),
    const BankAccountVm(
      id: 'local-2',
      bankName: 'MB Bank',
      number: '9876543210',
      holder: 'NGUYEN VAN A',
    ),
  ];

  Future<List<BankAccountVm>> fetchAccounts() async {
    if (!SupabaseBootstrap.isInitialized) {
      return List<BankAccountVm>.from(_localAccounts);
    }

    final storeId = await _resolveStoreId();
    final data = await _supabase
        .from('bank_accounts')
        .select('id, bank_name, account_number, account_holder')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data).map((row) {
      return BankAccountVm(
        id: row['id'].toString(),
        bankName: (row['bank_name'] ?? '').toString(),
        number: (row['account_number'] ?? '').toString(),
        holder: (row['account_holder'] ?? '').toString(),
      );
    }).toList();
  }

  Future<BankAccountVm> createAccount({
    required String bankName,
    required String number,
    required String holder,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      final item = BankAccountVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        bankName: bankName,
        number: number,
        holder: holder,
      );
      _localAccounts.insert(0, item);
      return item;
    }

    final storeId = await _resolveStoreId();
    final inserted = await _supabase
        .from('bank_accounts')
        .insert({
          'store_id': storeId,
          'bank_name': bankName,
          'account_number': number,
          'account_holder': holder,
          'is_active': true,
        })
        .select('id, bank_name, account_number, account_holder')
        .single();

    return BankAccountVm(
      id: inserted['id'].toString(),
      bankName: (inserted['bank_name'] ?? '').toString(),
      number: (inserted['account_number'] ?? '').toString(),
      holder: (inserted['account_holder'] ?? '').toString(),
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
        .select('id, bank_name, account_number, account_holder')
        .single();

    return BankAccountVm(
      id: updated['id'].toString(),
      bankName: (updated['bank_name'] ?? '').toString(),
      number: (updated['account_number'] ?? '').toString(),
      holder: (updated['account_holder'] ?? '').toString(),
    );
  }

  Future<void> deleteAccount(String id) async {
    if (!SupabaseBootstrap.isInitialized) {
      _localAccounts.removeWhere((e) => e.id == id);
      return;
    }

    await _supabase
        .from('bank_accounts')
        .update({'is_active': false})
        .eq('id', id);
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
