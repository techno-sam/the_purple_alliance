import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  final void Function() onTap;
  const CameraCard(this.onTap, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 5/8,
      child: Card(
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            customBorder: theme.cardTheme.shape ?? const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))), //match shape of card
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Attach Picture',
                    style: TextStyle(fontSize: 17.0, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: theme.primaryColorDark,
                        size: 128,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
      ),
    );
  }
}