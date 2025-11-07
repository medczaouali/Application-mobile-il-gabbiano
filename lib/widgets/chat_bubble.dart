import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final Widget child;
  final bool isMe;
  final Color? color;

  const ChatBubble({super.key, required this.child, this.isMe = false, this.color});

  @override
  Widget build(BuildContext context) {
  final bg = color ?? (isMe ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.grey.shade100);
    return CustomPaint(
      painter: _BubblePainter(color: bg, isMe: isMe),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: isMe ? const EdgeInsets.only(left: 40) : const EdgeInsets.only(right: 40),
        child: child,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  final bool isMe;

  _BubblePainter({required this.color, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(12));
    final paint = Paint()..color = color;
    canvas.drawRRect(rrect, paint);

    // tail
    final path = Path();
    if (isMe) {
      // tail on right
      path.moveTo(size.width, size.height - 12);
      path.relativeLineTo(8, 6);
      path.relativeLineTo(-8, 0);
    } else {
      // tail on left
      path.moveTo(0, size.height - 12);
      path.relativeLineTo(-8, 6);
      path.relativeLineTo(8, 0);
    }
    canvas.drawPath(path, paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.1));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
