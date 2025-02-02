import 'package:flutter/material.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/services/database_service.dart';
import 'package:intl/intl.dart' as intl;

class TrashScreen extends StatefulWidget {
  const TrashScreen({Key? key}) : super(key: key);

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late DatabaseService _db;
  List<Customer> _deletedCustomers = [];
  List<Payment> _deletedPayments = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      _db = await DatabaseService.getInstance();
      await _loadDeletedItems();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDeletedItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final customers = await _db.getCustomers();
      final allPayments = await _db.getAllPayments();

      if (!mounted) return;

      setState(() {
        _deletedCustomers = customers.where((c) => c.isDeleted).toList();
        _deletedPayments = allPayments.where((p) => p.isDeleted).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreCustomer(Customer customer) async {
    try {
      customer.isDeleted = false;
      customer.deletedAt = null;
      await _db.updateCustomer(customer);

      if (!mounted) return;

      setState(() {
        _deletedCustomers.remove(customer);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استعادة العميل بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في استعادة العميل: $e')),
      );
    }
  }

  Future<void> _restorePayment(Payment payment) async {
    try {
      payment.isDeleted = false;
      payment.deletedAt = null;
      await _db.updatePayment(payment);

      if (!mounted) return;

      setState(() {
        _deletedPayments.remove(payment);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استعادة الدفعة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في استعادة الدفعة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('سلة المحذوفات'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'العملاء'),
                Tab(text: 'الدفعات'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(child: Text('خطأ: $_error'))
                  : TabBarView(
                      children: [
                        _buildCustomersList(),
                        _buildPaymentsList(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildCustomersList() {
    if (_deletedCustomers.isEmpty) {
      return const Center(child: Text('لا يوجد عملاء محذوفين'));
    }

    return ListView.builder(
      itemCount: _deletedCustomers.length,
      itemBuilder: (context, index) {
        final customer = _deletedCustomers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Color(int.parse(customer.color.replaceAll('#', '0xFF'))),
            child: Text(
              customer.name.characters.first,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(customer.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.phone),
              Text(
                'الرصيد: ${customer.balance.toStringAsFixed(2)} ₪',
                style: TextStyle(
                  color: customer.balance < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _restoreCustomer(customer),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsList() {
    if (_deletedPayments.isEmpty) {
      return const Center(child: Text('لا يوجد دفعات محذوفة'));
    }

    return ListView.builder(
      itemCount: _deletedPayments.length,
      itemBuilder: (context, index) {
        final payment = _deletedPayments[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: payment.amount < 0 ? Colors.red : Colors.green,
            child: Icon(
              payment.amount < 0 ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.white,
            ),
          ),
          title: Text('${payment.amount.abs().toStringAsFixed(2)} ₪'),
          subtitle: Text(intl.DateFormat('yyyy/MM/dd').format(payment.date)),
          trailing: IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () => _restorePayment(payment),
          ),
        );
      },
    );
  }
}
