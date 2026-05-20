import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicenote/features/dashboard/domain/dashboard_time_filter.dart';

void main() {
  group('DashboardTimeFilter.resolveRange', () {
    test('today returns start/end of current day', () {
      final now = DateTime(2026, 5, 21, 10, 20, 30);
      final range = DashboardTimeFilter.resolveRange(
        DashboardRangeKey.today,
        now: now,
      );

      expect(range.start, DateTime(2026, 5, 21, 0, 0, 0));
      expect(range.end, DateTime(2026, 5, 21, 23, 59, 59));
    });

    test('yesterday returns previous day boundaries', () {
      final now = DateTime(2026, 5, 21, 10, 20, 30);
      final range = DashboardTimeFilter.resolveRange(
        DashboardRangeKey.yesterday,
        now: now,
      );

      expect(range.start, DateTime(2026, 5, 20, 0, 0, 0));
      expect(range.end, DateTime(2026, 5, 20, 23, 59, 59));
    });

    test('sevenDays starts 6 days before today', () {
      final now = DateTime(2026, 5, 21, 10, 20, 30);
      final range = DashboardTimeFilter.resolveRange(
        DashboardRangeKey.sevenDays,
        now: now,
      );

      expect(range.start, DateTime(2026, 5, 15, 0, 0, 0));
      expect(range.end, DateTime(2026, 5, 21, 23, 59, 59));
    });

    test('lastMonth works across year boundary', () {
      final now = DateTime(2026, 1, 5, 12, 0, 0);
      final range = DashboardTimeFilter.resolveRange(
        DashboardRangeKey.lastMonth,
        now: now,
      );

      expect(range.start, DateTime(2025, 12, 1, 0, 0, 0));
      expect(range.end, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('custom normalizes to full-day boundaries', () {
      final custom = DateTimeRange(
        start: DateTime(2026, 5, 2, 15, 30),
        end: DateTime(2026, 5, 8, 9, 45),
      );
      final range = DashboardTimeFilter.resolveRange(
        DashboardRangeKey.custom,
        custom: custom,
      );

      expect(range.start, DateTime(2026, 5, 2, 0, 0, 0));
      expect(range.end, DateTime(2026, 5, 8, 23, 59, 59));
    });
  });

  group('DashboardTimeFilter.contains', () {
    test('includes both start and end boundaries', () {
      final range = DashboardResolvedRange(
        DateTime(2026, 5, 1, 0, 0, 0),
        DateTime(2026, 5, 1, 23, 59, 59),
      );

      expect(
        DashboardTimeFilter.contains(DateTime(2026, 5, 1, 0, 0, 0), range),
        isTrue,
      );
      expect(
        DashboardTimeFilter.contains(DateTime(2026, 5, 1, 23, 59, 59), range),
        isTrue,
      );
      expect(
        DashboardTimeFilter.contains(DateTime(2026, 4, 30, 23, 59, 59), range),
        isFalse,
      );
      expect(
        DashboardTimeFilter.contains(DateTime(2026, 5, 2, 0, 0, 0), range),
        isFalse,
      );
    });
  });
}
