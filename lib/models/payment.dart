import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:meta/meta.dart';

part 'payment.g.dart';

@HiveType(typeId: 2)
class Payment {
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
  final DateTime? reminderDate;

  @HiveField(6)
  bool? reminderSent;

  @HiveField(7)
  DateTime? createdAt;

  @HiveField(8)
  DateTime? updatedAt;

  @HiveField(9)
  bool isDeleted;

  @HiveField(10)
  DateTime? deletedAt;

  @HiveField(11)
  String? title;

  @HiveField(12)
  DateTime? reminderSentAt;

  @HiveField(13)
  bool isSynced;

  @HiveField(14)
  String? userId;

  Payment({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.notes,
    this.reminderDate,
    this.reminderSent = false,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.title,
    this.reminderSentAt,
    this.isSynced = false,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_sent': reminderSent,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'title': title,
      'reminder_sent_at': reminderSentAt?.toIso8601String(),
      'is_synced': isSynced,
      'user_id': userId,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      customerId: map['customer_id'],
      amount: map['amount']?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date']),
      notes: map['notes'],
      reminderDate: map['reminder_date'] != null
          ? DateTime.parse(map['reminder_date'])
          : null,
      reminderSent: map['reminder_sent'] ?? false,
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      title: map['title'],
      reminderSentAt: map['reminder_sent_at'] != null
          ? DateTime.parse(map['reminder_sent_at'])
          : null,
      isSynced: map['is_synced'] ?? false,
      userId: map['user_id'],
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Payment.fromJson(Map<String, dynamic> json) => Payment.fromMap(json);

  Payment copyWith({
    int? id,
    int? customerId,
    double? amount,
    DateTime? date,
    String? notes,
    DateTime? reminderDate,
    bool? reminderSent,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? title,
    DateTime? reminderSentAt,
    bool? isSynced,
    String? userId,
  }) {
    return Payment(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderSent: reminderSent ?? this.reminderSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      title: title ?? this.title,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }

  String? get customerName => null; // سيتم تعبئته من قاعدة البيانات
}
