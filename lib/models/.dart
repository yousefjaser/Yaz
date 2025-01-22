// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 0;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      id: fields[0] as int?,
      name: (fields[1] as String?) ?? '',
      phone: (fields[2] as String?) ?? '',
      address: fields[3] as String?,
      notes: fields[4] as String?,
      color: fields[5] as String?,
      balance: (fields[6] as num?)?.toDouble() ?? 0.0,
      payments: (fields[7] as List?)?.cast<Payment>() ?? [],
      lastPaymentDate: fields[8] as DateTime?,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
      deletedAt: fields[11] as DateTime?,
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

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
