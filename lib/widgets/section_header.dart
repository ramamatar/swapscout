import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE5DA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.edit_outlined,
            size: 16,
            color: Color(0xFFF28C64),
          ),
        ),
      ],
    );
  }
}
