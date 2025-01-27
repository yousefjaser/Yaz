import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:meta/meta.dart';

part 'payment.g.dart';

@HiveType(typeId: 1)
class Payment extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  int customerId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  String? notes;

  @HiveField(5)
  DateTime? reminderDate;

  @HiveField(6)
  bool isDeleted;

  @HiveField(7)
  String? title;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  DateTime? createdAt;

  @HiveField(10)
  DateTime? updatedAt;

  @HiveField(11)
  String? userId;

  @HiveField(12)
  @protected
  String? customerJson;

  @HiveField(13)
  bool reminderSent;

  Map<String, dynamic>? get customer =>
      customerJson != null ? json.decode(customerJson!) : null;

  set customer(Map<String, dynamic>? value) {
    customerJson = value != null ? json.encode(value) : null;
  }

  String get customerName => customer?['name'] ?? 'عميل غير معروف';

  Payment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.notes,
    this.reminderDate,
    this.isDeleted = false,
    this.title,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
    this.userId,
    Map<String, dynamic>? customer,
    this.reminderSent = false,
  }) {
    if (customer != null) {
      this.customer = customer;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId.toString(),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'title': title,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_id': userId,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    int parseCustomerId(dynamic value) {
      if (value == null) throw Exception('معرف العميل مطلوب');
      if (value is int) return value;
      if (value is String) return int.parse(value);
      throw Exception('نوع معرف العميل غير صالح');
    }

    return Payment(
      id: map['id'] != null ? int.parse(map['id'].toString()) : null,
      customerId: parseCustomerId(map['customer_id']),
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      notes: map['notes'],
      reminderDate: map['reminder_date'] != null
          ? DateTime.parse(map['reminder_date'])
          : null,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      title: map['title'],
      isSynced: true,
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      userId: map['user_id'],
      customer: map['customers'],
    );
  }

  Payment copyWith({
    int? id,
    int? customerId,
    double? amount,
    DateTime? date,
    String? notes,
    DateTime? reminderDate,
    bool? isDeleted,
    String? title,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    Map<String, dynamic>? customer,
  }) {
    return Payment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      reminderDate: reminderDate ?? this.reminderDate,
      isDeleted: isDeleted ?? this.isDeleted,
      title: title ?? this.title,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      customer: customer ?? this.customer,
    );
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    int parseCustomerId(dynamic value) {
      if (value == null) throw Exception('معرف العميل مطلوب');
      if (value is int) return value;
      if (value is String) return int.parse(value);
      throw Exception('نوع معرف العميل غير صالح');
    }

    return Payment(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      customerId: parseCustomerId(json['customer_id']),
      amount: double.parse(json['amount'].toString()),
      date: DateTime.parse(json['date']),
      notes: json['notes'],
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      title: json['title'],
      isSynced: true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      userId: json['user_id'],
      customer: json['customers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId.toString(),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'is_deleted': isDeleted,
      'title': title,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_id': userId,
    };
  }
}
