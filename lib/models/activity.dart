/// A single upcoming (or past) activity shown in the Updates grid.
class Activity {
  const Activity({
    this.id = '',
    this.authorId = '',
    required this.title,
    required this.date,
  });

  final String id;
  final String authorId;
  final String title;

  /// The calendar day of the activity (time is ignored).
  final DateTime date;

  /// Whether [userId] is the author and may therefore delete this activity.
  bool canBeDeletedBy(String? userId) =>
      userId != null && userId.isNotEmpty && userId == authorId;

  /// Whether the activity's day has already passed.
  bool get isPast {
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// e.g. `Tue, 20 Oct` (adds the year when it isn't the current year).
  String get dateLabel => formatDate(date);

  /// Formats an activity's calendar day for the grid and the composer.
  static String formatDate(DateTime date) {
    final base =
        '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
    return date.year == DateTime.now().year ? base : '$base ${date.year}';
  }

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _months = [
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
}
