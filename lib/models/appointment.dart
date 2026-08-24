class Appointment {
  final String id;
  final String clientName;
  final String serviceName;
  final double value;
  final DateTime date;
  final String time;
  final String notes;

  Appointment({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.value,
    required this.date,
    required this.time,
    required this.notes,
  });
}
