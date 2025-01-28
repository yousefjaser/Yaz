import 'package:flutter/material.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:yaz/models/customer.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/services/reminder_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isDebt = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTypeChip(
                      label: 'دين',
                      isSelected: _isDebt,
                      icon: Icons.arrow_downward,
                      color: Colors.red,
                      onSelected: (selected) {
                        setState(() => _isDebt = selected);
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildTypeChip(
                      label: 'دفعة',
                      isSelected: !_isDebt,
                      icon: Icons.arrow_upward,
                      color: Colors.green,
                      onSelected: (selected) {
                        setState(() => _isDebt = !selected);
                      },
                    ),
                  ],
                ),
              ),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'عنوان العملية',
                icon: Icons.title,
                hint: _isDebt ? 'مثال: دين بضاعة' : 'مثال: دفعة شهر 1',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: 'ملاحظات',
                icon: Icons.note,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildOptionsCard(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required Color color,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : color,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'المبلغ',
          prefixIcon: Icon(
            Icons.attach_money,
            color: _isDebt ? Colors.red : Colors.green,
          ),
          suffixText: '₪',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: _validateAmount,
        style: TextStyle(
          color: _isDebt ? Colors.red : Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: _showDatePicker,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 16),
              Text(
                intl.DateFormat('yyyy/MM/dd').format(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int? maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        maxLines: maxLines ?? 1,
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _sendConfirmationSMS,
            onChanged: (value) {
              setState(() => _sendConfirmationSMS = value);
            },
            title: const Text('إرسال رسالة تأكيد'),
            subtitle: const Text('إرسال رسالة واتساب للعميل'),
            secondary: const Icon(Icons.message),
          ),
          const Divider(height: 1),
          SwitchListTile(
            value: _setReminder,
            onChanged: (value) {
              setState(() {
                _setReminder = value;
                if (!_setReminder) _reminderDate = null;
              });
            },
            title: Row(
              children: [
                const Text('تذكير بالموعد'),
                if (_setReminder && _reminderDate != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      _formatDateTime(_reminderDate!),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.edit, size: 16),
                    onDeleted: _showReminderDatePicker,
                  ),
                ],
              ],
            ),
            subtitle: const Text('تذكير بموعد التسديد'),
            secondary: const Icon(Icons.alarm),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _savePayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isDebt ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isDebt ? Icons.arrow_downward : Icons.arrow_upward),
                const SizedBox(width: 8),
                Text(_isDebt ? 'إضافة دين' : 'إضافة دفعة'),
              ],
            ),
    );
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال المبلغ';
    }
    if (double.tryParse(value) == null) {
      return 'الرجاء إدخال رقم صحيح';
    }
    if (double.parse(value) <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر';
    }
    return null;
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.getInstance();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final amount = double.parse(_amountController.text);
      final finalAmount = _isDebt ? -amount : amount;

      final payment = Payment(
        customerId: widget.customer.id!,
        amount: finalAmount,
        date: _selectedDate,
        notes: _notesController.text.trim(),
        reminderDate: _setReminder ? _reminderDate : null,
        reminderSent: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: false,
        deletedAt: null,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        reminderSentAt: null,
        isSynced: true,
        userId: userId,
      );

      await db.savePayment(payment);

      if (_sendConfirmationSMS) {
        final whatsapp = WhatsAppService();
        final message = _buildConfirmationMessage(payment);
        await whatsapp.sendMessage(
          phoneNumber: widget.customer.phone,
          message: message,
        );
      }

      if (_setReminder && payment.reminderDate != null) {
        final reminderService = await ReminderService.getInstance();
        // ## await reminderService.schedulePaymentReminder(
        // ##   payment,
        // ##   widget.customer,
        // ##   payment.reminderDate!,
        // ## );
      }

      if (!mounted) return;

      Navigator.pop(context);
      widget.onPaymentAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_isDebt ? 'تم إضافة الدين بنجاح' : 'تم إضافة الدفعة بنجاح'),
          backgroundColor: _isDebt ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      print('خطأ في حفظ الدفعة: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildConfirmationMessage(Payment payment) {
    final type = payment.amount < 0 ? 'دين' : 'دفعة';
    final amount = payment.amount.abs().toStringAsFixed(2);
    final date = intl.DateFormat('yyyy/MM/dd').format(payment.date);

    var message = 'تم تسجيل $type بقيمة $amount ₪ بتاريخ $date';
    if (payment.title != null) {
      message += '\nعنوان العملية: ${payment.title}';
    }
    if (payment.notes != null && payment.notes!.isNotEmpty) {
      message += '\nملاحظات: ${payment.notes}';
    }
    if (payment.reminderDate != null) {
      final reminderDate =
          intl.DateFormat('yyyy/MM/dd HH:mm').format(payment.reminderDate!);
      message += '\nموعد التسديد المتوقع: $reminderDate';
    }

    return message;
  }

  String _formatDateTime(DateTime dateTime) {
    return intl.DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _titleController.dispose();
    super.dispose();
  }
}
