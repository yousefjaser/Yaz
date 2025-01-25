import 'package:uuid/uuid.dart';

class Reminder {
  final String id;
  final int customerId;
  final DateTime reminderDate;
  final String message;
  bool isCompleted;
  final DateTime createdAt;

  Reminder({
    String? id,
    required this.customerId,
    required this.reminderDate,
    required this.message,
    this.isCompleted = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'reminder_date': reminderDate.toIso8601String(),
      'message': message,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      customerId: json['customer_id'] as int,
      reminderDate: DateTime.parse(json['reminder_date']),
      message: json['message'],
      isCompleted: json['is_completed'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
