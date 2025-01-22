import 'package:flutter/material.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:intl/intl.dart' as intl;

class EditPaymentSheet extends StatefulWidget {
  final Customer customer;
  final Payment payment;
  final VoidCallback onPaymentEdited;

  const EditPaymentSheet({
    super.key,
    required this.customer,
    required this.payment,
    required this.onPaymentEdited,
  });

  @override
  State<EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<EditPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  bool _isDebt = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.payment.amount.abs().toString();
    _notesController.text = widget.payment.notes ?? '';
    _selectedDate = widget.payment.date;
    _isDebt = widget.payment.amount < 0;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final updatedPayment = widget.payment.copyWith(
      amount: _isDebt ? -amount : amount,
      date: _selectedDate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    try {
      final db = await DatabaseService.getInstance();
      await db.updatePayment(updatedPayment);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onPaymentEdited();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الدفعة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث الدفعة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isDebt ? 'تعديل الدين' : 'تعديل الدفعة',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: '₪',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال المبلغ';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'الرجاء إدخال مبلغ صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('دفعة'),
                      value: false,
                      groupValue: _isDebt,
                      onChanged: (value) => setState(() => _isDebt = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('دين'),
                      value: true,
                      groupValue: _isDebt,
                      onChanged: (value) => setState(() => _isDebt = value!),
                    ),
                  ),
                ],
              ),
              ListTile(
                title: const Text('تاريخ الدفعة'),
                subtitle: Text(
                  intl.DateFormat('yyyy/MM/dd').format(_selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _updatePayment,
                child: const Text('حفظ التعديلات'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
