import 'package:flutter/material.dart';

class SectionListItem extends StatelessWidget {
  final List<String> entries;
  final Function(int) onEdit;
  final Function(int) onDelete;

  const SectionListItem({
    Key? key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(entry),
            leading: const Icon(Icons.check_circle_outline),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => onEdit(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => onDelete(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
