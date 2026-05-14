import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event;
  final DateTime? initialDate;
  final DateTime? initialEndDate;

  const EventFormScreen({super.key, this.event, this.initialDate, this.initialEndDate});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _memoCtrl;

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isAllDay = false;
  bool _isRecurring = false;
  String _recurrenceType = 'weekly';
  DateTime? _recurrenceEndDate;
  int _colorValue = 0xFF3D5AFE;
  bool _saving = false;

  static const _palette = [
    0xFF3D5AFE, 0xFFE53935, 0xFFE91E8C, 0xFF9C27B0,
    0xFF00ACC1, 0xFF009688, 0xFF43A047, 0xFFFB8C00,
    0xFF6D4C41, 0xFF546E7A,
  ];

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final today = widget.initialDate ?? DateTime.now();
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _memoCtrl = TextEditingController(text: e?.memo ?? '');
    _startDate = e?.startDate ?? today;
    _endDate = e?.endDate ?? widget.initialEndDate ?? today;
    _startTime = e?.startTime;
    _endTime = e?.endTime;
    _isAllDay = e?.isAllDay ?? true;
    _isRecurring = e?.isRecurring ?? false;
    _recurrenceType = e?.recurrenceType ?? 'weekly';
    _recurrenceEndDate = e?.recurrenceEndDate;
    _colorValue = e?.colorValue ?? 0xFF3D5AFE;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _recurrenceEndDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _recurrenceEndDate = picked);
  }

  // ── Save / Delete ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // 종료일이 시작일보다 이른 경우 방어
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료일이 시작일보다 빠를 수 없어요.')),
      );
      return;
    }
    setState(() => _saving = true);

    final event = Event(
      id: widget.event?.id,
      title: _titleCtrl.text.trim(),
      startDate: _startDate,
      startTimeMinutes: _isAllDay
          ? null
          : _startTime != null
              ? _startTime!.hour * 60 + _startTime!.minute
              : null,
      endDate: _endDate,
      endTimeMinutes: _isAllDay
          ? null
          : _endTime != null
              ? _endTime!.hour * 60 + _endTime!.minute
              : null,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      isAllDay: _isAllDay,
      isRecurring: _isRecurring,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceEndDate: _isRecurring ? _recurrenceEndDate : null,
      colorValue: _colorValue,
    );

    try {
      if (_isEdit) {
        await _db.updateEvent(event);
      } else {
        await _db.addEvent(event);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _db.deleteEvent(widget.event!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 중 오류가 발생했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay? t) => t == null
      ? '시간 선택'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '일정 수정' : '일정 추가'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.errorRed),
              onPressed: _saving ? null : _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0x667C5CFC),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('저장',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: '일정 이름',
                  hintStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textLight),
                  border: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppTheme.divider, width: 1.5)),
                  enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppTheme.divider, width: 1.5)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppTheme.primary, width: 2)),
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? '제목을 입력하세요'
                    : null,
                textInputAction: TextInputAction.next,
              ),
            ),

            const SizedBox(height: 12),

            // ── Color picker ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                children: _palette.map((c) {
                  final selected = _colorValue == c;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: selected ? 30 : 26,
                      height: selected ? 30 : 26,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Color(c), width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(
                                color: Color(c).withValues(alpha: 0.5),
                                blurRadius: 6, spreadRadius: 1)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // ── Date & Time ────────────────────────────────────────────────
            _SectionHeader(icon: Icons.schedule_rounded, label: '날짜 · 시간'),
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20),
              dense: true,
              title: const Text('종일',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
              value: _isAllDay,
              onChanged: (v) {
                setState(() {
                  _isAllDay = v;
                  if (!v) {
                    _startTime ??= const TimeOfDay(hour: 9, minute: 0);
                    _endTime ??= const TimeOfDay(hour: 10, minute: 0);
                  }
                });
              },
            ),
            _DateTimeRow(
              label: '시작',
              date: _startDate,
              time: _isAllDay ? null : _startTime,
              showTime: !_isAllDay,
              fmtDate: _fmtDate,
              fmtTime: _fmtTime,
              onDateTap: () => _pickDate(isStart: true),
              onTimeTap: () => _pickTime(isStart: true),
            ),
            const SizedBox(height: 4),
            _DateTimeRow(
              label: '종료',
              date: _endDate,
              time: _isAllDay ? null : _endTime,
              showTime: !_isAllDay,
              fmtDate: _fmtDate,
              fmtTime: _fmtTime,
              onDateTap: () => _pickDate(isStart: false),
              onTimeTap: () => _pickTime(isStart: false),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // ── Recurrence ─────────────────────────────────────────────────
            _SectionHeader(icon: Icons.repeat_rounded, label: '반복'),
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20),
              dense: true,
              title: const Text('반복 일정',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            if (_isRecurring) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonFormField<String>(
                  initialValue: _recurrenceType,
                  decoration:
                      const InputDecoration(labelText: '반복 주기'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('매일')),
                    DropdownMenuItem(
                        value: 'weekly', child: Text('매주')),
                    DropdownMenuItem(
                        value: 'monthly', child: Text('매달')),
                    DropdownMenuItem(
                        value: 'yearly', child: Text('매년')),
                  ],
                  onChanged: (v) =>
                      setState(() => _recurrenceType = v!),
                ),
              ),
              const SizedBox(height: 10),
              _IconRow(
                icon: Icons.event_repeat_rounded,
                onTap: _pickRecurrenceEndDate,
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _recurrenceEndDate == null
                          ? '종료일 없음'
                          : '종료: ${_fmtDate(_recurrenceEndDate!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _recurrenceEndDate == null
                            ? AppTheme.textLight
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (_recurrenceEndDate != null)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _recurrenceEndDate = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textLight),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
            const Divider(height: 1),

            // ── Memo ───────────────────────────────────────────────────────
            _SectionHeader(icon: Icons.notes_rounded, label: '메모'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextFormField(
                controller: _memoCtrl,
                decoration: const InputDecoration(
                  hintText: '추가 메모 (선택)',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.6),
                minLines: 5,
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
        ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4)),
      ]),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Widget child;
  const _IconRow(
      {required this.icon, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final TimeOfDay? time;
  final bool showTime;
  final String Function(DateTime) fmtDate;
  final String Function(TimeOfDay?) fmtTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const _DateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.showTime,
    required this.fmtDate,
    required this.fmtTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
        InkWell(
          onTap: onDateTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 5),
              Text(fmtDate(date),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ]),
          ),
        ),
        if (showTime) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onTimeTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(children: [
                const Icon(Icons.access_time_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 5),
                Text(
                  fmtTime(time),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: time != null
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: time != null
                        ? AppTheme.textPrimary
                        : AppTheme.textLight,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
