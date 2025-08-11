// mic_button.dart

import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onPressed;

  const MicButton({
    Key? key,
    required this.isListening,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        icon: Icon(
          isListening ? Icons.mic_off : Icons.mic,
          size: 40,
          color: isListening ? Colors.red : Colors.blue,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
