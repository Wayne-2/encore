import 'package:flutter_test/flutter_test.dart';

import 'package:encore/utils/active_time.dart';

void main() {
  group('formatActiveTimestamp', () {
    final now = DateTime(2026, 10, 21, 15, 30);

    test('shows Just now under a minute', () {
      expect(
        formatActiveTimestamp(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        'Just now',
      );
    });

    test('shows minutes ago for recent posts', () {
      expect(
        formatActiveTimestamp(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        '1 min ago',
      );
      expect(
        formatActiveTimestamp(
          now.subtract(const Duration(minutes: 24)),
          now: now,
        ),
        '24 mins ago',
      );
    });

    test('shows the posted clock time after an hour', () {
      expect(
        formatActiveTimestamp(DateTime(2026, 10, 21, 13, 5), now: now),
        '1:05 PM',
      );
    });

    test('keeps the date for older posts', () {
      expect(
        formatActiveTimestamp(DateTime(2026, 10, 20, 9, 7), now: now),
        'Yesterday, 9:07 AM',
      );
    });
  });
}
