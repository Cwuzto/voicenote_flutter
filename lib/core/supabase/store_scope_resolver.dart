import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves current user's store scope and caches it during session
/// to reduce repeated owner/employee lookup queries.
class StoreScopeResolver {
  StoreScopeResolver._();

  static String? _cachedUserId;
  static String? _cachedStoreId;

  static Future<String> resolveStoreId(SupabaseClient client) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const StoreScopeException(
        'Phien dang nhap het han. Vui long dang nhap lai.',
      );
    }

    if (_cachedUserId == userId &&
        _cachedStoreId != null &&
        _cachedStoreId!.isNotEmpty) {
      return _cachedStoreId!;
    }

    final ownerStore = await client
        .from('stores')
        .select('id')
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (ownerStore != null) {
      final storeId = ownerStore['id'].toString();
      _cachedUserId = userId;
      _cachedStoreId = storeId;
      return storeId;
    }

    final employeeRow = await client
        .from('employees')
        .select('store_id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    if (employeeRow != null) {
      final storeId = employeeRow['store_id'].toString();
      _cachedUserId = userId;
      _cachedStoreId = storeId;
      return storeId;
    }

    throw const StoreScopeException(
      'Chua tim thay cua hang cho tai khoan hien tai.',
    );
  }

  static void clearCache() {
    _cachedUserId = null;
    _cachedStoreId = null;
  }
}

class StoreScopeException implements Exception {
  const StoreScopeException(this.message);

  final String message;

  @override
  String toString() => message;
}

