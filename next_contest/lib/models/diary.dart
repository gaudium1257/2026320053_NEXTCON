import '../utils/date_utils.dart';

class Diary {
  final String dateKey; // 'yyyy-MM-dd' — PK
  final String content;
  final String? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Diary({
    required this.dateKey,
    required this.content,
    this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns 'yyyy-MM-dd' key for [date] — delegates to the shared utility.
  static String keyFrom(DateTime date) => dayKey(date);

  static DateTime dateFromKey(String key) => DateTime.parse(key);

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'content': content,
        'mood': mood,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Diary.fromMap(Map<String, dynamic> map) {
    try {
      final dateKey = map['dateKey'] as String?;
      final content = map['content'] as String?;
      final createdAtStr = map['createdAt'] as String?;
      final updatedAtStr = map['updatedAt'] as String?;

      if (dateKey == null || dateKey.isEmpty) {
        throw FormatException('Diary dateKey cannot be null or empty');
      }
      if (content == null || content.trim().isEmpty) {
        throw FormatException('Diary content cannot be null or empty');
      }
      if (createdAtStr == null || updatedAtStr == null) {
        throw FormatException('Diary timestamps cannot be null');
      }

      // 날짜 키 형식 검증 (yyyy-MM-dd)
      final dateKeyRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!dateKeyRegex.hasMatch(dateKey)) {
        throw FormatException('Invalid dateKey format: $dateKey');
      }

      final createdAt = DateTime.parse(createdAtStr);
      final updatedAt = DateTime.parse(updatedAtStr);

      return Diary(
        dateKey: dateKey,
        content: content.trim(),
        mood: map['mood'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      throw FormatException('Invalid diary data: $e');
    }
  }

  Diary copyWith({String? content, String? mood, DateTime? updatedAt}) {
    return Diary(
      dateKey: dateKey,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
