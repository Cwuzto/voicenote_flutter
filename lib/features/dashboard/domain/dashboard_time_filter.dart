import 'package:flutter/material.dart';

enum DashboardRangeKey {
  today,
  yesterday,
  sevenDays,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class DashboardResolvedRange {
  const DashboardResolvedRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  DateTime get startDay => DateTime(start.year, start.month, start.day);
}

class DashboardTimeFilter {
  static DashboardResolvedRange resolveRange(
    DashboardRangeKey key, {
    DateTime? now,
    DateTimeRange? custom,
  }) {
    final current = now ?? DateTime.now();
    final endOfToday = DateTime(
      current.year,
      current.month,
      current.day,
      23,
      59,
      59,
    );
    final startOfToday = DateTime(current.year, current.month, current.day);

    switch (key) {
      case DashboardRangeKey.today:
        return DashboardResolvedRange(startOfToday, endOfToday);
      case DashboardRangeKey.yesterday:
        final y = startOfToday.subtract(const Duration(days: 1));
        return DashboardResolvedRange(
          y,
          DateTime(y.year, y.month, y.day, 23, 59, 59),
        );
      case DashboardRangeKey.sevenDays:
        return DashboardResolvedRange(
          startOfToday.subtract(const Duration(days: 6)),
          endOfToday,
        );
      case DashboardRangeKey.thisMonth:
        return DashboardResolvedRange(
          DateTime(current.year, current.month, 1),
          endOfToday,
        );
      case DashboardRangeKey.lastMonth:
        final firstThisMonth = DateTime(current.year, current.month, 1);
        final lastPrevMonth = firstThisMonth.subtract(const Duration(seconds: 1));
        final firstPrevMonth = DateTime(lastPrevMonth.year, lastPrevMonth.month, 1);
        return DashboardResolvedRange(firstPrevMonth, lastPrevMonth);
      case DashboardRangeKey.thisYear:
        return DashboardResolvedRange(DateTime(current.year, 1, 1), endOfToday);
      case DashboardRangeKey.custom:
        if (custom != null) {
          return DashboardResolvedRange(
            DateTime(custom.start.year, custom.start.month, custom.start.day),
            DateTime(
              custom.end.year,
              custom.end.month,
              custom.end.day,
              23,
              59,
              59,
            ),
          );
        }
        return DashboardResolvedRange(
          DateTime(current.year, current.month, 1),
          endOfToday,
        );
    }
  }

  static bool contains(DateTime value, DashboardResolvedRange range) {
    return !value.isBefore(range.start) && !value.isAfter(range.end);
  }
}
