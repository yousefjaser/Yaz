import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';
import 'package:yaz/widgets/add_payment_sheet.dart';
import 'package:intl/intl.dart' as intl;
import 'package:yaz/providers/customers_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:yaz/providers/settings_provider.dart';
import 'package:yaz/providers/auth_provider.dart';
import 'package:yaz/screens/trash_screen.dart';
import 'package:yaz/main.dart';
import 'package:yaz/screens/analytics_screen.dart';
import 'package:yaz/widgets/payment_details_screen.dart';
import 'package:yaz/widgets/edit_payment_sheet.dart';
import 'package:url_launcher/url_launcher.dart' show launch, canLaunch;
import 'package:yaz/widgets/export_report_sheet.dart';
import 'package:yaz/services/whatsapp_service.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late DatabaseService _db;
  List<Payment> _payments = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    _db = await DatabaseService.getInstance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadPayments();
      _isInitialized = true;
    }
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد اتصال بالإنترنت')),
      );
      return;
    }
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final db = await DatabaseService.getInstance();

      // محاولة جلب الدفعات مع إعادة المحاولة في حالة انتهاء الجلسة
      for (int i = 0; i < 3; i++) {
        try {
          final payments = await db.getCustomerPayments(widget.customer.id!);
          if (mounted) {
            setState(() {
              _payments = payments;
              _isLoading = false;
            });
          }
          return;
        } catch (e) {
          if (e.toString().contains('JWT expired')) {
            debugPrint('انتهت صلاحية الجلسة، محاولة تجديد الجلسة...');
            await Future.delayed(Duration(seconds: 1));
            continue;
          }
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب الدفعات: $e')),
        );
      }
    }
  }

  void _updateBalance() {
    if (_payments.isEmpty) return;
    final newBalance =
        _payments.fold(0.0, (sum, payment) => sum + payment.amount);
    if (widget.customer.balance != newBalance) {
      widget.customer.balance = newBalance;
      context.read<CustomersProvider>().updateCustomer(widget.customer);
    }
  }

  Future<void> _onPaymentTap(Payment payment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentDetailsScreen(
          payment: payment,
          customer: widget.customer,
        ),
      ),
    );
    _loadPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.customer.name),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Image.asset(
                'assets/images/whatsapp.png',
                width: 24,
                height: 24,
                color: Colors.white,
              ),
              onPressed: () => _showSendMessageDialog(context),
              tooltip: 'إرسال رسالة واتساب',
            ),
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) =>
                      ExportReportSheet(customer: widget.customer),
                );
              },
              tooltip: 'تصدير كشف حساب',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('الاسم:', widget.customer.name),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                                'رقم الهاتف:', widget.customer.phone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone),
                            onPressed: () =>
                                _makePhoneCall(widget.customer.phone),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            onPressed: () =>
                                _sendWhatsApp(widget.customer.phone),
                          ),
                        ],
                      ),
                      if (widget.customer.address != null) ...[
                        const Divider(),
                        _buildInfoRow('العنوان:', widget.customer.address!),
                      ],
                      if (widget.customer.notes != null) ...[
                        const Divider(),
                        _buildInfoRow('ملاحظات:', widget.customer.notes!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryCard(
                      'المبلغ المدفوع',
                      _calculateTotalPaid(),
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      'الدين المتبقي',
                      _calculateTotalDebt(),
                      Colors.red,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildPaymentsList(),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => AddPaymentSheet(
                customer: widget.customer,
                onPaymentAdded: _loadPayments,
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showSendMessageDialog(BuildContext context) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Image.asset(
              'assets/images/whatsapp.png',
              width: 28,
              height: 28,
              color: const Color(0xFF25D366),
            ),
            const SizedBox(width: 8),
            const Text('إرسال رسالة واتساب'),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'نص الرسالة:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء كتابة رسالة')),
                );
                return;
              }

              try {
                final whatsapp = WhatsAppService();
                final success = await whatsapp.sendMessage(
                  phoneNumber: widget.customer.phone,
                  message: messageController.text.trim(),
                );

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الرسالة بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('فشل في إرسال الرسالة')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e')),
                );
              }

              Navigator.pop(context);
            },
            child: const Text(
              'إرسال',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendWhatsApp(String phoneNumber) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر رمز الدولة'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, {
              'code': '+972',
              'phone': phoneNumber,
            }),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إسرائيل'),
                Text('+972', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, {
              'code': '+970',
              'phone': phoneNumber,
            }),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('فلسطين'),
                Text('+970', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      String formattedNumber = result['phone']!;
      if (formattedNumber.startsWith('0')) {
        formattedNumber = formattedNumber.substring(1);
      }

      final phoneWithCode = '${result['code']!.substring(1)}$formattedNumber';

      try {
        final webUrl = Uri.parse('https://wa.me/$phoneWithCode');
        await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح واتساب')),
        );
      }
    }
  }

  double _calculateTotalDebt() {
    return _payments
        .where((p) => p.amount < 0)
        .fold(0.0, (sum, p) => sum + p.amount.abs());
  }

  double _calculateTotalPaid() {
    return _payments
        .where((p) => p.amount > 0)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${amount.toStringAsFixed(2)} ₪',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotes(String notes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملاحظات'),
        content: Text(notes),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Payment payment) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل أنت متأكد من حذف هذه الدفعة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deletePayment(Payment payment) async {
    try {
      await _db.movePaymentToTrash(payment);

      setState(() {
        _payments.removeWhere((p) => p.id == payment.id);
        _updateBalance();
      });

      if (!mounted) return;
      context.read<CustomersProvider>().hidePayment(payment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نقل الدفعة إلى سلة المحذوفات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في حذف الدفعة')),
      );
    }
  }

  Future<void> _editPayment(Payment payment) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditPaymentSheet(
        customer: widget.customer,
        payment: payment,
        onPaymentEdited: _loadPayments,
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_payments.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد دفعات حتى الآن',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(8),
      child: ListView.separated(
        itemCount: _payments.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          color: Color(0xFF2A2A2A),
        ),
        itemBuilder: (context, index) {
          final payment = _payments[index];
          return Dismissible(
            key: Key(payment.id.toString()),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Text('حذف',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            secondaryBackground: Container(
              color: Colors.blue,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                _editPayment(payment);
                return false;
              } else {
                return await _confirmDelete(payment);
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                _deletePayment(payment);
              }
            },
            child: InkWell(
              onTap: () => _onPaymentTap(payment),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      payment.amount > 0 ? Colors.green[100] : Colors.red[100],
                  child: Icon(
                    payment.amount > 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: payment.amount > 0 ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  payment.title ?? (payment.amount > 0 ? 'دفعة' : 'دين'),
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intl.DateFormat('yyyy/MM/dd').format(payment.date),
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                      ),
                    ),
                    if (payment.notes?.isNotEmpty ?? false)
                      Text(
                        payment.notes!,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${payment.amount.abs().toStringAsFixed(2)} ₪',
                      style: TextStyle(
                        color: payment.amount > 0 ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFF888888),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
