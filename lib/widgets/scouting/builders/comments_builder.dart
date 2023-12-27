import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/screens/main/scouting_sub/comments_list_page.dart';
import 'package:the_purple_alliance/state/data_values/comments.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';

import 'abstract_synchronized_builder.dart';

class CommentsWidgetBuilder extends LabeledAndPaddedSynchronizedBuilder<CommentsDataValue> {
  late final TextEditingController _controller;
  CommentsWidgetBuilder.fromJson(super.schemeData) : super.fromJson() {
    _controller = TextEditingController(text: dataValue?.personalComment ?? CommentsDataValue.getDefault());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ignore: unused_local_variable
    var appState = context.watch<MyAppState>(); // keep this here for now until individual change notification is implemented
    var config = context.watch<ConfigState>();
    var heroTag = "comment_title_$label:$key";
    _controller.text = dataValue?.personalComment ?? CommentsDataValue.getDefault();
    return Padding(
      padding: EdgeInsets.all(padding ?? 8.0),
      child: Card(
          color: oldColors ? theme.colorScheme.primaryContainer : null,
          child: Container(
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  Hero(tag: heroTag, child: Text(label, style: theme.textTheme.headlineSmall)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: ((context) {
                                return Scaffold(
                                  appBar: AppBar(
                                    backgroundColor: theme.primaryColorDark,
                                    title: Hero(tag: heroTag, child: Text(label, style: theme.textTheme.headlineSmall)),
                                    centerTitle: true,
                                  ),
                                  body: Center(
                                    child: CommentList(
                                      theme: theme,
                                      comments: (dataValue?.stringComments ?? {})..[config.username] = dataValue?.personalComment ?? "",
                                    ),
                                  ),
                                );
                              })
                          )
                      );
                    },
                    icon: const Icon(Icons.view_stream),
                    label: const Text("View All Comments"),
                  ),
                  const Divider(),
                  Text("Your comment", style: theme.textTheme.labelMedium),
                  TextFormField(
                    key: Key(key),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    controller: _controller,
                    onChanged: (value) {
                      dataValue?.personalComment = value;
                    },
                  )
                ],
              )
          )
      ),
    );
  }

  @override
  Widget buildSearchEditor(BuildContext context) {
    return const SizedBox();
  }

  @override
  IconData get icon => Icons.comment_outlined;
}