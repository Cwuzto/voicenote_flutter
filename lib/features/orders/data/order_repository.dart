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
        .select('''
          id,
          seller_id,
          paid_by_user_id,
          customer_name,
          status,
          created_at,
          order_items(
            product_name,
            quantity,
            unit_price,
            note,
            created_at
          )
          ''')
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(ordersData);
    if (orders.isEmpty) {
      return [];
    }

    final sellerIds = orders
        .map((e) => e['seller_id'])
        .whereType<String>()
        .toSet();
    final paidByUserIds = orders
        .map((e) => e['paid_by_user_id'])
        .whereType<String>()
        .toSet();
    final userIds = {...sellerIds, ...paidByUserIds}.toList();

    final userNames = <String, String>{};
    if (userIds.isNotEmpty) {
      final usersData = await _client
          .from('users')
          .select('id, full_name')
          .inFilter('id', userIds);
      for (final raw in List<Map<String, dynamic>>.from(usersData)) {
        final id = raw['id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }
        userNames[id] = (raw['full_name'] ?? '').toString();
      }
    }

    return orders.map((raw) {
      final sellerId = (raw['seller_id'] ?? '').toString();
      final paidByUserId = (raw['paid_by_user_id'] ?? '').toString();
      final createdAt = DateTime.tryParse((raw['created_at'] ?? '').toString());
      final status = (raw['status'] ?? '').toString().toUpperCase() == 'PAID'
          ? OrderStatusVm.paid
          : OrderStatusVm.unpaid;

      final rawItems = List<Map<String, dynamic>>.from(
        raw['order_items'] as List? ?? const [],
      );
      rawItems.sort((a, b) {
        final left = DateTime.tryParse((a['created_at'] ?? '').toString());
        final right = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (left == null && right == null) {
          return 0;
        }
        if (left == null) {
          return -1;
        }
        if (right == null) {
          return 1;
        }
        return left.compareTo(right);
      });

      return OrderVm(
        id: raw['id'].toString(),
        customerName: ((raw['customer_name'] ?? '').toString().trim()).isEmpty
            ? 'Khach le'
            : raw['customer_name'].toString(),
        sellerName: (userNames[sellerId]?.trim().isNotEmpty ?? false)
            ? userNames[sellerId]!
            : 'Nhan vien ban hang',
        paidByUserId: paidByUserId.isEmpty ? null : paidByUserId,
        paidByName: (userNames[paidByUserId]?.trim().isNotEmpty ?? false)
            ? userNames[paidByUserId]!
            : null,
        createdAt: createdAt ?? DateTime.now(),
        status: status,
        lines: rawItems.map((item) {
          return OrderLineVm(
            name: (item['product_name'] ?? '').toString(),
            quantity: (item['quantity'] as num?)?.toInt() ?? 0,
            unitPrice: (item['unit_price'] as num?)?.toInt() ?? 0,
            note: (item['note'] as String?)?.trim().isEmpty ?? true
                ? null
                : item['note'] as String,
          );
        }).toList(),
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

  Future<String?> getCurrentUserName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final row = await _client
        .from('users')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();
    final name = (row?['full_name'] ?? '').toString().trim();
    return name.isEmpty ? null : name;
  }

  Future<void> markPaid(String orderId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const OrderFlowException(
        'Phien dang nhap het han. Vui long dang nhap lai.',
      );
    }

    await _client
        .from('orders')
        .update({'status': 'PAID', 'paid_by_user_id': userId})
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
