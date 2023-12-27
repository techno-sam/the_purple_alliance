
import 'package:flutter/material.dart';

class CommentList extends StatelessWidget {
  const CommentList({
    super.key,
    required this.theme,
    required this.comments,
  });

  final ThemeData theme;
  final Map<String, String> comments;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.primaryColorDark,
      child: Column(
        children: [
          const Divider(color: Colors.black, indent: 20, endIndent: 20,),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  for (MapEntry<String, String> comment in comments.entries)
                    if (comment.value != '')
                      SizedBox(
                        height: 200,
                        child: Card(
                          color: theme.primaryColorLight,
                          elevation: 2,
                          child: Container(
                            margin: const EdgeInsets.all(4.0),
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.key, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
                                Divider(color: theme.colorScheme.onSurface, endIndent: 50),
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      child: Text(
                                        comment.value,
                                        style: TextStyle(color: theme.colorScheme.onSurface)
                                      )
                                    )
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}