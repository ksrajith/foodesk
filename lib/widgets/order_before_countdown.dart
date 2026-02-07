import 'dart:async';
import 'package:flutter/material.dart';

/// Given an hour (0-23) in 24h format. If [deliveryDate] is set, the deadline is
/// the day before delivery at that hour (deadline applies only to the following day).
/// Otherwise shows countdown to today at that hour.
class OrderBeforeCountdown extends StatefulWidget {
  const OrderBeforeCountdown({
    Key? key,
    required this.orderBeforeHour24,
    this.label = 'Recommended Order Before',
    this.deliveryDate,
  }) : super(key: key);

  final int orderBeforeHour24;
  final String label;
  /// If set, deadline = (deliveryDate - 1 day) at orderBeforeHour24.
  final DateTime? deliveryDate;

  /// Deadline for "next day" rule: day before [deliveryDate] at [hour]. Use from place_meal_screen to disable Confirm.
  static DateTime deadlineForDelivery(DateTime deliveryDate, int hour) {
    final dayBefore = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day)
        .subtract(const Duration(days: 1));
    return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, hour.clamp(0, 23), 0);
  }

  @override
  State<OrderBeforeCountdown> createState() => _OrderBeforeCountdownState();
}

class _OrderBeforeCountdownState extends State<OrderBeforeCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadline = widget.deliveryDate != null
        ? OrderBeforeCountdown.deadlineForDelivery(widget.deliveryDate!, widget.orderBeforeHour24)
        : DateTime(now.year, now.month, now.day, widget.orderBeforeHour24.clamp(0, 23), 0);

    String text;
    Color color;
    if (now.isBefore(deadline)) {
      final left = deadline.difference(now);
      final h = left.inHours;
      final m = left.inMinutes % 60;
      text = '${h}h ${m}m';
      color = Colors.green.shade700;
    } else {
      text = widget.deliveryDate != null
          ? 'Deadline passed for selected date'
          : 'Closed for today (resets at 00:00)';
      color = Colors.orange.shade700;
    }

    final timeStr = '${widget.orderBeforeHour24.toString().padLeft(2, '0')}:00';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.teal.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr — $text',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
