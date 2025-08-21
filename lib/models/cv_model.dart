import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single CV section
class CVSection {
  String text;
  bool isLoading;

  CVSection({
    required this.text,
    this.isLoading = false,
  });

  CVSection.fromMap(Map<String, dynamic> map)
      : text = map['text'] ?? '',
        isLoading = map['isLoading'] ?? false;

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isLoading': isLoading,
    };
  }

  CVSection copyWith({
    String? text,
    bool? isLoading,
  }) {
    return CVSection(
      text: text ?? this.text,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Helper: split text into a list of entries
  List<String> get textList =>
      text
          .split(RegExp(r'\n|,'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

  /// Helper: join a list of strings into text
  static String joinList(List<String> items) => items.join(', ');
}

/// Represents a full CV
class CVModel {
  final String cvId;
  final String userId;
  final Map<String, CVSection> cvData; // Map of sectionKey -> CVSection
  final bool isCompleted;
  final String? aiEnhancedText;
  final DateTime createdAt;
  final DateTime updatedAt;

  CVModel({
    required this.cvId,
    required this.userId,
    required this.cvData,
    required this.isCompleted,
    this.aiEnhancedText,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create CVModel from Firestore snapshot
  factory CVModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final cvDataRaw = data['cvData'] as Map<String, dynamic>? ?? {};
    final cvData = cvDataRaw.map(
          (key, value) => MapEntry(
        key,
        value is Map<String, dynamic>
            ? CVSection.fromMap(value)
            : CVSection(text: value?.toString() ?? ''),
      ),
    );

    return CVModel(
      cvId: data['cvId'] ?? '',
      userId: data['userId'] ?? '',
      cvData: cvData,
      isCompleted: data['isCompleted'] ?? false,
      aiEnhancedText: data['aiEnhancedText'],
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert CVModel to Map for Firestore
  Map<String, dynamic> toMap() {
    final cvDataMap = cvData.map((key, section) => MapEntry(key, section.toMap()));
    return {
      'cvId': cvId,
      'userId': userId,
      'cvData': cvDataMap,
      'isCompleted': isCompleted,
      'aiEnhancedText': aiEnhancedText,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy CVModel with optional overrides
  CVModel copyWith({
    String? cvId,
    String? userId,
    Map<String, CVSection>? cvData,
    bool? isCompleted,
    String? aiEnhancedText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CVModel(
      cvId: cvId ?? this.cvId,
      userId: userId ?? this.userId,
      cvData: cvData ?? this.cvData,
      isCompleted: isCompleted ?? this.isCompleted,
      aiEnhancedText: aiEnhancedText ?? this.aiEnhancedText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Utility: Get plain map of section texts
  Map<String, String> get plainTextMap => cvData.map((key, section) => MapEntry(key, section.text));
}
