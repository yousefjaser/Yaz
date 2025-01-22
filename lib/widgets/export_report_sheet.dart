import 'package:flutter/material.dart';
import 'package:yaz/models/customer.dart';
import 'package:yaz/services/report_service.dart';

class ExportReportSheet extends StatefulWidget {
  final Customer customer;

  const ExportReportSheet({
    super.key,
    required this.customer,
  });

  @override
  State<ExportReportSheet> createState() => _ExportReportSheetState();
}

class _ExportReportSheetState extends State<ExportReportSheet> {
  final _reportService = ReportService();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'pdf';
  bool _isLoading = false;

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _exportReport() async {
    try {
      setState(() => _isLoading = true);

      final filePath = await _reportService.generateCustomerReport(
        customer: widget.customer,
        startDate: _startDate,
        endDate: _endDate,
        format: _selectedFormat,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تم تصدير التقرير بنجاح',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'تم حفظ الملف في مجلد التطبيق/Reports',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'يمكنك مشاركة الملف من خلال نافذة المشاركة',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'حسناً',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'حدث خطأ في تصدير التقرير',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تصدير كشف حساب',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('من تاريخ'),
                  subtitle: Text(_startDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _selectStartDate,
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('إلى تاريخ'),
                  subtitle: Text(_endDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: RadioListTile(
                  title: const Text('PDF'),
                  value: 'pdf',
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile(
                  title: const Text('Excel'),
                  value: 'excel',
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            ElevatedButton(
              onPressed: _exportReport,
              child: const Text('تصدير التقرير'),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
