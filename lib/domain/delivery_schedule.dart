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
  static bool inJourney(DateTime instant) {
    final s = elapsedSeconds(instant);
    return s >= 0 && s < 24 * 60;
  }

  static String status(DateTime instant) {
    final s = elapsedSeconds(instant);
    return s < 0
        ? 'Scheduled'
        : s < 6 * 60
        ? 'Tiffe left'
        : s < 24 * 60
        ? 'On the way'
        : 'Tiffe arrived';
  }

  static double progress(DateTime instant) =>
      (elapsedSeconds(instant) / (24 * 60)).clamp(0.0, 1.0);
  static int remainingMinutes(DateTime instant) =>
      (24 - elapsedSeconds(instant) / 60).ceil().clamp(0, 24);
  static String countdown(DateTime instant) {
    final d = nextDeparture(instant).difference(instant.toUtc());
    final s = d.inSeconds.clamp(0, 86400);
    return '${(s ~/ 3600).toString().padLeft(2, '0')}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
