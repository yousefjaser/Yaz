import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/providers/customers_provider.dart';

class AddCustomerSheet extends StatefulWidget {
  const AddCustomerSheet({super.key});

  @override
  State<AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<AddCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedColor = '#448AFF'; // اللون الافتراضي
  String _selectedCountryCode = '+970'; // رمز الدولة الافتراضي

  final List<Map<String, String>> _countryCodes = [
    {'code': '+970', 'name': 'فلسطين'},
    {'code': '+972', 'name': 'إسرائيل'},
    {'code': '+962', 'name': 'الأردن'},
    {'code': '+20', 'name': 'مصر'},
    {'code': '+966', 'name': 'السعودية'},
  ];

  final List<Color> _availableColors = [
    const Color(0xFFFF5252), // أحمر
    const Color(0xFF448AFF), // أزرق
    const Color(0xFF66BB6A), // أخضر
    const Color(0xFFFFA726), // برتقالي
    const Color(0xFFAB47BC), // بنفسجي
    const Color(0xFFEC407A), // وردي
    const Color(0xFF26A69A), // فيروزي
    const Color(0xFF8D6E63), // بني
  ];

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 16),
                  child: Text(
                    'إضافة عميل',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {}),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'الرجاء إدخال اسم العميل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 120,
                      margin: const EdgeInsets.only(left: 8),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCountryCode,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        ),
                        items: _countryCodes.map((country) {
                          return DropdownMenuItem(
                            value: country['code'],
                            child:
                                Text('${country['name']} ${country['code']}'),
                          );
                        }).toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return _countryCodes.map((country) {
                            return Text(country['code']!);
                          }).toList();
                        },
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryCode = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: '059xxxxxxxxx',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setState(() {}),
                        validator: _validatePhone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    hintText: 'أضف أي ملاحظات خاصة بالعميل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('لون العميل'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableColors.length,
                    itemBuilder: (context, index) {
                      final color = _availableColors[index];
                      final colorHex =
                          '#${color.value.toRadixString(16).substring(2)}';
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedColor = colorHex),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == colorHex
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: _selectedColor == colorHex
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isFormValid() ? _submitForm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFormValid() ? Colors.deepPurple : Colors.grey[300],
                      foregroundColor:
                          _isFormValid() ? Colors.white : Colors.grey[600],
                    ),
                    child: const Text(
                      'إضافة عميل',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isFormValid() {
    return _nameController.text.isNotEmpty &&
        _validatePhone(_phoneController.text) == null;
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final customer = Customer(
        name: _nameController.text,
        phone: '$_selectedCountryCode${_phoneController.text}',
        address: _addressController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        color: _selectedColor,
      );

      context.read<CustomersProvider>().addCustomer(customer);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال رقم الهاتف';
    }

    // إزالة المسافات والرموز الخاصة
    value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // التحقق من أن الرقم يبدأ بـ 0 أو يحتوي على 9 أرقام
    if (!value.startsWith('0') && value.length != 9) {
      return 'رقم الهاتف يجب أن يبدأ بـ 0 أو يتكون من 9 أرقام';
    }

    // التحقق من طول الرقم
    if (value.startsWith('0') && value.length != 10) {
      return 'رقم الهاتف يجب أن يتكون من 10 أرقام عند البدء بـ 0';
    }

    return null;
  }
}
