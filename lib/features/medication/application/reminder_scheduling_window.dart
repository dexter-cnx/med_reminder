import '../domain/entities/medication.dart';

final class ReminderSchedulingWindow {
  const ReminderSchedulingWindow({this.maxCalendarDays = 14})
    : assert(maxCalendarDays > 0);

  final int maxCalendarDays;

  Medication? project(Medication medication, DateTime now) {
    if (medication.mode != MedicationMode.days) return medication;
    final totalDays = medication.daysCount ?? 0;
    final slice = finiteCourseSlice(
      courseStart: medication.createdAt,
      totalDays: totalDays,
      now: now,
    );
    if (slice == null) return null;
    return medication.copyWith(
      createdAt: slice.start,
      daysCount: slice.dayCount,
    );
  }

  ReminderDaySlice? finiteCourseSlice({
    required DateTime courseStart,
    required int totalDays,
    required DateTime now,
  }) {
    if (totalDays <= 0) return null;

    final startDay = _dateOnly(courseStart);
    final today = _dateOnly(now);
    final elapsedDays = _calendarDaysBetween(startDay, today);

    if (elapsedDays >= totalDays) return null;

    if (elapsedDays < 0) {
      final daysUntilStart = -elapsedDays;
      final availableWindowDays = maxCalendarDays - daysUntilStart;
      if (availableWindowDays <= 0) return null;
      final windowDays = totalDays < availableWindowDays
          ? totalDays
          : availableWindowDays;
      return ReminderDaySlice(start: startDay, dayCount: windowDays);
    }

    final remainingDays = totalDays - elapsedDays;
    final windowDays = remainingDays < maxCalendarDays
        ? remainingDays
        : maxCalendarDays;
    return ReminderDaySlice(start: today, dayCount: windowDays);
  }
}

final class ReminderDaySlice {
  const ReminderDaySlice({required this.start, required this.dayCount});

  final DateTime start;
  final int dayCount;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _calendarDaysBetween(DateTime from, DateTime to) {
  final fromUtc = DateTime.utc(from.year, from.month, from.day);
  final toUtc = DateTime.utc(to.year, to.month, to.day);
  return toUtc.difference(fromUtc).inDays;
}

const defaultReminderSchedulingWindow = ReminderSchedulingWindow();
