import 'package:flutter/material.dart';

/// Dialog for configuring the ADB executable path.
class AdbPathDialog extends StatefulWidget {
  final String currentPath;
  final Future<void> Function(String path) onPathChanged;

  const AdbPathDialog({
    super.key,
    required this.currentPath,
    required this.onPathChanged,
  });

  @override
  State<AdbPathDialog> createState() => _AdbPathDialogState();
}

class _AdbPathDialogState extends State<AdbPathDialog> {
  late final TextEditingController _controller;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPath);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ADB Path'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the path to the ADB executable, or leave as "adb" to use system PATH.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'ADB executable path',
                hintText: 'adb',
                border: const OutlineInputBorder(),
                suffixIcon: _validating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              autofocus: true,
              onSubmitted: (_) => _apply(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validating ? null : _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() => _validating = true);
    await widget.onPathChanged(_controller.text.trim());
    setState(() => _validating = false);
    if (mounted) Navigator.pop(context);
  }
}
