import 'package:hive/hive.dart';
import 'package:yaz/models/payment.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String phone;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  String color;

  @HiveField(6)
  double balance;

  @HiveField(7)
  List<Payment> payments;

  @HiveField(8)
  DateTime? lastPaymentDate;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  DateTime? deletedAt;

  @HiveField(12)
  String? userId;

  bool isSynced;
  bool isDeleted;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    required this.color,
    this.balance = 0,
    List<Payment>? payments,
    this.lastPaymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.userId,
    this.isSynced = false,
    this.isDeleted = false,
  })  : payments = payments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'color': color,
      'balance': balance,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'user_id': userId,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      notes: map['notes'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      color: map['color'] ?? '#FF0000',
      address: map['address'] ?? '',
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isSynced: map['is_synced'] ?? true,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    String? color,
    double? balance,
    List<Payment>? payments,
    DateTime? lastPaymentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? userId,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      color: color ?? this.color,
      balance: balance ?? this.balance,
      payments: payments ?? this.payments,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
    )
      ..isSynced = isSynced ?? this.isSynced
      ..isDeleted = isDeleted ?? this.isDeleted;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'color': color,
      'balance': balance,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
