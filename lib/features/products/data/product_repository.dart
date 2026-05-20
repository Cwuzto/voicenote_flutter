import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

class ProductVm {
  const ProductVm({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final int price;

  ProductVm copyWith({String? name, int? price}) {
    return ProductVm(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}

class ProductRepository {
  ProductRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  Future<List<ProductVm>> fetchProducts() async {
    if (!SupabaseBootstrap.isInitialized) {
      return _localSeed();
    }

    final storeId = await _resolveStoreId();
    final data = await _supabase
        .from('products')
        .select('id, name, price')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(data).map((row) {
      return ProductVm(
        id: row['id'].toString(),
        name: (row['name'] ?? '').toString(),
        price: (row['price'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<ProductVm> createProduct({
    required String name,
    required int price,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      return ProductVm(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        price: price,
      );
    }

    final storeId = await _resolveStoreId();
    final inserted = await _supabase
        .from('products')
        .insert({
          'store_id': storeId,
          'name': name,
          'price': price,
          'is_active': true,
        })
        .select('id, name, price')
        .single();

    return ProductVm(
      id: inserted['id'].toString(),
      name: (inserted['name'] ?? '').toString(),
      price: (inserted['price'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ProductVm> updateProduct({
    required String id,
    required String name,
    required int price,
  }) async {
    if (!SupabaseBootstrap.isInitialized) {
      return ProductVm(id: id, name: name, price: price);
    }

    final updated = await _supabase
        .from('products')
        .update({
          'name': name,
          'price': price,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('id, name, price')
        .single();

    return ProductVm(
      id: updated['id'].toString(),
      name: (updated['name'] ?? '').toString(),
      price: (updated['price'] as num?)?.toInt() ?? 0,
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
      ProductVm(id: 'p1', name: 'Banh mi', price: 18000),
      ProductVm(id: 'p2', name: 'Ca phe sua', price: 25000),
      ProductVm(id: 'p3', name: 'Pho bo', price: 45000),
      ProductVm(id: 'p4', name: 'Tra dao', price: 30000),
      ProductVm(id: 'p5', name: 'Bun cha', price: 50000),
    ];
  }
}

class ProductFlowException implements Exception {
  const ProductFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
