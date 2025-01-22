import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:intl/intl.dart' as intl;

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final Set<int> _selectedCustomers = {};
  final Set<int> _selectedPayments = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomersProvider>().loadDeletedPayments();
    });
  }

  Future<void> _confirmPermanentDelete(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف النهائي'),
        content: const Text('هل أنت متأكد من حذف العناصر المحددة نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => navigator.pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = Provider.of<CustomersProvider>(context, listen: false);
        if (_selectedCustomers.isNotEmpty) {
          await provider
              .permanentlyDeleteCustomers(_selectedCustomers.toList());
        }
        if (_selectedPayments.isNotEmpty) {
          await provider.permanentlyDeletePayments(_selectedPayments.toList());
        }
        if (!mounted) return;
        setState(() {
          _selectedCustomers.clear();
          _selectedPayments.clear();
        });
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('تم الحذف النهائي بنجاح')),
        );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('خطأ في الحذف النهائي: $e')),
        );
      }
    }
  }

  Widget _buildDeletedCustomers() {
    return Consumer<CustomersProvider>(
      builder: (context, provider, _) {
        final deletedCustomers = provider.deletedCustomers;

        return Column(
          children: [
            if (deletedCustomers.isNotEmpty)
              CheckboxListTile(
                title: const Text('تحديد الكل'),
                value: _selectedCustomers.length == deletedCustomers.length,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedCustomers.addAll(
                        deletedCustomers.map((c) => c.id!),
                      );
                    } else {
                      _selectedCustomers.clear();
                    }
                  });
                },
              ),
            Expanded(
              child: ListView.builder(
                itemCount: deletedCustomers.length,
                itemBuilder: (context, index) {
                  final customer = deletedCustomers[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: CheckboxListTile(
                      value: _selectedCustomers.contains(customer.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedCustomers.add(customer.id!);
                          } else {
                            _selectedCustomers.remove(customer.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: customer.balance < 0
                                ? Colors.red
                                : Colors.green,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'الرصيد: ${customer.balance.abs().toStringAsFixed(2)} ₪',
                                  style: TextStyle(
                                    color: customer.balance < 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(customer.phone),
                      secondary: IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () {
                          provider.restoreCustomer(customer);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم استعادة العميل')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeletedPayments() {
    return Consumer<CustomersProvider>(
      builder: (context, provider, _) {
        final deletedPayments = provider.deletedPayments;

        return Column(
          children: [
            if (deletedPayments.isNotEmpty)
              CheckboxListTile(
                title: const Text('تحديد الكل'),
                value: _selectedPayments.length == deletedPayments.length,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedPayments.addAll(
                        deletedPayments.map((p) => p.id!),
                      );
                    } else {
                      _selectedPayments.clear();
                    }
                  });
                },
              ),
            Expanded(
              child: ListView.builder(
                itemCount: deletedPayments.length,
                itemBuilder: (context, index) {
                  final payment = deletedPayments[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: CheckboxListTile(
                      value: _selectedPayments.contains(payment.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedPayments.add(payment.id!);
                          } else {
                            _selectedPayments.remove(payment.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                payment.amount < 0 ? Colors.red : Colors.green,
                            child: Icon(
                              payment.amount < 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.customerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${payment.amount.abs().toStringAsFixed(2)} ₪',
                                  style: TextStyle(
                                    color: payment.amount < 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        intl.DateFormat('yyyy/MM/dd').format(payment.date),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          provider.restorePayment(payment).then((_) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('تم استعادة الدفعة')),
                            );
                          }).catchError((e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text('خطأ في استعادة الدفعة: $e')),
                            );
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة المحذوفات'),
          actions: [
            if (_selectedCustomers.isNotEmpty || _selectedPayments.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: () => _confirmPermanentDelete(context),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'العملاء'),
              Tab(text: 'الدفعات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDeletedCustomers(),
            _buildDeletedPayments(),
          ],
        ),
      ),
    );
  }
}
