import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

class CategoryVm {
  const CategoryVm({required this.id, required this.name});

  final String id;
  final String name;
}

class CategoryRepository {
  CategoryRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  Future<List<CategoryVm>> fetchCategories() async {
    if (!SupabaseBootstrap.isInitialized) {
      return _localDefaults();
    }
    final storeId = await _resolveStoreId();
    final rows = await _supabase
        .from('product_categories')
        .select('id, name')
        .eq('store_id', storeId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(rows)
        .map(
          (e) => CategoryVm(
            id: e['id'].toString(),
            name: (e['name'] ?? '').toString(),
          ),
        )
        .where((e) => e.name.trim().isNotEmpty)
        .toList();
  }

  Future<CategoryVm> createCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const CategoryFlowException('Tên danh mục không được để trống.');
    }
    if (!SupabaseBootstrap.isInitialized) {
      return CategoryVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: normalized,
      );
    }
    final storeId = await _resolveStoreId();
    final inserted = await _supabase
        .from('product_categories')
        .insert({'store_id': storeId, 'name': normalized})
        .select('id, name')
        .single();
    return CategoryVm(
      id: inserted['id'].toString(),
      name: (inserted['name'] ?? '').toString(),
    );
  }

  Future<void> renameCategory({
    required CategoryVm category,
    required String newName,
  }) async {
    final normalized = newName.trim();
    if (normalized.isEmpty) {
      throw const CategoryFlowException('Tên danh mục không được để trống.');
    }
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }
    final storeId = await _resolveStoreId();
    await _supabase
        .from('product_categories')
        .update({'name': normalized})
        .eq('id', category.id);

    await _supabase
        .from('products')
        .update({'category_name': normalized})
        .eq('store_id', storeId)
        .eq('category_name', category.name);
  }

  Future<void> deleteCategory(CategoryVm category) async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }
    final storeId = await _resolveStoreId();

    await _supabase
        .from('products')
        .update({'category_name': 'Khác'})
        .eq('store_id', storeId)
        .eq('category_name', category.name);

    await _supabase.from('product_categories').delete().eq('id', category.id);
  }

  Future<String> _resolveStoreId() async {
    try {
      return await StoreScopeResolver.resolveStoreId(_supabase);
    } on StoreScopeException catch (e) {
      throw CategoryFlowException(e.message);
    }
  }

  List<CategoryVm> _localDefaults() {
    return const [
      CategoryVm(id: 'c1', name: 'Món chính'),
      CategoryVm(id: 'c2', name: 'Món phụ'),
      CategoryVm(id: 'c3', name: 'Đồ uống'),
      CategoryVm(id: 'c4', name: 'Khác'),
    ];
  }
}

class CategoryFlowException implements Exception {
  const CategoryFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
