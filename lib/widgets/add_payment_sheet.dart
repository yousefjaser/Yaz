import 'package:flutter/material.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:yaz/models/customer.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/services/reminder_service.dart';

class AddPaymentSheet extends StatefulWidget {
  final Customer customer;
  final VoidCallback onPaymentAdded;

  const AddPaymentSheet({
    super.key,
    required this.customer,
    required this.onPaymentAdded,
  });

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleController = TextEditingController();
  late DateTime _selectedDate;
  bool _sendConfirmationSMS = false;
  bool _setReminder = false;
  DateTime? _reminderDate;
  bool _isDebt = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('دفعة'),
                    selected: !_isDebt,
                    onSelected: (selected) {
                      setState(() {
                        _isDebt = !selected;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('دين'),
                    selected: _isDebt,
                    onSelected: (selected) {
                      setState(() {
                        _isDebt = selected;
                      });
                    },
                  ),
                ],
              ),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                  suffixText: '₪',
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'اسم الدفعة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: دفعة شهر 1',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _sendConfirmationSMS,
                onChanged: (value) {
                  setState(() {
                    _sendConfirmationSMS = value ?? false;
                  });
                },
                title: const Text('إرسال رسالة تأكيد'),
              ),
              CheckboxListTile(
                value: _setReminder,
                onChanged: (value) {
                  setState(() {
                    _setReminder = value ?? false;
                    if (!_setReminder) {
                      _reminderDate = null;
                    }
                  });
                },
                title: Row(
                  children: [
                    const Text('موعد التسديد المتوقع'),
                    if (_setReminder && _reminderDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDateTime(_reminderDate!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle:
                    const Text('سيتم إرسال رسالة واتساب تذكيرية في هذا الموعد'),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _setReminder ? _showReminderDatePicker : null,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _savePayment,
                child: const Text('إضافة دفعة'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final hour = localDateTime.hour.toString().padLeft(2, '0');
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    return '${localDateTime.year}/${localDateTime.month}/${localDateTime.day} $hour:$minute';
  }

  Future<void> _showReminderDatePicker() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: false,
              ),
              child: child!,
            ),
          );
        },
      );

      if (time != null) {
        setState(() {
          _reminderDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ).toLocal();
        });
      }
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final payment = Payment(
      customerId: widget.customer.id!,
      amount: _isDebt ? -amount : amount,
      date: _selectedDate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      reminderDate: _reminderDate,
      reminderSent: false,
      title: _titleController.text.isEmpty ? null : _titleController.text,
    );

    try {
      final db = await DatabaseService.getInstance();
      await db.insertPayment(payment);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onPaymentAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الدفعة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ الدفعة: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال المبلغ';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'الرجاء إدخال مبلغ صحيح';
    }
    return null;
  }
}
