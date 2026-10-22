/// Content lifetimes for the shared Updates feed.
abstract final class ContentLifetime {
  static const Duration announcement = Duration(hours: 24);
  static const Duration trend = Duration(days: 3);
  static const Duration activity = Duration(days: 7);

  /// Whether [createdAt] is older than [lifetime].
  ///
  /// Items without a creation timestamp are kept so legacy content is not
  /// removed before it can be migrated.
  static bool isExpired(
    DateTime? createdAt,
    Duration lifetime, {
    DateTime? now,
  }) {
    if (createdAt == null) return false;
    return !createdAt.add(lifetime).isAfter(now ?? DateTime.now());
  }
}
