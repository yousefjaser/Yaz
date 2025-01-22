import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/screens/customer_details_screen.dart';
import 'package:yaz/screens/edit_customer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaz/services/database_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:yaz/widgets/bottom_nav.dart';
import 'package:yaz/screens/profile_screen.dart';
import 'package:yaz/widgets/add_customer_sheet.dart';
import 'package:yaz/widgets/drawer_widget.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class CustomerListWidget extends StatefulWidget {
  final List<Customer> customers;

  const CustomerListWidget({
    super.key,
    required this.customers,
  });

  @override
  State<CustomerListWidget> createState() => _CustomerListWidgetState();
}

class _CustomerListWidgetState extends State<CustomerListWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<int, Payment?> _lastPayments = {};
  final _debouncer = Debouncer(milliseconds: 300);
  List<Customer> _filteredCustomers = [];

  DateTime? _startDate;
  DateTime? _endDate;
  RangeValues _balanceRange = const RangeValues(-10000, 10000);
  bool _showOnlyWithPayments = false;

  late DatabaseService _db;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _loadLastPayments();
    _initDb();
  }

  Future<void> _initDb() async {
    _db = await DatabaseService.getInstance();
  }

  @override
  void didUpdateWidget(CustomerListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers) {
      _filterCustomers(_searchController.text);
    }
  }

  void _filterCustomers(String query) {
    if (!mounted) return;
    _debouncer.run(() {
      if (!mounted) return;
      setState(() {
        if (query.isEmpty) {
          _filteredCustomers = widget.customers;
        } else {
          final searchLower = query.toLowerCase();
          _filteredCustomers = widget.customers.where((customer) {
            return customer.name.toLowerCase().contains(searchLower) ||
                customer.phone.contains(searchLower);
          }).toList();
        }
      });
    });
  }

  Future<void> _loadLastPayments() async {
    if (!mounted) return;
    for (var customer in widget.customers) {
      if (!mounted) return;
      if (customer.id != null && !_lastPayments.containsKey(customer.id)) {
        final payment =
            await context.read<CustomersProvider>().getLastPayment(customer);
        if (!mounted) return;
        setState(() {
          _lastPayments[customer.id!] = payment;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await context.read<CustomersProvider>().loadCustomers();
    _loadLastPayments();
    return Future.value();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خيارات الفلترة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                      _applyFilters();
                    }
                  },
                  child: const Text('من تاريخ'),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                      _applyFilters();
                    }
                  },
                  child: const Text('إلى تاريخ'),
                ),
              ],
            ),
            RangeSlider(
              values: _balanceRange,
              min: -10000,
              max: 10000,
              divisions: 100,
              labels: RangeLabels(
                '${_balanceRange.start.toStringAsFixed(0)} ₪',
                '${_balanceRange.end.toStringAsFixed(0)} ₪',
              ),
              onChanged: (values) {
                setState(() => _balanceRange = values);
                _applyFilters();
              },
            ),
            CheckboxListTile(
              title: const Text('إظهار العملاء الذين لديهم دفعات فقط'),
              value: _showOnlyWithPayments,
              onChanged: (value) {
                setState(() => _showOnlyWithPayments = value ?? false);
                _applyFilters();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _balanceRange = const RangeValues(-10000, 10000);
                _showOnlyWithPayments = false;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('إعادة تعيين'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    if (!mounted) return;
    _debouncer.run(() {
      if (!mounted) return;
      setState(() {
        _filteredCustomers = widget.customers.where((customer) {
          final searchMatch = _searchController.text.isEmpty ||
              customer.name
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              customer.phone.contains(_searchController.text);

          final dateMatch =
              (_startDate == null || customer.createdAt.isAfter(_startDate!)) &&
                  (_endDate == null || customer.createdAt.isBefore(_endDate!));

          final balanceMatch = customer.balance >= _balanceRange.start &&
              customer.balance <= _balanceRange.end;

          final paymentMatch =
              !_showOnlyWithPayments || (_lastPayments[customer.id] != null);

          return searchMatch && dateMatch && balanceMatch && paymentMatch;
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _applyFilters();
              },
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(8),
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _filteredCustomers.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _filteredCustomers.length) {
                      return const SizedBox(height: 80);
                    }
                    final customer = _filteredCustomers[index];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCustomerTile(context, customer),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCustomerDetails(BuildContext context, Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailsScreen(customer: customer),
      ),
    );
  }

  void _navigateToEditCustomer(BuildContext context, Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCustomerScreen(customer: customer),
      ),
    );
  }

  Widget _buildCustomerTile(BuildContext context, Customer customer) {
    final lastPayment = _lastPayments[customer.id];

    return Dismissible(
      key: Key(customer.id.toString()),
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
          _navigateToEditCustomer(context, customer);
          return false;
        } else {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('هل تريد نقل العميل إلى سلة المحذوفات؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('نقل'),
                ),
              ],
            ),
          );
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(
            int.parse(customer.color.replaceAll('#', '0xFF')),
          ),
          child: Text(
            customer.name.characters.first,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 16,
              ),
            ),
            Text(
              customer.phone,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
              ),
            ),
            if (lastPayment?.reminderDate != null)
              Text(
                _formatRemainingTime(lastPayment!.reminderDate!),
                style: TextStyle(
                  color: _getReminderColor(lastPayment.reminderDate!),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${customer.balance.toStringAsFixed(2)} ₪',
          style: TextStyle(
            color: customer.balance < 0 ? Colors.red : Colors.green,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _navigateToCustomerDetails(context, customer),
        onLongPress: () => _showQuickInfo(context, customer),
      ),
    );
  }

  String _formatRemainingTime(DateTime reminderDate) {
    final now = DateTime.now();
    final difference = reminderDate.difference(now);

    if (difference.isNegative) {
      return 'حان موعد السداد';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return 'موعد السداد خلال $days يوم';
    } else if (hours > 0) {
      return 'موعد السداد خلال $hours ساعة';
    }

    return 'موعد السداد اليوم';
  }

  Color _getReminderColor(DateTime reminderDate) {
    final now = DateTime.now();
    final difference = reminderDate.difference(now);

    if (difference.isNegative) {
      return Colors.red;
    }
    return Colors.orange;
  }

  void _showQuickInfo(BuildContext context, Customer customer) {
    final lastPayment = _lastPayments[customer.id];

    showModalBottomSheet(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.grey[400],
                  displayColor: Colors.black,
                ),
          ),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<List<dynamic>>(
              future: Future.wait<dynamic>([
                _calculateTotalPaid(customer),
                _calculateTotalDebt(customer),
                customer.id != null
                    ? _db.getCustomerPayments(customer.id!)
                    : Future.value(<Payment>[]),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final totalPaid = (snapshot.data![0] as num).toDouble();
                final totalDebt = (snapshot.data![1] as num).toDouble();
                final payments = snapshot.data![2] as List<Payment>;

                return SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(
                                int.parse('FF${customer.color.substring(1)}',
                                    radix: 16),
                              ),
                              child: Text(
                                customer.name.characters.first,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customer.phone,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.phone, size: 20),
                                        onPressed: () =>
                                            _makePhoneCall(customer.phone),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chat,
                                            color: Colors.green, size: 20),
                                        onPressed: () =>
                                            _sendWhatsApp(customer.phone),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (!snapshot.hasData)
                          const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          // ملخص المبالغ
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المبلغ المدفوع: ${totalPaid.toStringAsFixed(2)} ₪',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'الدين: ${totalDebt.toStringAsFixed(2)} ₪',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الرصيد: ${customer.balance.toStringAsFixed(2)} ₪',
                            style: TextStyle(
                              color: customer.balance < 0
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(height: 24),

                          // آخر الدفعات
                          const Text(
                            'آخر الدفعات:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...payments
                              .where((p) => !p.isDeleted)
                              .take(3)
                              .map((payment) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: payment.amount > 0
                                          ? Colors.green[100]
                                          : Colors.red[100],
                                      child: Icon(
                                        payment.amount > 0
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        color: payment.amount > 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    title: Text(
                                      payment.title ??
                                          (payment.amount > 0 ? 'دفعة' : 'دين'),
                                    ),
                                    subtitle: Text(
                                      intl.DateFormat('yyyy/MM/dd')
                                          .format(payment.date),
                                    ),
                                    trailing: Text(
                                      '${payment.amount.abs().toStringAsFixed(2)} ₪',
                                      style: TextStyle(
                                        color: payment.amount > 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                        if (lastPayment?.reminderDate != null) ...[
                          const Divider(height: 24),
                          Text(
                            _formatRemainingTime(lastPayment!.reminderDate!),
                            style: TextStyle(
                              color:
                                  _getReminderColor(lastPayment.reminderDate!),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن الاتصال بالرقم')),
      );
    }
  }

  Future<void> _sendWhatsApp(String phoneNumber) async {
    final formattedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$formattedNumber';
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح واتساب')),
      );
    }
  }

  Future<double> _calculateTotalPaid(Customer customer) async {
    if (customer.id == null) return 0.0;
    final payments = await _db.getCustomerPayments(customer.id!);
    double total = 0.0;
    for (var payment in payments) {
      if (payment.amount > 0 && !payment.isDeleted) {
        total += payment.amount;
      }
    }
    return total;
  }

  Future<double> _calculateTotalDebt(Customer customer) async {
    if (customer.id == null) return 0.0;
    final payments = await _db.getCustomerPayments(customer.id!);
    double total = 0.0;
    for (var payment in payments) {
      if (payment.amount < 0 && !payment.isDeleted) {
        total += payment.amount.abs();
      }
    }
    return total;
  }

  Future<void> _deleteCustomer(Customer customer) async {
    try {
      final db = await DatabaseService.getInstance();
      await db.deleteCustomer(customer.id!);

      if (!mounted) return;
      context.read<CustomersProvider>().removeCustomer(customer);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العميل بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف العميل: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }
}
