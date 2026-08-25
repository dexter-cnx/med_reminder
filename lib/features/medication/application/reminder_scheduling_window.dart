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
    final elapsedDays = today.difference(startDay).inDays;
    final firstRemainingOffset = elapsedDays.clamp(0, totalDays);
    final remainingDays = totalDays - firstRemainingOffset;
    if (remainingDays <= 0) return null;

    final windowDays = remainingDays < maxCalendarDays
        ? remainingDays
        : maxCalendarDays;
    final sliceStart = elapsedDays <= 0 ? startDay : today;
    return ReminderDaySlice(start: sliceStart, dayCount: windowDays);
  }
}

final class ReminderDaySlice {
  const ReminderDaySlice({required this.start, required this.dayCount});

  final DateTime start;
  final int dayCount;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

const defaultReminderSchedulingWindow = ReminderSchedulingWindow();
