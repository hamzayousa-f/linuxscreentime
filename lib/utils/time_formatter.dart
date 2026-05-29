class TimeFormatter {
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes < 0) return "0m";

    final int hours = totalMinutes ~/ 60; // Integer division to get whole hours
    final int minutes = totalMinutes %
        60; // Remainder modulo operation to get remaining minutes

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }
}
