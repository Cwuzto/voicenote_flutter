import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/store_scope_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../presentation/order_models.dart';

class OrderRepository {
  OrderRepository({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<List<OrderVm>> fetchOrders() async {
    final storeId = await _resolveStoreId();

    final ordersData = await _client
        .from('orders')
        .select('id, seller_id, customer_name, status, created_at')
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(ordersData);
    if (orders.isEmpty) {
      return [];
    }

    final orderIds = orders.map((e) => e['id'].toString()).toList();
    final sellerIds = orders
        .map((e) => e['seller_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final itemsData = await _client
        .from('order_items')
        .select('order_id, product_name, quantity, unit_price, note')
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: true);
    final itemsByOrderId = <String, List<OrderLineVm>>{};
    for (final raw in List<Map<String, dynamic>>.from(itemsData)) {
      final orderId = raw['order_id'].toString();
      itemsByOrderId
          .putIfAbsent(orderId, () => [])
          .add(
            OrderLineVm(
              name: (raw['product_name'] ?? '').toString(),
              quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
              unitPrice: (raw['unit_price'] as num?)?.toInt() ?? 0,
              note: (raw['note'] as String?)?.trim().isEmpty ?? true
                  ? null
                  : raw['note'] as String,
            ),
          );
    }

    final sellerNames = <String, String>{};
    if (sellerIds.isNotEmpty) {
      final usersData = await _client
          .from('users')
          .select('id, full_name')
          .inFilter('id', sellerIds);
      for (final raw in List<Map<String, dynamic>>.from(usersData)) {
        final id = raw['id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }
        sellerNames[id] = (raw['full_name'] ?? '').toString();
      }
    }

    return orders.map((raw) {
      final id = raw['id'].toString();
      final sellerId = (raw['seller_id'] ?? '').toString();
      final createdAt = DateTime.tryParse((raw['created_at'] ?? '').toString());
      final status = (raw['status'] ?? '').toString().toUpperCase() == 'PAID'
          ? OrderStatusVm.paid
          : OrderStatusVm.unpaid;

      return OrderVm(
        id: id,
        customerName: ((raw['customer_name'] ?? '').toString().trim()).isEmpty
            ? 'Khach le'
            : raw['customer_name'].toString(),
        sellerName: (sellerNames[sellerId]?.trim().isNotEmpty ?? false)
            ? sellerNames[sellerId]!
            : 'Nhan vien ban hang',
        createdAt: createdAt ?? DateTime.now(),
        status: status,
        lines: itemsByOrderId[id] ?? const [],
      );
    }).toList();
  }

  Future<OrderVm> createOrder({
    required String customerName,
    required String sellerName,
    required List<OrderLineVm> lines,
  }) async {
    if (lines.isEmpty) {
      throw const OrderFlowException('Don hang trong, khong the luu.');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrderFlowException(
        'Phien dang nhap het han. Vui long dang nhap lai.',
      );
    }
    final storeId = await _resolveStoreId();
    final totalAmount = lines.fold<int>(0, (sum, line) => sum + line.lineTotal);

    final insertedOrder = await _client
        .from('orders')
        .insert({
          'store_id': storeId,
          'seller_id': userId,
          'customer_name': customerName,
          'status': 'UNPAID',
          'payment_method': 'CASH',
          'total_amount': totalAmount,
        })
        .select('id, created_at')
        .single();

    final orderId = insertedOrder['id'].toString();

    try {
      await _client
          .from('order_items')
          .insert(
            lines
                .map(
                  (line) => {
                    'order_id': orderId,
                    'product_name': line.name,
                    'quantity': line.quantity,
                    'unit_price': line.unitPrice,
                    'note': (line.note?.trim().isEmpty ?? true)
                        ? null
                        : line.note!.trim(),
                  },
                )
                .toList(),
          );
    } catch (e) {
      // Avoid orphaned orders when item insert fails.
      await _client.from('orders').delete().eq('id', orderId);
      rethrow;
    }

    final createdAt = DateTime.tryParse(
      (insertedOrder['created_at'] ?? '').toString(),
    );
    return OrderVm(
      id: orderId,
      customerName: customerName,
      sellerName: sellerName,
      createdAt: createdAt ?? DateTime.now(),
      status: OrderStatusVm.unpaid,
      lines: lines,
    );
  }

  Future<void> markPaid(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'PAID'})
        .eq('id', orderId)
        .eq('status', 'UNPAID');
  }

  Future<void> updateOrder({
    required String orderId,
    required String customerName,
    required List<OrderLineVm> lines,
  }) async {
    final totalAmount = lines.fold<int>(0, (sum, line) => sum + line.lineTotal);

    await _client
        .from('orders')
        .update({
          'customer_name': customerName,
          'total_amount': totalAmount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);

    await _client.from('order_items').delete().eq('order_id', orderId);
    if (lines.isEmpty) {
      return;
    }

    await _client
        .from('order_items')
        .insert(
          lines
              .map(
                (line) => {
                  'order_id': orderId,
                  'product_name': line.name,
                  'quantity': line.quantity,
                  'unit_price': line.unitPrice,
                  'note': (line.note?.trim().isEmpty ?? true)
                      ? null
                      : line.note!.trim(),
                },
              )
              .toList(),
        );
  }

  Future<String> _resolveStoreId() async {
    try {
      return await StoreScopeResolver.resolveStoreId(_client);
    } on StoreScopeException catch (e) {
      throw OrderFlowException(e.message);
    }
  }
}

class OrderFlowException implements Exception {
  const OrderFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
