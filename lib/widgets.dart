import 'package:flutter/material.dart';

class DisplayCard extends StatelessWidget {
  const DisplayCard({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Center(child: icon),
            if (icon != null) SizedBox(width: 8),
            Text(
              text,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}