import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

class ProductVm {
  const ProductVm({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryName,
  });

  final String id;
  final String name;
  final int price;
  final String categoryName;

  ProductVm copyWith({String? name, int? price, String? categoryName}) {
    return ProductVm(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}

class ProductRepository {
  ProductRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  bool _supportsCategoryColumn = true;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  Future<List<ProductVm>> fetchProducts() async {
    if (!SupabaseBootstrap.isInitialized) {
      return _localSeed();
    }

    final storeId = await _resolveStoreId();
    late final dynamic data;
    try {
      data = await _supabase
          .from('products')
          .select('id, name, price, category_name')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('name', ascending: true);
      _supportsCategoryColumn = true;
    } catch (_) {
      data = await _supabase
          .from('products')
          .select('id, name, price')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('name', ascending: true);
      _supportsCategoryColumn = false;
    }

    return List<Map<String, dynamic>>.from(data).map((row) {
      return ProductVm(
        id: row['id'].toString(),
        name: (row['name'] ?? '').toString(),
        price: (row['price'] as num?)?.toInt() ?? 0,
        categoryName: (row['category_name'] ?? 'Khác').toString(),
      );
    }).toList();
  }

  Future<ProductVm> createProduct({
    required String name,
    required int price,
    required String categoryName,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      return ProductVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        price: price,
        categoryName: categoryName,
      );
    }

    final storeId = await _resolveStoreId();
    late final Map<String, dynamic> inserted;
    if (_supportsCategoryColumn) {
      try {
        inserted = Map<String, dynamic>.from(
          await _supabase
              .from('products')
              .insert({
                'store_id': storeId,
                'name': name,
                'price': price,
                'category_name': categoryName,
                'is_active': true,
              })
              .select('id, name, price, category_name')
              .single(),
        );
      } catch (_) {
        _supportsCategoryColumn = false;
        inserted = Map<String, dynamic>.from(
          await _supabase
              .from('products')
              .insert({
                'store_id': storeId,
                'name': name,
                'price': price,
                'is_active': true,
              })
              .select('id, name, price')
              .single(),
        );
      }
    } else {
      inserted = Map<String, dynamic>.from(
        await _supabase
            .from('products')
            .insert({
              'store_id': storeId,
              'name': name,
              'price': price,
              'is_active': true,
            })
            .select('id, name, price')
            .single(),
      );
    }

    return ProductVm(
      id: inserted['id'].toString(),
      name: (inserted['name'] ?? '').toString(),
      price: (inserted['price'] as num?)?.toInt() ?? 0,
      categoryName: (inserted['category_name'] ?? categoryName).toString(),
    );
  }

  Future<ProductVm> updateProduct({
    required String id,
    required String name,
    required int price,
    required String categoryName,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      return ProductVm(
        id: id,
        name: name,
        price: price,
        categoryName: categoryName,
      );
    }

    late final Map<String, dynamic> updated;
    if (_supportsCategoryColumn) {
      try {
        updated = Map<String, dynamic>.from(
          await _supabase
              .from('products')
              .update({
                'name': name,
                'price': price,
                'category_name': categoryName,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .select('id, name, price, category_name')
              .single(),
        );
      } catch (_) {
        _supportsCategoryColumn = false;
        updated = Map<String, dynamic>.from(
          await _supabase
              .from('products')
              .update({
                'name': name,
                'price': price,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .select('id, name, price')
              .single(),
        );
      }
    } else {
      updated = Map<String, dynamic>.from(
        await _supabase
            .from('products')
            .update({
              'name': name,
              'price': price,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .select('id, name, price')
            .single(),
      );
    }

    return ProductVm(
      id: updated['id'].toString(),
      name: (updated['name'] ?? '').toString(),
      price: (updated['price'] as num?)?.toInt() ?? 0,
      categoryName: (updated['category_name'] ?? categoryName).toString(),
    );
  }

  Future<void> deleteProduct(String id) async {
    if (!SupabaseBootstrap.isInitialized) {
      return;
    }

    await _supabase.from('products').update({'is_active': false}).eq('id', id);
  }

  Future<String> _resolveStoreId() async {
    try {
      return await StoreScopeResolver.resolveStoreId(_supabase);
    } on StoreScopeException catch (e) {
      throw ProductFlowException(e.message);
    }
  }

  List<ProductVm> _localSeed() {
    return const [
      ProductVm(
        id: 'p1',
        name: 'Cơm gà xối mỡ',
        price: 45000,
        categoryName: 'Món chính',
      ),
      ProductVm(
        id: 'p2',
        name: 'Bún bò Huế',
        price: 50000,
        categoryName: 'Món chính',
      ),
      ProductVm(
        id: 'p3',
        name: 'Phở bò tái',
        price: 55000,
        categoryName: 'Món chính',
      ),
      ProductVm(
        id: 'p4',
        name: 'Mì xào bò',
        price: 48000,
        categoryName: 'Món chính',
      ),
      ProductVm(
        id: 'p5',
        name: 'Gỏi cuốn tôm thịt',
        price: 35000,
        categoryName: 'Món phụ',
      ),
      ProductVm(id: 'p6', name: 'Trà đá', price: 5000, categoryName: 'Đồ uống'),
      ProductVm(
        id: 'p7',
        name: 'Trà tắc',
        price: 12000,
        categoryName: 'Đồ uống',
      ),
      ProductVm(
        id: 'p8',
        name: 'Coca Cola',
        price: 15000,
        categoryName: 'Đồ uống',
      ),
      ProductVm(id: 'p9', name: 'Pepsi', price: 15000, categoryName: 'Đồ uống'),
      ProductVm(
        id: 'p10',
        name: 'Cam ép',
        price: 25000,
        categoryName: 'Đồ uống',
      ),
    ];
  }
}

class ProductFlowException implements Exception {
  const ProductFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
