import 'package:hive/hive.dart';
import 'package:yaz/models/payment.dart';

part 'customer.g.dart';

@HiveType(typeId: 0)
class Customer extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String phone;

  @HiveField(3)
  String? address;

  @HiveField(4)
  String? notes;

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

  @HiveField(13)
  bool isSynced;

  @HiveField(14)
  bool isDeleted;

  @HiveField(15)
  String? localId;

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
    this.localId,
  })  : payments = payments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'color': color,
      'balance': balance,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'is_synced': isSynced,
      'user_id': userId,
      'local_id': localId,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'],
      notes: json['notes'],
      color: json['color'] ?? '#000000',
      balance: json['balance'] != null
          ? double.parse(json['balance'].toString())
          : 0.0,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      isSynced: json['is_synced'] ?? false,
      userId: json['user_id'],
      localId: json['local_id'],
    );
  }

  factory Customer.fromMap(Map<String, dynamic> map) => Customer.fromJson(map);

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
    String? localId,
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
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      localId: localId ?? this.localId,
    );
  }
}
