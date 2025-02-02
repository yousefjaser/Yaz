import 'package:flutter/material.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/models/customer.dart';
import 'package:intl/intl.dart' as intl;
import 'package:yaz/services/reminder_service.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final Payment payment;
  final Customer customer;

  const PaymentDetailsScreen({
    super.key,
    required this.payment,
    required this.customer,
  });

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  ReminderService? _reminderService;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeReminderService();
  }

  Future<void> _initializeReminderService() async {
    _reminderService = await ReminderService.getInstance();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _scheduleReminder(Payment payment) async {
    try {
      final reminderService = await ReminderService.getInstance();
      if (payment.reminderDate == null) {
        throw Exception('لم يتم تحديد موعد التذكير');
      }

      if (payment.id == null) {
        throw Exception('معرف الدفعة غير موجود');
      }

      await reminderService.scheduleReminder(payment.id!, payment.reminderDate!);
    } catch (e) {
      debugPrint('خطأ في جدولة التذكير: $e');
      rethrow;
    }
  }

  Future<void> _handleAction(BuildContext context) async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _scheduleReminder(widget.payment);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('تم جدولة التذكير بنجاح')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('خطأ في جدولة التذكير: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remainingTime = widget.payment.reminderDate?.difference(now);
    final hasReminder = widget.payment.reminderDate != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدفعة'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المبلغ: ${widget.payment.amount.toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Text(
                        'تاريخ الدفع: ${intl.DateFormat('yyyy/MM/dd').format(widget.payment.date)}',
                      ),
                      if (widget.payment.notes != null) ...[
                        const SizedBox(height: 8),
                        Text('ملاحظات: ${widget.payment.notes}'),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasReminder) ...[
                const SizedBox(height: 16),
                _buildReminderSection(context, widget.payment),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (duration.inMinutes < 1) {
      return 'حان موعد السداد';
    }

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours ساعة');
    if (minutes > 0) parts.add('$minutes دقيقة');

    return parts.join(' و ');
  }

  Widget _buildReminderSection(BuildContext context, Payment payment) {
    final now = DateTime.now().toLocal();
    final reminderDate = payment.reminderDate!.toLocal();
    final remainingTime = reminderDate.difference(now);
    final reminderSent = payment.reminderSent ?? false;
    final notes = payment.notes ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alarm,
                  color: Colors.blue.withAlpha(200),
                ),
                const SizedBox(width: 8),
                Text(
                  'التذكير',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withAlpha(220),
                  ),
                ),
                const Spacer(),
                if (!reminderSent)
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    onPressed: () => _handleAction(context),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: reminderSent
                        ? Colors.green.withAlpha(255)
                        : remainingTime.isNegative
                            ? Colors.red.withAlpha(255)
                            : Colors.orange.withAlpha(255),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reminderSent
                        ? 'تم الإرسال'
                        : remainingTime.isNegative
                            ? 'متأخر'
                            : 'قيد الانتظار',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'موعد التذكير: ${intl.DateFormat('yyyy/MM/dd HH:mm', 'ar').format(reminderDate)}',
            ),
            if (!reminderSent) ...[
              const SizedBox(height: 8),
              Text(
                remainingTime.isNegative
                    ? 'متأخر بـ ${_formatDuration(-remainingTime)}'
                    : 'متبقي ${_formatDuration(remainingTime)}',
                style: TextStyle(
                  color: remainingTime.isNegative ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظات: $notes'),
            ],
          ],
        ),
      ),
    );
  }
}
