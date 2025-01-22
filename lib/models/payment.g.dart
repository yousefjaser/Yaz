// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentAdapter extends TypeAdapter<Payment> {
  @override
  final int typeId = 1;

  @override
  Payment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Payment(
      id: fields[0] as int?,
      customerId: fields[1] as int,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      notes: fields[4] as String?,
      reminderDate: fields[5] as DateTime?,
      reminderSent: fields[6] as bool,
      isSynced: fields[7] as bool,
      isDeleted: fields[8] as bool,
      deletedAt: fields[9] as DateTime?,
      customer: (fields[10] as Map?)?.cast<String, dynamic>(),
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

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
