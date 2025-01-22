import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class HiveTypeIds {
  static const int customer = 0;
  static const int payment = 1;
}

@HiveType(typeId: 1)
class HiveFieldIds {
  // Customer fields
  static const int customerId = 0;
  static const int customerName = 1;
  static const int customerPhone = 2;
  static const int customerAddress = 3;
  static const int customerNotes = 4;
  static const int customerColor = 5;
  static const int customerBalance = 6;
  static const int customerPayments = 7;
  static const int customerLastPaymentDate = 8;
  static const int customerCreatedAt = 9;
  static const int customerUpdatedAt = 10;
  static const int customerDeletedAt = 11;
  static const int customerUserId = 12;

  // Payment fields
  static const int paymentId = 0;
  static const int paymentCustomerId = 1;
  static const int paymentAmount = 2;
  static const int paymentDate = 3;
  static const int paymentNotes = 4;
  static const int paymentReminderDate = 5;
  static const int paymentReminderSent = 6;
  static const int paymentIsSynced = 7;
  static const int paymentIsDeleted = 8;
  static const int paymentDeletedAt = 9;
  static const int paymentCustomer = 10;
  static const int paymentTitle = 11;
}
