// lib/models/cv_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CVModel {
  final String cvId;                // Unique CV ID (same pattern as existing: cv_<timestamp>)
  final String userId;              // Owner's Firebase UID
  final Map<String, dynamic> cvData; // All CV sections (name, contact, skills, etc.)
  final bool isCompleted;           // Whether CV was marked complete
  final String? aiEnhancedText;     // Optional: AI-enhanced version
  final DateTime createdAt;         // Timestamp when CV was first created
  final DateTime updatedAt;         // Timestamp when CV was last updated

  CVModel({
    required this.cvId,
    required this.userId,
    required this.cvData,
    required this.isCompleted,
    this.aiEnhancedText,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper getters for commonly accessed fields
  String get name => cvData['name']?.toString() ?? '';
  String get summary => cvData['summary']?.toString() ?? '';
  Map<String, dynamic> get contact => Map<String, dynamic>.from(cvData['contact'] ?? {});
  List<String> get skills => List<String>.from(cvData['skills'] ?? []);
  List<dynamic> get experience => List<dynamic>.from(cvData['experience'] ?? []);
  List<dynamic> get projects => List<dynamic>.from(cvData['projects'] ?? []);
  List<dynamic> get education => List<dynamic>.from(cvData['education'] ?? []);
  List<dynamic> get certifications => List<dynamic>.from(cvData['certifications'] ?? []);
  List<String> get languages => List<String>.from(cvData['languages'] ?? []);

  /// ✅ Create a CVModel from Firestore data
  factory CVModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both old and new data structures
    Map<String, dynamic> cvData = Map<String, dynamic>.from(data['cvData'] ?? {});

    // If we have header data in the old format, migrate it to the new format
    if (cvData.containsKey('header') && cvData['header'] is Map) {
      final headerData = Map<String, dynamic>.from(cvData['header']);
      cvData.addAll({
        'name': headerData['name'] ?? '',
        'summary': headerData['summary'] ?? '',
      });
      cvData.remove('header'); // Remove the old header structure
    }

    // Ensure we have the required fields
    if (!cvData.containsKey('name')) cvData['name'] = '';
    if (!cvData.containsKey('summary')) cvData['summary'] = '';

    return CVModel(
      cvId: data['cvId'] ?? doc.id, // Use document ID as fallback
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

  /// ✅ Convert CVModel to Firestore format
  Map<String, dynamic> toMap() {
    // Ensure name and summary are at the root level of cvData
    final Map<String, dynamic> processedCvData = Map<String, dynamic>.from(cvData);

    // Remove any legacy header structure if it exists
    if (processedCvData.containsKey('header')) {
      processedCvData.remove('header');
    }

    // Ensure required fields exist
    if (!processedCvData.containsKey('name')) processedCvData['name'] = '';
    if (!processedCvData.containsKey('summary')) processedCvData['summary'] = '';

    return {
      'cvId': cvId,
      'userId': userId,
      'cvData': processedCvData,
      'isCompleted': isCompleted,
      'aiEnhancedText': aiEnhancedText,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// ✅ Create a copy of CVModel with updated fields
  CVModel copyWith({
    String? cvId,
    String? userId,
    Map<String, dynamic>? cvData,
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

  /// Update specific fields in cvData
  CVModel updateCvDataField(String key, dynamic value) {
    final updatedCvData = Map<String, dynamic>.from(cvData);
    updatedCvData[key] = value;
    return copyWith(cvData: updatedCvData);
  }

  /// Update multiple fields in cvData
  CVModel updateCvDataFields(Map<String, dynamic> updates) {
    final updatedCvData = Map<String, dynamic>.from(cvData);
    updatedCvData.addAll(updates);
    return copyWith(cvData: updatedCvData);
  }

  /// Check if the CV has all required fields filled
  bool get isComplete {
    return name.isNotEmpty &&
        summary.isNotEmpty &&
        contact.isNotEmpty &&
        skills.isNotEmpty;
  }

  /// Get a formatted string representation of the CV
  String toFormattedString() {
    return '''
CV ID: $cvId
User ID: $userId
Name: $name
Summary: $summary
Skills: ${skills.length}
Experience: ${experience.length} items
Education: ${education.length} items
Completed: $isCompleted
Created: ${createdAt.toString()}
Updated: ${updatedAt.toString()}
''';
  }
}