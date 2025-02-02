import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yaz/services/whatsapp_service.dart';
import 'package:yaz/models/payment.dart';
import 'package:yaz/models/customer.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_icon_snackbar/flutter_icon_snackbar.dart';
import 'package:yaz/services/reminder_service.dart';
import 'package:yaz/models/reminder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:yaz/providers/auth_provider.dart';

class ScheduledReminder {
  final String id;
  final DateTime scheduleDate;
  bool isSent;
  bool hasError;
  String? customMessage;

  ScheduledReminder({
    required this.id,
    required this.scheduleDate,
    this.isSent = false,
    this.hasError = false,
    this.customMessage,
  });
}

class PaymentDetailsScreen extends StatefulWidget {
  final Payment payment;
  final Customer customer;

  const PaymentDetailsScreen({
    Key? key,
    required this.payment,
    required this.customer,
  }) : super(key: key);

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  bool _isLoading = false;
  int _selectedMessageType = 0;
  final TextEditingController _customMessageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<ScheduledReminder> _scheduledReminders = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _reminderKey = 'reminders';
  Timer? _timer;

  final List<String> _variables = [
    'الاسم',
    'الهاتف',
    'المبلغ',
    'التاريخ',
    'النوع',
    'المدفوع',
    'الديون',
    'الرصيد',
    'التواصل',
    'الشركة',
  ];

  @override
  void initState() {
    super.initState();
    _loadScheduledReminders();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customMessageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendWhatsAppMessage() async {
    try {
      // التحقق من وجود نص للرسالة
      String message;
      if (_selectedMessageType == 4 && _customMessageController.text.isEmpty) {
        if (mounted) {
          showIconSnackBar(
            context: context,
            icon: Icons.error,
            color: Colors.red,
            label: 'الرجاء كتابة نص الرسالة أولاً',
          );
        }
        return;
      }

      message = _replaceVariables(_getMessageTemplate(_selectedMessageType));

      setState(() {
        _isLoading = true;
      });

      final whatsapp = WhatsAppService();
      final (success, error) = await whatsapp.sendMessage(
        phoneNumber: widget.customer.phone,
        message: message,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          showIconSnackBar(
            context: context,
            icon: Icons.check_circle,
            color: Colors.green,
            label: 'تم إرسال الرسالة بنجاح',
          );
        } else {
          showIconSnackBar(
            context: context,
            icon: Icons.error,
            color: Colors.red,
            label: error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        showIconSnackBar(
          context: context,
          icon: Icons.error,
          color: Colors.red,
          label: 'حدث خطأ في إرسال الرسالة',
        );
      }
    }
  }

  String _getMessageTemplate(int type) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userProfile = auth.userProfile;
    final businessName = userProfile?['business_name'] as String? ?? 'شركتنا';
    final contactPhone = userProfile?['phone'] as String? ?? '';

    switch (type) {
      case 0:
        return '''مرحبا @الاسم
نود إعلامك بموعد استحقاق دين بقيمة @المبلغ في @التاريخ
للتواصل: @التواصل
مع تحيات @الشركة
نشكر تعاونكم معنا''';
      case 1:
        return '''مرحبا @الاسم
هذا تذكير بموعد استحقاق دين بقيمة @المبلغ في @التاريخ
للتواصل: @التواصل
مع تحيات @الشركة
نشكر تعاونكم معنا''';
      case 2:
        return '''عزيزي @الاسم
نود إعلامكم بأنه تم استلام @النوع بقيمة @المبلغ في @التاريخ
للتواصل: @التواصل
مع تحيات @الشركة
شكراً لكم''';
      case 3:
        // ترتيب الدفعات حسب التاريخ من الأحدث للأقدم
        final sortedPayments = [...widget.customer.payments ?? []];
        sortedPayments.sort((a, b) => b.date.compareTo(a.date));

        // بناء قائمة الدفعات
        final paymentsDetails = sortedPayments.map((payment) {
          final type = payment.amount >= 0 ? 'دفعة' : 'دين';
          final amount = '${payment.amount.abs()} ₪';
          final date = _formatDate(payment.date);
          final note = payment.notes?.isNotEmpty == true ? ' - ${payment.notes}' : '';
          return '• $date: $type $amount$note';
        }).join('\n');

        return '''*كشف حساب*
العميل: @الاسم
رقم الهاتف: @الهاتف
تاريخ الكشف: @التاريخ
----------------
إجمالي المدفوع: @المدفوع ₪
إجمالي الديون: @الديون ₪
الرصيد الحالي: @الرصيد ₪
----------------
*سجل المعاملات:*
$paymentsDetails
----------------
للتواصل: @التواصل
مع تحيات @الشركة''';
      case 4: // تخصيص
        final text = _customMessageController.text;
        if (text.isEmpty) {
          return 'اكتب رسالتك هنا...\nالمتغيرات المتاحة:\n@الاسم - اسم العميل\n@الهاتف - رقم الهاتف\n@المبلغ - المبلغ\n@التاريخ - التاريخ\n@النوع - نوع المعاملة\n@المدفوع - إجمالي المدفوعات\n@الديون - إجمالي الديون\n@الرصيد - الرصيد الحالي\n@التواصل - رقم التواصل\n@الشركة - اسم الشركة';
        }
        return text;
      default:
        return '';
    }
  }

  String _replaceVariables(String text) {
    final amount = '${widget.payment.amount.abs()} ₪';
    final date = _formatDate(widget.payment.date);
    final paymentType = widget.payment.amount >= 0 ? 'دفعة' : 'دين';

    // حساب إجماليات كشف الحساب
    var totalPaid = 0.0;
    var totalDebt = 0.0;
    for (var payment in widget.customer.payments ?? []) {
      if (payment.amount > 0) {
        totalPaid += payment.amount;
      } else {
        totalDebt += payment.amount.abs();
      }
    }

    // الحصول على معلومات المستخدم
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userProfile = auth.userProfile;
    final businessName = userProfile?['business_name'] as String? ?? 'شركتنا';
    final contactPhone = userProfile?['phone'] as String? ?? '';

    return text
        .replaceAll('@الاسم', widget.customer.name)
        .replaceAll('@الهاتف', widget.customer.phone)
        .replaceAll('@المبلغ', amount)
        .replaceAll('@التاريخ', date)
        .replaceAll('@النوع', paymentType)
        .replaceAll('@المدفوع', totalPaid.toStringAsFixed(2))
        .replaceAll('@الديون', totalDebt.toStringAsFixed(2))
        .replaceAll('@الرصيد', widget.customer.balance.toStringAsFixed(2))
        .replaceAll('@التواصل', contactPhone)
        .replaceAll('@الشركة', businessName);
  }

  void showIconSnackBar({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showVariablesList(BuildContext context, TextEditingController controller) {
    final cursorPosition = controller.selection.baseOffset;
    final text = controller.text;
    final textBeforeCursor = text.substring(0, cursorPosition);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.minPositive,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'اختر متغير',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _variables.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final variable = _variables[index];
                    return ListTile(
                      dense: true,
                      title: Text('@$variable'),
                      subtitle: Text(_getVariableDescription(variable)),
                      onTap: () {
                        final newText = textBeforeCursor + variable + text.substring(cursorPosition);
                        controller.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                            offset: cursorPosition + variable.length,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVariableDescription(String variable) {
    switch (variable) {
      case 'الاسم':
        return widget.customer.name;
      case 'الهاتف':
        return widget.customer.phone;
      case 'المبلغ':
        return '${widget.payment.amount.abs()} ₪';
      case 'التاريخ':
        return _formatDate(widget.payment.date);
      case 'النوع':
        return widget.payment.amount >= 0 ? 'دفعة' : 'دين';
      case 'المدفوع':
        var total = 0.0;
        for (var p in widget.customer.payments ?? []) {
          if (p.amount > 0) total += p.amount;
        }
        return '$total ₪';
      case 'الديون':
        var total = 0.0;
        for (var p in widget.customer.payments ?? []) {
          if (p.amount < 0) total += p.amount.abs();
        }
        return '$total ₪';
      case 'الرصيد':
        return '${widget.customer.balance} ₪';
      case 'التواصل':
        final auth = Provider.of<AuthProvider>(context, listen: false);
        return auth.userProfile?['phone'] as String? ?? '';
      case 'الشركة':
        final auth = Provider.of<AuthProvider>(context, listen: false);
        return auth.userProfile?['business_name'] as String? ?? 'شركتنا';
      default:
        return '';
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadScheduledReminders();
    });
  }

  Widget _buildMessagePreview() {
    if (_customMessageController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Image.asset('assets/images/whatsapp.png', width: 22, height: 22,),
                const SizedBox(width: 8),
                Text(
                  'معاينة الرسالة',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: (0.3 * 255).round().toDouble()),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text(
              _replaceVariables(_customMessageController.text),
              style: const TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  void _startUpdateTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // تحديث الواجهة فقط
        });
      }
    });
  }

  Future<void> _loadScheduledReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson =
          prefs.getStringList('${_reminderKey}_${widget.payment.id}') ?? [];
      setState(() {
        _scheduledReminders = remindersJson.map((json) {
          final parts = json.split(':');
          final scheduleDate =
              DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]));
          final isSent = parts.length > 1 ? parts[1] == '1' : false;
          final hasError = parts.length > 2 ? parts[2] == '1' : false;
          final customMessage = parts.length > 3 ? parts[3] : null;

          return ScheduledReminder(
            id: parts[0],
            scheduleDate: scheduleDate,
            isSent: isSent,
            hasError: hasError,
            customMessage: customMessage,
          );
        }).toList();
        _scheduledReminders
            .sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
      });
    } catch (e) {
      debugPrint('خطأ في تحميل التذكيرات: $e');
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = _scheduledReminders.map((reminder) {
        return '${reminder.scheduleDate.millisecondsSinceEpoch}:'
            '${reminder.isSent ? '1' : '0'}:'
            '${reminder.hasError ? '1' : '0'}:'
            '${reminder.customMessage ?? ''}';
      }).toList();
      await prefs.setStringList(
          '${_reminderKey}_${widget.payment.id}', remindersJson);
    } catch (e) {
      debugPrint('خطأ في حفظ التذكيرات: $e');
    }
  }

  Future<void> _scheduleReminder(DateTime scheduleDate) async {
    try {
      if (widget.customer.id == null) {
        throw Exception('معرف العميل غير موجود');
      }

      // إنشاء كائن التذكير
      final reminder = Reminder(
        customerId: widget.customer.id!,
        reminderDate: scheduleDate,
        message: _selectedMessageType == 4
            ? _customMessageController.text
            : _getMessageTemplate(_selectedMessageType),
      );

      // حفظ التذكير في Supabase
      final reminderService = await ReminderService.getInstance();
      await reminderService.createReminder(reminder);

      // إضافة التذكير إلى القائمة المحلية
      setState(() {
        _scheduledReminders.add(ScheduledReminder(
          id: reminder.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          scheduleDate: scheduleDate,
          isSent: false,
          hasError: false,
          customMessage:
              _selectedMessageType == 4 ? _customMessageController.text : null,
        ));
        _scheduledReminders
            .sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
      });

      await _saveReminders();

      if (mounted) {
        showIconSnackBar(
          context: context,
          icon: Icons.check,
          color: Colors.green,
          label: 'تمت جدولة التذكير بنجاح',
        );
      }
    } catch (e) {
      debugPrint('خطأ في جدولة التذكير: $e');
      if (mounted) {
        showIconSnackBar(
          context: context,
          icon: Icons.error,
          color: Colors.red,
          label: 'حدث خطأ في جدولة التذكير',
        );
      }
    }
  }

  Future<void> _deleteReminder(int index) async {
    try {
      final reminder = _scheduledReminders[index];

      // حذف التذكير من Supabase
      final reminderService = await ReminderService.getInstance();
      await reminderService.deleteReminder(reminder.id);

      setState(() {
        _scheduledReminders.removeAt(index);
      });

      await _saveReminders();

      if (mounted) {
        showIconSnackBar(
          context: context,
          icon: Icons.check,
          color: Colors.green,
          label: 'تم حذف التذكير بنجاح',
        );
      }
    } catch (e) {
      debugPrint('خطأ في حذف التذكير: $e');
      if (mounted) {
        showIconSnackBar(
          context: context,
          icon: Icons.error,
          color: Colors.red,
          label: 'حدث خطأ: $e',
        );
      }
    }
  }

  String _getRemainingTimeText(Duration difference) {
    if (difference.isNegative) {
      return 'جارٍ الإرسال...';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (days > 0) {
      return 'متبقي $days يوم ${hours > 0 ? 'و $hours ساعة' : ''}';
    } else if (hours > 0) {
      return 'متبقي $hours ساعة ${minutes > 0 ? 'و $minutes دقيقة' : ''}';
    } else if (minutes > 0) {
      return 'متبقي $minutes دقيقة ${seconds > 0 ? 'و $seconds ثانية' : ''}';
    } else {
      return 'متبقي $seconds ثانية';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('تفاصيل الدفعة'),
              if (!widget.payment.isSynced) ...[
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
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          CircleAvatar(
                            radius: 40,
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            child: Text(
                              widget.customer.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.customer.name,
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.customer.phone,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'معلومات الدفعة',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${widget.payment.amount.abs()} ₪',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: widget.payment.amount > 0
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    child: Icon(
                                      widget.payment.amount > 0
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: widget.payment.amount > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  if (!widget.payment.isSynced)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                              title: Text(
                                widget.payment.title ??
                                    (widget.payment.amount > 0
                                        ? 'دفعة'
                                        : 'دين'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'التاريخ: ${_formatDateTime(widget.payment.date)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (!widget.payment.isSynced)
                                    const Text(
                                      'في انتظار المزامنة مع السيرفر',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                '${widget.payment.amount.abs().toStringAsFixed(2)} ₪',
                                style: TextStyle(
                                  color: widget.payment.amount > 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.payment.notes?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'ملاحظات:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    widget.payment.notes!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                            if (widget.payment.reminderDate != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.alarm),
                                  title: const Text('موعد التذكير'),
                                  subtitle: Text(_formatDateTime(
                                      widget.payment.reminderDate!)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'اختر نموذج الرسالة',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.message_rounded,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _sendWhatsAppMessage,
                                      icon: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.send),
                                      label: Text(_isLoading ? 'جاري الإرسال...' : 'إرسال'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (int i = 0; i < 4; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedMessageType = i;
                                            });
                                          },
                                          child: Container(
                                            width: 200,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: _selectedMessageType == i
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer
                                                  : Theme.of(context).colorScheme.surface,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _selectedMessageType == i
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .outline
                                                        .withOpacity(0.2),
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'نموذج ${i + 1}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: _selectedMessageType == i
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                Expanded(
                                                  child: Text(
                                                    _getMessageTemplate(i),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withOpacity(0.8),
                                                        ),
                                                    maxLines: 6,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    // مربع الرسالة المخصصة
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedMessageType = 4;
                                          });
                                        },
                                        child: Container(
                                          width: 140,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _selectedMessageType == 4
                                                ? Theme.of(context).colorScheme.primaryContainer
                                                : Theme.of(context).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedMessageType == 4
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.edit_note_rounded,
                                                size: 32,
                                                color: _selectedMessageType == 4
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'تخصيص',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: _selectedMessageType == 4
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_selectedMessageType == 4) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _customMessageController,
                                focusNode: _focusNode,
                                maxLines: 4,
                                textDirection: TextDirection.rtl,
                                onChanged: (value) {
                                  setState(() {});
                                  if (value.endsWith('@')) {
                                    _showVariablesList(context, _customMessageController);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'اكتب رسالتك هنا...',
                                  helperText: 'اكتب @ لإظهار قائمة المتغيرات المتاحة',
                                  helperMaxLines: 2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[850]
                                      : Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withValues(alpha: (0.5 * 255).round().toDouble()),
                                ),
                              ),
                              _buildMessagePreview(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'التذكيرات المجدولة',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          FloatingActionButton(
                            heroTag: 'add_reminder',
                            mini: true,
                            child: const Icon(Icons.add),
                            onPressed: () async {
                              final now = DateTime.now();
                              final lastDate = now.add(
                                  const Duration(days: 365)); // سنة من اليوم
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: now,
                                firstDate: now,
                                lastDate: lastDate,
                              );
                              if (pickedDate != null) {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (pickedTime != null && mounted) {
                                  final scheduleDate = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                  await _scheduleReminder(scheduleDate);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reminder = _scheduledReminders[index];
                        final now = DateTime.now();
                        final difference =
                            reminder.scheduleDate.difference(now);
                        String remainingTime = '';

                        if (!reminder.isSent) {
                          remainingTime = _getRemainingTimeText(difference);
                        }

                        return Dismissible(
                          key: Key('reminder_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteReminder(index),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: reminder.isSent
                                    ? (reminder.hasError
                                        ? Colors.orange
                                        : Colors.green)
                                    : Colors.grey,
                                child: Icon(
                                  reminder.isSent
                                      ? (reminder.hasError
                                          ? Icons.error
                                          : Icons.check)
                                      : Icons.alarm,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                _formatDateTime(reminder.scheduleDate),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                reminder.isSent
                                    ? (reminder.hasError
                                        ? 'فشل في الإرسال'
                                        : 'تم الإرسال')
                                    : remainingTime,
                                style: TextStyle(
                                  color: reminder.isSent
                                      ? (reminder.hasError
                                          ? Colors.orange
                                          : Colors.green)
                                      : Colors.grey,
                                ),
                              ),
                              trailing: !reminder.isSent
                                  ? IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteReminder(index),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                      childCount: _scheduledReminders.length,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('yyyy/MM/dd', 'ar');
    return formatter.format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('yyyy/MM/dd HH:mm', 'ar');
    return formatter.format(dateTime);
  }
}
