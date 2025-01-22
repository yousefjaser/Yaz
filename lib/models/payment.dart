import 'package:hive/hive.dart';

part 'payment.g.dart';

@HiveType(typeId: 1)
class Payment extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  final int customerId;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  DateTime? reminderDate;

  @HiveField(6)
  bool reminderSent;

  @HiveField(7)
  bool isSynced;

  @HiveField(8)
  bool isDeleted;

  @HiveField(9)
  DateTime? deletedAt;

  @HiveField(10)
  Map<String, dynamic>? customer;

  @HiveField(11)
  final String? title;

  String get customerName => customer?['name'] ?? 'عميل غير معروف';

  Payment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.notes,
    this.reminderDate,
    this.reminderSent = false,
    this.isSynced = false,
    this.isDeleted = false,
    this.deletedAt,
    this.customer,
    this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId.toString(),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_sent': reminderSent ? 1 : 0,
      'title': title,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
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
      reminderSent: map['reminder_sent'] == 1 || map['reminder_sent'] == true,
      title: map['title'],
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      customer: map['customers'],
      isSynced: true,
    );
  }

  Payment copyWith({
    int? id,
    int? customerId,
    double? amount,
    DateTime? date,
    String? notes,
    DateTime? reminderDate,
    bool? reminderSent,
    bool? isDeleted,
    bool? isSynced,
    DateTime? deletedAt,
    Map<String, dynamic>? customer,
    String? title,
  }) {
    return Payment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderSent: reminderSent ?? this.reminderSent,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      deletedAt: deletedAt ?? this.deletedAt,
      customer: customer ?? this.customer,
      title: title ?? this.title,
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
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      notes: json['notes'],
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : null,
      reminderSent: json['reminder_sent'] == true,
      title: json['title'],
      customer: json['customers'],
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id?.toString(),
      'customer_id': customerId.toString(),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_sent': reminderSent,
      'title': title,
    };
  }
}
