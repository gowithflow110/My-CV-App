// lib/modules/library/widgets/cv_item.dart

import 'package:flutter/material.dart';
import '../../../models/cv_model.dart';

class CVItem extends StatelessWidget {
  final CVModel cv;
  final bool isSelected;
  final bool showCheckbox; // NEW
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onDelete;
  final VoidCallback onView;

  const CVItem({
    Key? key,
    required this.cv,
    required this.onView,
    required this.onDelete,
    required this.isSelected,
    required this.onSelectChanged,
    this.showCheckbox = false, // default false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: showCheckbox
          ? Checkbox(
        value: isSelected,
        onChanged: onSelectChanged,
      )
          : null, // hide checkbox when not in selection mode
      title: Text(cv.cvData['name'] ?? cv.cvData['header']?['name'] ?? "Untitled CV"),
      subtitle: Text(
        '${cv.createdAt.day}-${cv.createdAt.month}-${cv.createdAt.year}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: showCheckbox
          ? null // hide 3-dot menu during selection mode
          : PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'view') {
            onView();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'view', child: Text('View')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}