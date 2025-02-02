import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/screens/edit_customer_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  double _containerHeight = 200.0;
  double _containerOpacity = 1.0;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _initDb();
    _scrollController.addListener(_onScroll);
    // تحميل الدفعات مباشرة عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPayments();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // إزالة التحميل من didChangeDependencies لتجنب التحميل المزدوج
    if (!_isInitialized) {
      _isInitialized = true;
    }
  }

  Future<void> _initDb() async {
    _db = await DatabaseService.getInstance();
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final db = await DatabaseService.getInstance();
      final payments = await db.getCustomerPayments(widget.customer.id!);

      if (!mounted) return;

      setState(() {
        _payments = payments.where((p) => !p.isDeleted).toList();
        _isLoading = false;
      });

      _updateBalance();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateBalance() {
    if (!mounted || _payments.isEmpty) return;

    final newBalance = _calculateTotalAmount();
    if (widget.customer.balance != newBalance) {
      setState(() {
        widget.customer.balance = newBalance;
      });

      context.read<CustomersProvider>().updateCustomer(widget.customer);
    }
  }

  double _calculateTotalAmount() {
    return _payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double _calculateTotalPaid() {
    return _payments
        .where((p) => p.amount > 0)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  double _calculateTotalDebt() {
    return _payments
        .where((p) => p.amount < 0)
        .fold(0.0, (sum, p) => sum + p.amount);
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

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset;
    final maxOffset = 100.0;

    setState(() {
      _containerHeight = 200.0 - (offset).clamp(0.0, maxOffset);
      _containerOpacity = (1 - (offset / maxOffset)).clamp(0.0, 1.0);
      _isExpanded = offset < maxOffset / 2;
    });
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAmountColumn(
                      'المبلغ الكلي', widget.customer.balance, Colors.blue),
                  _buildAmountColumn(
                      'المدفوع', _calculateTotalPaid(), Colors.green),
                  _buildAmountColumn(
                      'الدين المتبقي', _calculateTotalDebt(), Colors.red),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildContactInfo(),
                          const SizedBox(height: 16),
                          _buildAdditionalInfo(),
                        ],
                      ),
                    ),
                  ),
                  _isLoading
                      ? const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final payment = _payments[index];
                              return _buildPaymentItem(payment);
                            },
                            childCount: _payments.length,
                          ),
                        ),
                ],
              ),
            ),
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

  Widget _buildAmountColumn(String title, double amount, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${amount.abs().toStringAsFixed(2)} ₪',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // معلومات الاتصال الرئيسية
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // صورة العميل
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(int.parse(
                        widget.customer.color.replaceAll('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.customer.name.characters.first,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // معلومات العميل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.customer.phone,
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // أزرار الاتصال السريع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  icon: Icons.phone,
                  label: 'اتصال',
                  color: Colors.blue,
                  onTap: () => _makePhoneCall(widget.customer.phone),
                ),
                _buildQuickActionButton(
                  icon: Icons.message,
                  label: 'رسالة',
                  color: Colors.green,
                  onTap: () => _sendWhatsApp(widget.customer.phone),
                ),
                _buildQuickActionButton(
                  icon: Icons.edit,
                  label: 'تعديل',
                  color: Colors.orange,
                  onTap: () => _editCustomer(),
                ),
                _buildQuickActionButton(
                  icon: Icons.share,
                  label: 'مشاركة',
                  color: Colors.purple,
                  onTap: () => _shareCustomerDetails(),
                ),
              ],
            ),
          ),
          // العنوان إذا كان موجوداً
          if (widget.customer.address?.isNotEmpty ?? false)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.customer.address!,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.map),
                    onPressed: () => _openInMaps(widget.customer.address!),
                    tooltip: 'فتح في الخريطة',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    final hasNotes = widget.customer.notes?.isNotEmpty ?? false;
    final hasCreatedAt = widget.customer.createdAt != null;

    if (!hasNotes && !hasCreatedAt) return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasNotes)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ملاحظات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.customer.notes!,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          if (hasCreatedAt)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: hasNotes
                      ? BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تاريخ الإضافة:',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(widget.customer.createdAt),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Payment payment) {
    return Dismissible(
      key: Key(payment.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Text(
          'حذف',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor:
                    payment.amount > 0 ? Colors.green[100] : Colors.red[100],
                child: Icon(
                  payment.amount > 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: payment.amount > 0 ? Colors.green : Colors.red,
                ),
              ),
              if (!payment.isSynced)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sync,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Text(
                payment.title ?? (payment.amount > 0 ? 'دفعة' : 'دين'),
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 16,
                ),
              ),
              if (!payment.isSynced) ...[
                const SizedBox(width: 8),
                const Tooltip(
                  message: 'في انتظار المزامنة',
                  child: Icon(
                    Icons.cloud_upload,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ],
            ],
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
                final (success, errorMessage) = await whatsapp.sendMessage(
                  phoneNumber: widget.customer.phone,
                  message: messageController.text.trim(),
                );

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الرسالة بنجاح')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMessage ?? 'فشل في إرسال الرسالة')),
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

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy/MM/dd').format(date);
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
      // تحديث حالة الحذف
      payment.isDeleted = true;
      payment.deletedAt = DateTime.now();
      payment.isSynced = false;

      // حفظ التغييرات محلياً
      await _db.updatePayment(payment);

      if (!mounted) return;

      setState(() {
        _payments.remove(payment);
      });

      _updateBalance();

      // تحديث حالة المزامنة للعميل
      widget.customer.isSynced = false;
      await _db.updateCustomer(widget.customer);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نقل الدفعة إلى سلة المحذوفات')),
      );

      // محاولة المزامنة مع السيرفر إذا كان هناك اتصال
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        try {
          await _db.syncPayment(payment);
          await _db.syncCustomer(widget.customer);
        } catch (e) {
          debugPrint('خطأ في المزامنة: $e');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف الدفعة: $e')),
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

  Future<void> _editCustomer() async {
    // تنفيذ عملية تعديل العميل
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCustomerScreen(customer: widget.customer),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _shareCustomerDetails() async {
    final text = '''
معلومات العميل:
الاسم: ${widget.customer.name}
رقم الهاتف: ${widget.customer.phone}
${widget.customer.address != null ? 'العنوان: ${widget.customer.address}\n' : ''}
المبلغ الكلي: ${widget.customer.balance} ₪
المدفوع: ${_calculateTotalPaid()} ₪
الدين المتبقي: ${_calculateTotalDebt()} ₪
''';

    // مشاركة المعلومات
    // يمكنك استخدام مكتبة share_plus هنا
  }

  Future<void> _openInMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url =
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress';

    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح الخريطة')),
      );
    }
  }
}
