import 'package:flutter/material.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/models/customer.dart';
import 'package:intl/intl.dart' as intl;

class PaymentDetailsScreen extends StatelessWidget {
  final Payment payment;
  final Customer customer;

  const PaymentDetailsScreen({
    super.key,
    required this.payment,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remainingTime = payment.reminderDate?.difference(now);
    final hasReminder = payment.reminderDate != null;

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
                        'المبلغ: ${payment.amount.toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Text(
                        'تاريخ الدفع: ${intl.DateFormat('yyyy/MM/dd').format(payment.date)}',
                      ),
                      if (payment.notes != null) ...[
                        const SizedBox(height: 8),
                        Text('ملاحظات: ${payment.notes}'),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasReminder) ...[
                const SizedBox(height: 16),
                _buildReminderSection(context, payment),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm),
                const SizedBox(width: 8),
                const Text(
                  'التذكير',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: payment.reminderSent
                        ? Colors.green
                        : remainingTime.isNegative
                            ? Colors.red
                            : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    payment.reminderSent
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
            if (!payment.reminderSent) ...[
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
          ],
        ),
      ),
    );
  }
}
