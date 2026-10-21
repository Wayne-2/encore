import 'dart:async';

import 'package:flutter/material.dart';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatClockTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// Formats a post timestamp as "Just now", "N mins ago", then clock time.
String formatActiveTimestamp(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  final current = (now ?? DateTime.now()).toLocal();
  final difference = current.difference(local);

  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  }

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAgo = today.difference(day).inDays;
  final clock = formatClockTime(local);

  if (daysAgo <= 0) return clock;
  if (daysAgo == 1) return 'Yesterday, $clock';
  if (local.year == current.year) {
    return '${local.day} ${_months[local.month - 1]}, $clock';
  }
  return '${local.day} ${_months[local.month - 1]} ${local.year}, $clock';
}

/// A timestamp that refreshes itself as time passes.
class ActiveTimestamp extends StatefulWidget {
  const ActiveTimestamp({
    super.key,
    required this.at,
    this.fallback = '',
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final DateTime? at;
  final String fallback;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  State<ActiveTimestamp> createState() => _ActiveTimestampState();
}

class _ActiveTimestampState extends State<ActiveTimestamp> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ActiveTimestamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.at != widget.at) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.at == null) return;

    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.at;
    return Text(
      at == null ? widget.fallback : formatActiveTimestamp(at),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
