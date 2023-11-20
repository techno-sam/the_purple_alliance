import 'package:flutter/material.dart';
import 'package:the_purple_alliance/state/meta/config_state.dart';

class SimplePasswordFormField extends StatefulWidget {
  const SimplePasswordFormField({
    super.key,
    required this.genericTextStyle,
    required this.config,
    this.formKey,
  });

  final TextStyle genericTextStyle;
  final ConfigState config;
  final Key? formKey;

  @override
  State<SimplePasswordFormField> createState() => _SimplePasswordFormFieldState();
}

class _SimplePasswordFormFieldState extends State<SimplePasswordFormField> {

  bool passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      key: widget.formKey,
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        labelText: "Password",
        labelStyle: widget.genericTextStyle,
        suffixIcon: IconButton(
          icon: Icon(
            passwordVisible ? Icons.visibility : Icons.visibility_off,
            color: theme.colorScheme.primary,
          ),
          onPressed: () {
            setState(() {
              passwordVisible = !passwordVisible;
            });
          },
        ),
      ),
      controller: TextEditingController(text: widget.config.password),
      obscureText: !passwordVisible,
      enableIMEPersonalizedLearning: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      readOnly: widget.config.locked,
//      initialValue: widget.appState._password,
      onChanged: (value) {
        widget.config.password = value;
      },
      validator: (String? value) {
        if (value == null || value == "") {
          return "Must have a password!";
        }
        return null; // ok
      },
    );
  }
}