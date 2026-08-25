final class ReminderSchedulingWindow {
  const ReminderSchedulingWindow({this.maxDaysAhead = 14})
    : assert(maxDaysAhead > 0);

  final int maxDaysAhead;

  bool includes(DateTime scheduled, DateTime now) {
    if (!scheduled.isAfter(now)) return false;
    final cutoff = now.add(Duration(days: maxDaysAhead));
    return !scheduled.isAfter(cutoff);
  }
}

const defaultReminderSchedulingWindow = ReminderSchedulingWindow();
