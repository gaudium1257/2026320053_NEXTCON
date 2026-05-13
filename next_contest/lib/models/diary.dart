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

  static String keyFrom(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
    return Diary(
      dateKey: map['dateKey'] as String,
      content: map['content'] as String,
      mood: map['mood'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
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
