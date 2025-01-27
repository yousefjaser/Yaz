import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/reminder.dart';

class LocalStorageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = await getDatabasesPath();
    final dbPath = join(path, 'yaz_local.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // إنشاء جداول قاعدة البيانات
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            color TEXT,
            sync_status TEXT DEFAULT 'pending',
            remote_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            sync_status TEXT DEFAULT 'pending',
            remote_id TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');

        await db.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            reminder_date TEXT NOT NULL,
            message TEXT NOT NULL,
            is_completed INTEGER DEFAULT 0,
            sync_status TEXT DEFAULT 'pending',
            remote_id TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');
      },
    );
  }

  // عمليات العملاء
  static Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', {
      'name': customer.name,
      'phone': customer.phone,
      'color': customer.color,
      'sync_status': 'pending'
    });
  }

  static Future<List<Customer>> getCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers');
    return List.generate(maps.length, (i) {
      return Customer(
        id: maps[i]['id'],
        name: maps[i]['name'],
        phone: maps[i]['phone'],
        color: maps[i]['color'] ?? '#FF0000',
      );
    });
  }

  // عمليات المدفوعات
  static Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', {
      'customer_id': payment.customerId,
      'amount': payment.amount,
      'date': payment.date.toIso8601String(),
      'notes': payment.notes,
      'sync_status': 'pending'
    });
  }

  static Future<List<Payment>> getCustomerPayments(int customerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return List.generate(maps.length, (i) {
      return Payment(
        id: maps[i]['id'],
        customerId: maps[i]['customer_id'],
        amount: maps[i]['amount'],
        date: DateTime.parse(maps[i]['date']),
        notes: maps[i]['notes'],
      );
    });
  }

  // عمليات التذكيرات
  static Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('reminders', {
      'customer_id': reminder.customerId,
      'reminder_date': reminder.reminderDate.toIso8601String(),
      'message': reminder.message,
      'is_completed': reminder.isCompleted ? 1 : 0,
      'sync_status': 'pending'
    });
  }

  // مزامنة البيانات مع السيرفر
  static Future<void> syncWithServer() async {
    final db = await database;

    // مزامنة العملاء
    final pendingCustomers = await db
        .query('customers', where: 'sync_status = ?', whereArgs: ['pending']);
    // قم بإرسال العملاء إلى Supabase

    // مزامنة المدفوعات
    final pendingPayments = await db
        .query('payments', where: 'sync_status = ?', whereArgs: ['pending']);
    // قم بإرسال المدفوعات إلى Supabase

    // مزامنة التذكيرات
    final pendingReminders = await db
        .query('reminders', where: 'sync_status = ?', whereArgs: ['pending']);
    // قم بإرسال التذكيرات إلى Supabase
  }
}
