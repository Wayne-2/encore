import 'package:flutter_test/flutter_test.dart';

import 'package:encore/services/activity_store.dart';
import 'package:encore/utils/content_lifetime.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);

  test('announcements, trends and activities use the agreed lifetimes', () {
    expect(ContentLifetime.announcement, const Duration(hours: 24));
    expect(ContentLifetime.trend, const Duration(days: 3));
    expect(ContentLifetime.activity, const Duration(days: 7));

    expect(
      ContentLifetime.isExpired(
        now.subtract(const Duration(hours: 23)),
        ContentLifetime.announcement,
        now: now,
      ),
      isFalse,
    );
    expect(
      ContentLifetime.isExpired(
        now.subtract(const Duration(hours: 24)),
        ContentLifetime.announcement,
        now: now,
      ),
      isTrue,
    );
    expect(
      ContentLifetime.isExpired(
        now.subtract(const Duration(days: 3)),
        ContentLifetime.trend,
        now: now,
      ),
      isTrue,
    );
    expect(
      ContentLifetime.isExpired(
        now.subtract(const Duration(days: 7)),
        ContentLifetime.activity,
        now: now,
      ),
      isTrue,
    );
  });

  test('activity store hides and prunes expired posts', () {
    final store = ActivityStore.instance;
    store.clear();
    final current = DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    store.add(
      title: 'Old activity',
      date: today,
      authorId: 'seed',
      createdAt: current.subtract(const Duration(days: 8)),
    );
    store.add(
      title: 'Fresh activity',
      date: today,
      authorId: 'seed',
      createdAt: current.subtract(const Duration(days: 6)),
    );

    expect(store.items.map((item) => item.title), ['Fresh activity']);

    store.pruneExpired();
    expect(store.items.map((item) => item.title), ['Fresh activity']);
    store.clear();
  });
}
