// lib/widgets/section_header.dart
import 'package:flutter/material.dart';
import '../screens/wedding_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: weddingSurface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Text(title,
          style: const TextStyle(
              color: weddingOnSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}
