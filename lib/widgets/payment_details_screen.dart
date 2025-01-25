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
  final WhatsAppService _whatsAppService = WhatsAppService();
  List<ScheduledReminder> _scheduledReminders = [];
  Timer? _timer;
  Timer? _updateTimer;
  bool _isLoading = false;
  final _reminderKey = 'reminders';
  final TextEditingController _customMessageController =
      TextEditingController();
  int _selectedMessageType = 0;
  final FocusNode _focusNode = FocusNode();

  final List<String> _variables = [
    'الاسم',
    'الرقم',
    'المبلغ',
    'التاريخ',
    'النوع',
  ];

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

  @override
  void initState() {
    super.initState();
    _loadScheduledReminders();
    _startTimer();
    _startUpdateTimer();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // _removeOverlay();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _updateTimer?.cancel();
    _customMessageController.dispose();
    _focusNode.dispose();
    // _removeOverlay();
    super.dispose();
  }

  void _showVariablesList(
      BuildContext context, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _variables.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final variable = _variables[index];
              return ListTile(
                dense: true,
                onTap: () {
                  final text = controller.text;
                  final selection = controller.selection;
                  final beforeCursor = text.substring(0, selection.baseOffset);
                  final afterCursor = text.substring(selection.baseOffset);
                  final lastAtIndex = beforeCursor.lastIndexOf('@');
                  if (lastAtIndex != -1) {
                    final newText = beforeCursor.substring(0, lastAtIndex) +
                        '@$variable' +
                        afterCursor;
                    controller.text = newText;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: lastAtIndex + variable.length + 1),
                    );
                  }
                  Navigator.of(context).pop();
                },
                title: Text(
                  '@$variable',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                subtitle: Text(
                  _getVariableDescription(variable),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getVariableDescription(String variable) {
    switch (variable) {
      case 'الاسم':
        return 'اسم العميل';
      case 'الرقم':
        return 'رقم هاتف العميل';
      case 'المبلغ':
        return 'قيمة المبلغ مع العملة';
      case 'التاريخ':
        return 'تاريخ الاستحقاق';
      case 'النوع':
        return 'نوع المعاملة (دفعة/دين)';
      default:
        return '';
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      bool needsSave = false;
      for (int i = 0; i < _scheduledReminders.length; i++) {
        var reminder = _scheduledReminders[i];
        if (!reminder.isSent &&
            reminder.scheduleDate.isBefore(DateTime.now())) {
          try {
            final success = await _whatsAppService.schedulePaymentReminder(
              phoneNumber: widget.customer.phone,
              customerName: widget.customer.name,
              amount: widget.payment.amount,
              dueDate: widget.payment.date,
              scheduleDate: reminder.scheduleDate,
              customMessage: reminder.customMessage,
            );

            if (success) {
              // تحديث حالة التذكير في Supabase
              final reminderService = ReminderService(Supabase.instance.client);
              await reminderService.markReminderAsCompleted(reminder.id);
            }

            if (mounted) {
              setState(() {
                _scheduledReminders[i] = ScheduledReminder(
                  id: reminder.id,
                  scheduleDate: reminder.scheduleDate,
                  isSent: true,
                  hasError: !success,
                  customMessage: reminder.customMessage,
                );
              });
              needsSave = true;

              showIconSnackBar(
                context: context,
                icon: success ? Icons.check : Icons.error,
                color: success ? Colors.green : Colors.red,
                label:
                    success ? 'تم إرسال التذكير بنجاح' : 'فشل في إرسال التذكير',
              );
            }
          } catch (e) {
            debugPrint('خطأ في إرسال التذكير: $e');
            if (mounted) {
              setState(() {
                _scheduledReminders[i] = ScheduledReminder(
                  id: reminder.id,
                  scheduleDate: reminder.scheduleDate,
                  isSent: true,
                  hasError: true,
                  customMessage: reminder.customMessage,
                );
              });
              needsSave = true;
            }
          }
        }
      }

      if (needsSave) {
        await _saveReminders();
      }
    });
  }

  void _startUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
        message: _selectedMessageType == 3
            ? _customMessageController.text
            : _getMessageTemplate(_selectedMessageType),
      );

      // حفظ التذكير في Supabase
      final reminderService = ReminderService(Supabase.instance.client);
      await reminderService.createReminder(reminder);

      // إضافة التذكير إلى القائمة المحلية
      setState(() {
        _scheduledReminders.add(ScheduledReminder(
          id: reminder.id,
          scheduleDate: scheduleDate,
          isSent: false,
          hasError: false,
          customMessage:
              _selectedMessageType == 3 ? _customMessageController.text : null,
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
      final reminderService = ReminderService(Supabase.instance.client);
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

  String _replaceVariables(String text) {
    final amount = '${widget.payment.amount.abs()} ₪';
    final date = _formatDate(widget.payment.date);
    final paymentType = widget.payment.amount >= 0 ? 'دفعة' : 'دين';

    return text
        .replaceAll('@الاسم', widget.customer.name)
        .replaceAll('@الرقم', widget.customer.phone)
        .replaceAll('@المبلغ', amount)
        .replaceAll('@التاريخ', date)
        .replaceAll('@النوع', paymentType);
  }

  String _getMessageTemplate(int type) {
    final amount = '${widget.payment.amount.abs()} ₪';
    final date = _formatDate(widget.payment.date);
    final paymentType = widget.payment.amount >= 0 ? 'دفعة' : 'دين';

    switch (type) {
      case 0:
        return 'السلام عليكم ${widget.customer.name}،\nنود تذكيركم بموعد استحقاق $paymentType بقيمة $amount في تاريخ $date\nشكراً لتعاونكم';
      case 1:
        return 'مرحباً ${widget.customer.name}،\nهذا تذكير بموعد استحقاق $paymentType بمبلغ $amount في $date\nنقدر تعاونكم معنا';
      case 2:
        return 'عزيزي ${widget.customer.name}،\nنود إعلامكم باستحقاق $paymentType بقيمة $amount في تاريخ $date\nشكراً لكم';
      case 3:
        final text = _customMessageController.text;
        if (text.isEmpty) {
          return 'اكتب رسالتك هنا...\nالمتغيرات المتاحة:\n@الاسم - اسم العميل\n@الرقم - رقم العميل\n@المبلغ - المبلغ\n@التاريخ - التاريخ\n@النوع - نوع المعاملة';
        }
        return _replaceVariables(text);
      default:
        return '';
    }
  }

  Widget _buildMessagePreview() {
    return Card(
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
                Icon(
                  Icons.message_rounded,
                  color: Theme.of(context).colorScheme.secondary,
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
                    for (int i = 0; i < 3; i++)
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
                            _selectedMessageType = 3;
                          });
                        },
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedMessageType == 3
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedMessageType == 3
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
                                color: _selectedMessageType == 3
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
                                      color: _selectedMessageType == 3
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
            if (_selectedMessageType == 3) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customMessageController,
                focusNode: _focusNode,
                maxLines: 4,
                onChanged: (value) {
                  setState(() {});
                  if (value.endsWith('@')) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showVariablesList(context, _customMessageController);
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'اكتب رسالتك المخصصة هنا...\nمثال: مرحباً @الاسم لديك @النوع بقيمة @المبلغ',
                  helperText: 'اكتب @ لإظهار قائمة المتغيرات المتاحة',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              if (_customMessageController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'معاينة الرسالة:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_replaceVariables(_customMessageController.text)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدفعة'),
          elevation: 0,
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
                              leading: CircleAvatar(
                                backgroundColor: widget.payment.amount >= 0
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                child: Icon(
                                  widget.payment.amount >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: widget.payment.amount >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              title: Text(
                                'نوع المعاملة',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                widget.payment.amount >= 0 ? 'دفعة' : 'دين',
                                style: TextStyle(
                                  color: widget.payment.amount >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.calendar_today,
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              title: Text(
                                'تاريخ الاستحقاق',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                _formatDate(widget.payment.date),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ),
                            if (widget.payment.notes != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.note,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                                title: Text(
                                  'ملاحظات',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  widget.payment.notes!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildMessagePreview(),
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
