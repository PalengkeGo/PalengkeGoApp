/// Time-aware greeting in Bikol dialect:
/// morning (5:00-11:59): "Marhay na Aga"
/// afternoon (12:00-17:59): "Marhay na Hapon"
/// evening (18:00-4:59): "Marhay na Banggi"
String getBikolGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 12) return 'Marhay na Aga';
  if (hour >= 12 && hour < 18) return 'Marhay na Hapon';
  return 'Marhay na Banggi';
}
