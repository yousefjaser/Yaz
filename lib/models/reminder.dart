import 'package:hive/hive.dart';

part 'reminder.g.dart';

@HiveType(typeId: 3)
class Reminder {
  @HiveField(0)
  String? id;

  @HiveField(1)
  final int customerId;

  @HiveField(2)
  final DateTime reminderDate;

  @HiveField(3)
  final String message;

  @HiveField(4)
  bool isCompleted;

  Reminder({
    this.id,
    required this.customerId,
    required this.reminderDate,
    required this.message,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'reminder_date': reminderDate.toIso8601String(),
      'message': message,
      'is_completed': isCompleted,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id']?.toString(),
      customerId: map['customer_id'],
      reminderDate: DateTime.parse(map['reminder_date']),
      message: map['message'],
      isCompleted: map['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Reminder.fromJson(Map<String, dynamic> json) =>
      Reminder.fromMap(json);
}
