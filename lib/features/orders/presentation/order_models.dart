class OrderLineVm {
  const OrderLineVm({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.note,
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final String? note;

  int get lineTotal => quantity * unitPrice;

  OrderLineVm copyWith({
    String? name,
    int? quantity,
    int? unitPrice,
    String? note,
  }) {
    return OrderLineVm(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      note: note ?? this.note,
    );
  }
}

enum OrderStatusVm { paid, unpaid }

class OrderVm {
  OrderVm({
    required this.id,
    required this.customerName,
    required this.sellerName,
    this.paidByUserId,
    this.paidByName,
    required this.createdAt,
    required this.status,
    required this.lines,
  });

  final String id;
  String customerName;
  String sellerName;
  String? paidByUserId;
  String? paidByName;
  DateTime createdAt;
  OrderStatusVm status;
  List<OrderLineVm> lines;

  int get totalAmount =>
      lines.fold<int>(0, (sum, line) => sum + line.quantity * line.unitPrice);
}
