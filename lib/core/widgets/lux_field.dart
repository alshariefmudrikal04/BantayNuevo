import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/lux_theme.dart';

/// The one text-input treatment for the whole auth flow (login, register,
/// forgot-account) — same rounded-14/hairline-border/white-surface shape
/// already used throughout resident_home_screen.dart for its cards and
/// list rows, so a form field reads as part of the same system rather
/// than a separately-invented "input box" component. Centralized here
/// instead of copy-pasted per screen so there's exactly one place to
/// adjust the look.
class LuxField extends StatelessWidget {
  const LuxField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.hintText,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? hintText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: LuxType.eyebrow(fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: LuxColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LuxColors.divider),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: LuxType.body(fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: LuxType.body(fontSize: 14, color: LuxColors.inkSoft),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
