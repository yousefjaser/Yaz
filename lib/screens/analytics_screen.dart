import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:yaz/providers/customers_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحليل البيانات'),
        ),
        body: Consumer<CustomersProvider>(
          builder: (context, provider, _) {
            final customers = provider.customers;

            if (customers.isEmpty) {
              return const Center(child: Text('لا توجد بيانات للتحليل'));
            }

            // حساب إجمالي الديون والمدفوعات
            double totalDebt = 0;
            double totalPaid = 0;
            for (var customer in customers) {
              if (customer.balance < 0) {
                totalDebt += customer.balance.abs();
              } else {
                totalPaid += customer.balance;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'نسبة الديون والمدفوعات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: totalDebt,
                                    title: 'الديون',
                                    color: Colors.red,
                                    radius: 100,
                                  ),
                                  PieChartSectionData(
                                    value: totalPaid,
                                    title: 'المدفوعات',
                                    color: Colors.green,
                                    radius: 100,
                                  ),
                                ],
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'إحصائيات العملاء',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStatisticRow(
                              'عدد العملاء', '${customers.length}'),
                          _buildStatisticRow(
                            'إجمالي الديون',
                            '${totalDebt.toStringAsFixed(2)} ₪',
                          ),
                          _buildStatisticRow(
                            'إجمالي المدفوعات',
                            '${totalPaid.toStringAsFixed(2)} ₪',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatisticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
