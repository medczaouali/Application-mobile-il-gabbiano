import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.isPassword = false,
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  void _toggle() {
    setState(() => _obscure = !_obscure);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: Icon(widget.icon, color: cs.primary),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: cs.primary),
                onPressed: _toggle,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        // Respect theme for dark/light contrast; fall back to surface
        fillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface,
      ),
      validator: widget.validator,
    );
  }
}
