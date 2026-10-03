class BusSearchQuery {
  const BusSearchQuery({
    required this.pickup,
    required this.destination,
    required this.travelDate,
    this.returnDate,
    required this.passengerCount,
    required this.tripType,
  });

  final String pickup;
  final String destination;
  final DateTime travelDate;
  final DateTime? returnDate;
  final int passengerCount;
  final String tripType;
}
