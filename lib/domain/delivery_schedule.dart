class DeliverySchedule {
  static const puneOffset = Duration(hours: 5, minutes: 30);
  static DateTime puneTime(DateTime instant) => instant.toUtc().add(puneOffset);
  static DateTime departure(DateTime instant) {
    final p = puneTime(instant);
    return DateTime.utc(p.year, p.month, p.day, 20).subtract(puneOffset);
  }

  static DateTime nextDeparture(DateTime instant) {
    final d = departure(instant);
    return instant.toUtc().isBefore(d) ? d : d.add(const Duration(days: 1));
  }

  static int elapsedSeconds(DateTime instant) =>
      instant.toUtc().difference(departure(instant)).inSeconds;
  static bool inJourney(DateTime instant) => false;
  static String status(DateTime instant) => 'Waiting for staff update';
  static double progress(DateTime instant) => 0;
  static int remainingMinutes(DateTime instant) => 0;
  static String countdown(DateTime instant) => 'Waiting for staff update';
}
