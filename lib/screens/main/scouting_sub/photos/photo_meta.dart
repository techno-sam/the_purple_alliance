import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/state/images/image_record.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';

class PhotoMetaPage extends StatelessWidget {
  final String imagePath;
  final int teamNumber;
  PhotoMetaPage({super.key, required this.imagePath, required this.teamNumber});
  final GlobalKey<_TagSelectionState> _tagSelectionKey = GlobalKey<_TagSelectionState>(debugLabel: "tagSelectionKey");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var config = context.watch<ConfigState>();
    return Scaffold(
        appBar: AppBar(
          title: const Text("Image metadata"),
        ),
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                  children: [
                    Text("Team $teamNumber", style: theme.textTheme.headlineMedium),
                    Image.file(
                      File(imagePath),
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        return Card(
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.all(0.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: child,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(indent: 5, endIndent: 5, height: 20),
                    TagSelection(key: _tagSelectionKey),
                    const Divider(indent: 5, endIndent: 5, height: 20),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                              icon: const Icon(Icons.add_a_photo, color: Colors.black),
                              label: const Text("Post", style: TextStyle(color: Colors.black)),
                              onPressed: () {
                                //print("making record: $tagSelectionKey; ${tagSelectionKey.currentState}; ${tagSelectionKey.currentState?.tags}");
                                ImageRecord record = ImageRecord("", config.username, _tagSelectionKey.currentState?.tags ?? [], teamNumber);
                                Navigator.of(context).pop(record);
                              },
                              style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.green))
                          ),
                          ElevatedButton.icon(
                              icon: const Icon(Icons.cancel, color: Colors.black),
                              label: const Text("Cancel", style: TextStyle(color: Colors.black)),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red))
                          ),
                        ]
                    )
                  ]
              ),
            ),
          ),
        )
    );
  }
}

class TagSelection extends StatefulWidget {
  const TagSelection({
    super.key,
  });

  @override
  State<TagSelection> createState() => _TagSelectionState();
}

class _TagSelectionState extends State<TagSelection> {
  List<String> tags = [];
  final GlobalKey<FormFieldState<String>> _tagKey = GlobalKey<FormFieldState<String>>(debugLabel: "tag");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text("Tags", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [
                  for (String tag in tags)
                    Card(child: InkWell(
                      onTap: () {
                        setState(() {
                          tags.remove(tag);
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        child: Text(tag, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16)),
                      ),
                    )),
                ]
            ),
          ),
        ),
//        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              String? tag = await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Add tag"),
                    content: TextFormField(
                      key: _tagKey,
                      decoration: const InputDecoration(
                        hintText: "Enter tag",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(_tagKey.currentState?.value);
                        },
                        child: const Text("Add"),
                      ),
                    ],
                  );
                },
              );
              log("tag: $tag");
              if (tag != null && tag != "") {
                setState(() {
                  if (!tags.contains(tag)) {
                    tags.add(tag);
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }
}