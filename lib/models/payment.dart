import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:meta/meta.dart';

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
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.title,
    this.reminderSentAt,
    this.isSynced = false,
    this.userId,
  })  : this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'reminder_date': reminderDate?.toIso8601String(),
      'reminder_sent': reminderSent,
      'created_at':
          createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'title': title,
      'reminder_sent_at': reminderSentAt?.toIso8601String(),
      'is_synced': isSynced,
      'user_id': userId,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      customerId: json['customer_id'] != null
          ? int.parse(json['customer_id'].toString())
          : 0,
      amount: json['amount'] != null
          ? double.parse(json['amount'].toString())
          : 0.0,
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      notes: json['notes'],
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : null,
      reminderSent: json['reminder_sent'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isDeleted: json['is_deleted'] ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      title: json['title'],
      reminderSentAt: json['reminder_sent_at'] != null
          ? DateTime.parse(json['reminder_sent_at'])
          : null,
      isSynced: json['is_synced'] ?? false,
      userId: json['user_id'],
    );
  }

  factory Payment.fromMap(Map<String, dynamic> map) => Payment.fromJson(map);

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
