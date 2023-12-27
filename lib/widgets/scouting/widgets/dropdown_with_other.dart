import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:the_purple_alliance/main.dart';
import 'package:the_purple_alliance/state/data_values/dropdown.dart';

class DropdownWithOther extends StatefulWidget {
  const DropdownWithOther({
    super.key,
    required double? padding,
    required String formKey,
    required String label,
    required DropdownDataValue? dataValue,
    required this.theme,
  }) : _padding = padding, _key = formKey, _label = label, _dataValue = dataValue;

  final double? _padding;
  final String _key;
  final String _label;
  final DropdownDataValue? _dataValue;
  final ThemeData theme;

  @override
  State<DropdownWithOther> createState() => _DropdownWithOtherState();
}

class _DropdownWithOtherState extends State<DropdownWithOther> {

  late final TextEditingController _controller;

  _DropdownWithOtherState();


  @override
  void initState() {
    super.initState();
    _showOtherField = widget._dataValue?.canBeOther == true && widget._dataValue?.value == "Other";
    _controller = TextEditingController(text: widget._dataValue?.otherValue ?? "");
  }

  bool get _canBeOther => widget._dataValue?.canBeOther == true;
  late bool _showOtherField;

  void update() {
    setState(() {
      _showOtherField = _canBeOther && widget._dataValue?.value == "Other";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget._padding ?? 8.0),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          var dropdown = DropdownButtonFormField(
            key: Key(widget._key),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: widget._label,
            ),
            items: [
              if (widget._dataValue != null)
                for (String value in widget._dataValue!.options)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: widget.theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              if (widget._dataValue != null && widget._dataValue!.canBeOther)
                DropdownMenuItem(
                  value: "Other",
                  child: Text(
                    "Other",
                    style: TextStyle(
                      color: widget.theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                widget._dataValue?.value = value;
                log("Set dropdown value to $value");
                update();
              }
            },
            value: widget._dataValue?.value,
            dropdownColor: widget.theme.colorScheme.primaryContainer,
          );
          if (!_showOtherField) {
            return dropdown;
          }
          _controller.text = widget._dataValue?.otherValue ?? _controller.text;
          return Column(
            children: [
              dropdown,
              TextFormField(
                key: Key("${widget._key}_text"),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: widget._label,
                ),
                keyboardType: TextInputType.text,
                controller: _controller,
                onChanged: (value) {
                  widget._dataValue?.otherValue = value;
                },
              )
            ],
          );
        },
      ),
    );
  }
}