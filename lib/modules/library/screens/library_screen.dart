// lib/modules/library/screens/library_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/cv_model.dart';
import '../widgets/cv_item.dart';
import '../../cv_preview/preview_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, bool> _selectedCVs = {};
  bool _selectAll = false;
  bool _selectionMode = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to see your library.'),
        ),
      );
    }
    final userId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Library CVs"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userId)
            .collection('libraryCVs_clean')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No CVs saved in library.'));
          }

          final cvs = docs.map((doc) => CVModel.fromFirestore(doc)).toList();

          // Initialize selection map
          for (var cv in cvs) {
            _selectedCVs.putIfAbsent(cv.cvId, () => false);
          }

          return Column(
            children: [
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: _selectAll,
                          onChanged: (val) {
                            setState(() {
                              _selectAll = val ?? false;
                              for (var key in _selectedCVs.keys) {
                                _selectedCVs[key] = _selectAll;
                              }
                            });
                          },
                          title: const Text("Select All"),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Delete Selected',
                        onPressed: _selectedCVs.values.any((v) => v)
                            ? () => _deleteSelectedCVs(userId)
                            : null,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: cvs.length,
                  itemBuilder: (context, index) {
                    final cv = cvs[index];
                    final isSelected = _selectedCVs[cv.cvId] ?? false;

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _selectionMode = true;
                          _selectedCVs[cv.cvId] = true;
                        });
                      },
                      onTap: () {
                        if (_selectionMode) {
                          setState(() {
                            _selectedCVs[cv.cvId] = !isSelected;
                            if (_selectedCVs.values.every((v) => !v)) {
                              _selectionMode = false;
                              _selectAll = false;
                            }
                            _selectAll = !_selectedCVs.values.contains(false);
                          });
                        } else {
                          _viewCV(cv);
                        }
                      },
                      child: CVItem(
                        cv: cv,
                        isSelected: isSelected,
                        showCheckbox: _selectionMode,
                        onSelectChanged: (val) {
                          setState(() {
                            _selectedCVs[cv.cvId] = val ?? false;
                            if (_selectedCVs.values.every((v) => !v)) {
                              _selectionMode = false;
                              _selectAll = false;
                            }
                            _selectAll = !_selectedCVs.values.contains(false);
                          });
                        },
                        onDelete: () => _deleteSingleCV(userId, cv),
                        onView: () => _viewCV(cv),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _viewCV(CVModel cv) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PreviewScreen(cv: cv)),
    );
  }

  Future<void> _deleteSingleCV(String userId, CVModel cv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete CV"),
        content: const Text("Are you sure you want to delete this CV?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('libraryCVs_clean')
          .doc(cv.cvId)
          .delete();
      setState(() {
        _selectedCVs.remove(cv.cvId);
        if (_selectedCVs.values.every((v) => !v)) {
          _selectionMode = false;
          _selectAll = false;
        }
      });
    }
  }

  Future<void> _deleteSelectedCVs(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Selected CVs"),
        content: const Text("Are you sure you want to delete all selected CVs?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = _firestore.batch();
      _selectedCVs.forEach((cvId, selected) {
        if (selected) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('libraryCVs_clean')
              .doc(cvId);
          batch.delete(docRef);
        }
      });
      await batch.commit();
      setState(() {
        _selectedCVs.clear();
        _selectAll = false;
        _selectionMode = false;
      });
    }
  }
}