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

  /// ✅ Create a CVModel from Firestore data
  factory CVModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CVModel(
      cvId: data['cvId'] ?? '',
      userId: data['userId'] ?? '',
      cvData: Map<String, dynamic>.from(data['cvData'] ?? {}),
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
    return {
      'cvId': cvId,
      'userId': userId,
      'cvData': cvData,
      'isCompleted': isCompleted,
      'aiEnhancedText': aiEnhancedText,
      'createdAt': createdAt is DateTime ? Timestamp.fromDate(createdAt) : createdAt,
      'updatedAt': updatedAt is DateTime ? Timestamp.fromDate(updatedAt) : updatedAt,
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
}
