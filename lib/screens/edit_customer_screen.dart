import 'package:flutter/material.dart';
import 'package:yaz/models/customer.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class EditCustomerScreen extends StatefulWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  _EditCustomerScreenState createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  bool _hasUnsavedChanges = false;
  String? _selectedColor;
  bool _isOfflineMode = false;
  final List<String> _colorOptions = [
    '#FF5252', // أحمر
    '#448AFF', // أزرق
    '#4CAF50', // أخضر
    '#FFC107', // أصفر
    '#9C27B0', // بنفسجي
    '#FF9800', // برتقالي
    '#795548', // بني
    '#607D8B', // رمادي
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone);
    _addressController = TextEditingController(text: widget.customer.address);
    _notesController = TextEditingController(text: widget.customer.notes);
    _selectedColor = widget.customer.color;

    // إضافة مستمعين للتغييرات
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);

    // التحقق من حالة الاتصال
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectivityStatus(result);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(result);
  }

  void _updateConnectivityStatus(ConnectivityResult result) {
    setState(() {
      _isOfflineMode = result == ConnectivityResult.none;
    });
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
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

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        content: const Text('لديك تغييرات غير محفوظة. هل تريد تجاهلها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('تعديل العميل'),
                if (_isOfflineMode) ...[
                  const SizedBox(width: 8),
                  const Tooltip(
                    message: 'وضع عدم الاتصال',
                    child: Icon(
                      Icons.cloud_off,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (_hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildSaveButton(),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة العميل واللون
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                  _selectedColor!.replaceAll('#', '0xFF'))),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _nameController.text.isEmpty
                                    ? '?'
                                    : _nameController.text.characters.first,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _colorOptions
                                .map((color) => _buildColorOption(color))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // معلومات العميل
                    _buildTextField(
                      controller: _nameController,
                      label: 'اسم العميل',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم العميل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال رقم الهاتف';
                        }
                        if (!RegExp(r'^\d{9,10}$').hasMatch(value)) {
                          return 'رقم الهاتف غير صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressController,
                      label: 'العنوان',
                      icon: Icons.location_on,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'ملاحظات',
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    if (!_hasUnsavedChanges)
                      Center(
                        child: Text(
                          'لم يتم إجراء أي تغييرات',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: _hasUnsavedChanges
              ? FloatingActionButton.extended(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
      ),
    );
  }

  Widget _buildColorOption(String color) {
    final isSelected = color == _selectedColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _hasUnsavedChanges = true;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(int.parse(color.replaceAll('#', '0xFF'))),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: const Icon(Icons.save),
      label: const Text('حفظ'),
    );
  }

  void _saveChanges() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final updatedCustomer = widget.customer.copyWith(
          name: _nameController.text,
          phone: _phoneController.text,
          address:
              _addressController.text.isEmpty ? null : _addressController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          color: _selectedColor,
          isSynced: !_isOfflineMode, // تحديث حالة المزامنة
        );

        final customersProvider = context.read<CustomersProvider>();
        await customersProvider.updateCustomer(updatedCustomer);

        // إذا كان في وضع عدم الاتصال، قم بتخزين التغييرات محلياً
        if (_isOfflineMode) {
          await customersProvider.addToSyncQueue(updatedCustomer);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'تم حفظ التغييرات محلياً وسيتم مزامنتها عند توفر الاتصال'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
          );
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOfflineMode
                ? 'حدث خطأ أثناء الحفظ المحلي: $e'
                : 'حدث خطأ أثناء الحفظ: $e'),
          ),
        );
      }
    }
  }
}
