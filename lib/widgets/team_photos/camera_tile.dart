import 'package:flutter/material.dart';

class CameraTile extends StatelessWidget {
  final Function() onTap;
  const CameraTile(this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        child: InkWell(
            onTap: onTap,
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
            child: const Icon(Icons.photo_camera_outlined, size: 48,)
        )
    );
  }
}