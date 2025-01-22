import 'package:hive/hive.dart';
import 'package:yaz/models/payment.dart';

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 1;

  @override
  Payment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // التعامل مع القيم الفارغة والتحويلات
    final amount = fields[2];
    double parsedAmount = 0.0;

    if (amount != null) {
      if (amount is double) {
        parsedAmount = amount;
      } else if (amount is int) {
        parsedAmount = amount.toDouble();
      } else if (amount is String) {
        parsedAmount = double.tryParse(amount) ?? 0.0;
      }
    }

    return Payment(
      id: fields[0] as int?,
      customerId: fields[1] != null ? int.parse(fields[1].toString()) : 0,
      amount: parsedAmount,
      date: fields[3] is String
          ? DateTime.parse(fields[3] as String)
          : (fields[3] as DateTime? ?? DateTime.now()),
      notes: fields[4] as String?,
      reminderDate: fields[5] is String
          ? DateTime.parse(fields[5] as String)
          : fields[5] as DateTime?,
      reminderSent: fields[6] as bool? ?? false,
      isSynced: fields[7] as bool? ?? false,
      isDeleted: fields[8] as bool? ?? false,
      deletedAt: fields[9] is String
          ? DateTime.parse(fields[9] as String)
          : fields[9] as DateTime?,
      customer: fields[10] as Map<String, dynamic>?,
      title: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Payment obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.reminderDate)
      ..writeByte(6)
      ..write(obj.reminderSent)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.isDeleted)
      ..writeByte(9)
      ..write(obj.deletedAt)
      ..writeByte(10)
      ..write(obj.customer)
      ..writeByte(11)
      ..write(obj.title);
  }
}
