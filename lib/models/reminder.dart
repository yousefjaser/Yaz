import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 2)
class Reminder extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  int? customerId;

  @HiveField(2)
  DateTime reminderDate;

  @HiveField(3)
  String message;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isSynced;

  Reminder({
    this.id,
    this.customerId,
    required this.reminderDate,
    required this.message,
    this.isCompleted = false,
    DateTime? createdAt,
    this.isSynced = false,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id?.toString(),
      'customer_id': customerId,
      'reminder_date': reminderDate.toIso8601String(),
      'message': message,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id']?.toString(),
      customerId: json['customer_id'] != null
          ? int.parse(json['customer_id'].toString())
          : null,
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : DateTime.now(),
      message: json['message'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isSynced: json['is_synced'] ?? false,
    );
  }

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder.fromJson(map);
}
