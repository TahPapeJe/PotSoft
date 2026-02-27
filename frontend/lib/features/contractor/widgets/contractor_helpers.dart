import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

Color priorityColor(String p) {
  switch (p) {
    case 'Red':
      return Colors.redAccent;
    case 'Yellow':
      return Colors.amberAccent;
    case 'Green':
      return Colors.greenAccent;
    default:
      return Colors.white54;
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'In Progress':
      return Colors.orange;
    case 'Finished':
      return Colors.cyan;
    case 'Analyzed':
      return Colors.tealAccent;
    default:
      return Colors.white54;
  }
}

// ─── Time helper ──────────────────────────────────────────────────────────────

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}

// ─── Image helpers ────────────────────────────────────────────────────────────

Uint8List? tryBase64Bytes(String src) {
  if (src.startsWith('data:image/')) {
    try {
      final comma = src.indexOf(',');
      if (comma != -1) return base64Decode(src.substring(comma + 1));
    } catch (_) {}
  }
  return null;
}

Widget reportImage(String src, {double height = 160}) {
  final bytes = tryBase64Bytes(src);
  if (bytes != null) {
    return Image.memory(
      bytes,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }
  return Image.network(
    src,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      height: height,
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white38,
          size: 40,
        ),
      ),
    ),
  );
}

Widget thumbnailImage(String src) {
  final bytes = tryBase64Bytes(src);
  if (bytes != null) {
    return Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover);
  }
  return Image.network(
    src,
    width: 64,
    height: 64,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      width: 64,
      height: 64,
      color: Colors.grey[850],
      child: const Icon(Icons.image, color: Colors.white24, size: 28),
    ),
  );
}

// ─── SnackBar helper ─────────────────────────────────────────────────────────

SnackBar buildSnackBar(String message, Color color) {
  return SnackBar(
    content: Text(message, style: const TextStyle(color: Colors.black)),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(16),
  );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 12,
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
