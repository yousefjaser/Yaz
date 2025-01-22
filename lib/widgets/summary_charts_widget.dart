import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/services/database_service.dart';

class SummaryChartsWidget extends StatefulWidget {
  const SummaryChartsWidget({super.key});

  @override
  State<SummaryChartsWidget> createState() => _SummaryChartsWidgetState();
}

class _SummaryChartsWidgetState extends State<SummaryChartsWidget> {
  double totalDue = 0;
  double totalPaid = 0;
  late DatabaseService db;
  double _chartScale = 1.0;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    db = await DatabaseService.getInstance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final customersProvider = context.read<CustomersProvider>();
    final customers = customersProvider.customers;

    double newTotalDue = 0;
    double newTotalPaid = 0;

    for (var customer in customers) {
      final payments = await db.getCustomerPayments(customer.id!);

      for (var payment in payments) {
        if (payment.amount < 0) {
          // إذا كانت دين
          newTotalDue += payment.amount.abs();
        } else {
          // إذا كانت دفعة
          newTotalPaid += payment.amount;
        }
      }
    }

    if (mounted) {
      setState(() {
        totalDue = newTotalDue;
        totalPaid = newTotalPaid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification) {
                setState(() {
                  double scrollFactor =
                      1 - (scrollInfo.metrics.pixels / 300).clamp(0, 0.7);
                  _chartScale = scrollFactor;
                });
              }
              return true;
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 300 * _chartScale,
                    child: _buildChartCard(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScaleDialog(
                        totalPaid: totalPaid,
                        totalDue: totalDue,
                        paidDetails: '${totalPaid.toStringAsFixed(2)} ₪',
                        dueDetails: '${totalDue.toStringAsFixed(2)} ₪',
                      ),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(200, 200),
                      painter: SmoothDonutChartPainter(
                        paid: totalPaid,
                        due: totalDue,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'إجمالي المستحقات',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${totalDue.toStringAsFixed(0)} ₪',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(
                  color: Colors.red,
                  label: 'المبالغ المستحقة',
                  amount: totalDue,
                ),
                _LegendItem(
                  color: Colors.green,
                  label: 'المبالغ المدفوعة',
                  amount: totalPaid,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScaleDialog extends StatelessWidget {
  final double totalPaid;
  final double totalDue;
  final String paidDetails;
  final String dueDetails;

  const ScaleDialog({
    super.key,
    required this.totalPaid,
    required this.totalDue,
    required this.paidDetails,
    required this.dueDetails,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalPaid + totalDue;
    if (total <= 0) return const SizedBox.shrink();

    final paidPercentage = (totalPaid / total * 100).toStringAsFixed(1);
    final duePercentage = (totalDue / total * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل النسبة'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'chartHero',
                child: SizedBox(
                  height: 200,
                  width: 200,
                  child: CustomPaint(
                    painter: SmoothDonutChartPainter(
                      paid: totalPaid,
                      due: totalDue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailItem(
                'المبلغ المدفوع',
                paidDetails,
                paidPercentage,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDetailItem(
                'المبلغ المستحق',
                dueDetails,
                duePercentage,
                Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String title,
    String amount,
    String percentage,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class SmoothDonutChartPainter extends CustomPainter {
  final double paid;
  final double due;

  SmoothDonutChartPainter({required this.paid, required this.due});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..isAntiAlias = true; // لتنعيم الحواف

    final total = paid + due;
    if (total <= 0) return;

    final paidAngle = (paid / total) * 2 * pi;
    final dueAngle = (due / total) * 2 * pi;

    // رسم الجزء المدفوع
    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2),
      -pi / 2,
      paidAngle,
      false,
      paint,
    );

    // رسم الجزء المستحق
    paint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2),
      -pi / 2 + paidAngle,
      dueAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant SmoothDonutChartPainter oldDelegate) {
    return oldDelegate.paid != paid || oldDelegate.due != due;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: ${amount.toStringAsFixed(0)} ₪'),
      ],
    );
  }
}
