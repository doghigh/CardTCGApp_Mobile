import 'dart:io';
import 'package:flutter/material.dart';

class CardImage extends StatelessWidget {
  final String? path;
  final String placeholder;
  final double? width;
  final double? height;

  const CardImage({
    super.key,
    this.path,
    this.placeholder = 'No image',
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (path != null && File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path!),
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Center(
        child: Text(placeholder,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
    );
  }
}
