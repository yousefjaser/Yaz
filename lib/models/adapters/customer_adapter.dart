import 'package:hive/hive.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 0;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    // التعامل مع القيم الفارغة والتحويلات
    final balance = fields[6];
    double parsedBalance = 0.0;

    if (balance != null) {
      if (balance is double) {
        parsedBalance = balance;
      } else if (balance is int) {
        parsedBalance = balance.toDouble();
      } else if (balance is String) {
        parsedBalance = double.tryParse(balance) ?? 0.0;
      }
    }

    return Customer(
      id: fields[0] as int?,
      name: fields[1] as String? ?? '',
      phone: fields[2] as String? ?? '',
      address: fields[3] as String?,
      notes: fields[4] as String?,
      color: fields[5] as String? ?? '#448AFF',
      balance: parsedBalance,
      payments: (fields[7] as List?)?.cast<Payment>() ?? [],
      lastPaymentDate: fields[8] is String
          ? DateTime.parse(fields[8] as String)
          : fields[8] as DateTime?,
      createdAt: fields[9] is String
          ? DateTime.parse(fields[9] as String)
          : (fields[9] as DateTime? ?? DateTime.now()),
      updatedAt: fields[10] is String
          ? DateTime.parse(fields[10] as String)
          : (fields[10] as DateTime? ?? DateTime.now()),
      deletedAt: fields[11] is String
          ? DateTime.parse(fields[11] as String)
          : fields[11] as DateTime?,
      userId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.balance)
      ..writeByte(7)
      ..write(obj.payments)
      ..writeByte(8)
      ..write(obj.lastPaymentDate)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.deletedAt)
      ..writeByte(12)
      ..write(obj.userId);
  }
}
