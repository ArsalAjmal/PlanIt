class EventModel {
  final String name;
  final DateTime eventDate;

  EventModel({required this.name, required this.eventDate});

  Map<String, int> getCountdown() {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return {
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
    };
  }
}
