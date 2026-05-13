import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class DiaryFormScreen extends StatefulWidget {
  final DateTime date;
  const DiaryFormScreen({super.key, required this.date});

  @override
  State<DiaryFormScreen> createState() => _DiaryFormScreenState();
}

class _DiaryFormScreenState extends State<DiaryFormScreen> {
  final _db = DatabaseService();
  final _contentCtrl = TextEditingController();
  final _focusNode = FocusNode();

  Diary? _existing;
  String? _mood;
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;
  int _charCount = 0;

  static const _moods = ['😊', '😄', '😢', '😤', '😴', '🤗'];

  void _onTextChanged() {
    if (_loading) return; // 초기 로드 중엔 변경 감지 무시
    setState(() {
      _charCount = _contentCtrl.text.length;
      _hasChanges = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _contentCtrl.addListener(_onTextChanged);
    _loadDiary();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDiary() async {
    final diary = await _db.getDiaryByDateKey(Diary.keyFrom(widget.date));
    if (!mounted) return;
    // Set text outside setState to avoid nested setState via listener
    _contentCtrl.text = diary?.content ?? '';
    if (!mounted) return;
    setState(() {
      _existing = diary;
      _mood = diary?.mood;
      _charCount = _contentCtrl.text.length;
      _hasChanges = false;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('내용을 입력하세요.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      await _db.saveDiary(
        Diary(
          dateKey: Diary.keyFrom(widget.date),
          content: content,
          mood: _mood,
          createdAt: _existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
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
    if (_existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 날의 일기를 삭제할까요?'),
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
      await _db.deleteDiary(_existing!.dateKey);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 중 오류가 발생했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하지 않고 나가기'),
        content: const Text('작성 중인 내용이 저장되지 않아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('계속 작성')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('나가기')),
        ],
      ),
    );
    return result ?? false;
  }

  String _fmtDate(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}년 ${d.month}월 ${d.day}일 ${wd[d.weekday - 1]}요일';
  }

  String _fmtUpdated(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}'
      '.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')} 저장됨';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final leave = await _onWillPop();
        if (leave) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.diaryAccent,
          foregroundColor: AppTheme.textPrimary,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          titleTextStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          title: Column(children: [
            Text(_fmtDate(widget.date)),
            if (_existing != null)
              Text(_fmtUpdated(_existing!.updatedAt),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400)),
          ]),
          actions: [
            if (_existing != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 22),
                onPressed: _saving ? null : _delete,
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton(
                onPressed: (_loading || _saving) ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black26,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                // ── Mood selector ────────────────────────────────────────
                Container(
                  color: AppTheme.diaryAccentBg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _moods.map((emoji) {
                      final selected = _mood == emoji;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mood = selected ? null : emoji;
                          _hasChanges = true;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.diaryAccent
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(emoji,
                                style: TextStyle(
                                    fontSize: selected ? 24 : 22)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),

                // ── Writing area ─────────────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: Container(
                      color: AppTheme.surface,
                      child: Stack(children: [
                        CustomPaint(
                          painter: _RuledLinePainter(),
                          child: Container(),
                        ),
                        TextField(
                          controller: _contentCtrl,
                          focusNode: _focusNode,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 2.0,
                              color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText:
                                '오늘 하루는 어땠나요?\n느낀 점, 있었던 일을 자유롭게 기록해 보세요.',
                            hintStyle: TextStyle(
                                fontSize: 15,
                                height: 2.0,
                                color: AppTheme.textLight),
                            contentPadding:
                                EdgeInsets.fromLTRB(20, 20, 20, 20),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                // ── Status bar ───────────────────────────────────────────
                Container(
                  color: AppTheme.diaryAccentBg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.auto_stories_outlined,
                        size: 14, color: AppTheme.diaryAccent),
                    const SizedBox(width: 6),
                    Text(
                      _existing == null ? '새 일기' : '일기 수정 중',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Text('$_charCount자',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  ]),
                ),
              ]),
      ),
    );
  }
}

class _RuledLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 0.8;
    const lineHeight = 16.0 * 2.0;
    const topPadding = 20.0;
    double y = topPadding + lineHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
