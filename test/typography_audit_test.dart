import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_12/app/theme.dart';
import 'package:flutter_application_12/models/booking_request_model.dart';
import 'package:flutter_application_12/core/constants/booking_status.dart';
import 'package:flutter_application_12/core/constants/payment_status.dart';
import 'package:flutter_application_12/features/payment/payment_details_screen.dart';

void main() {
  testWidgets('theme keeps heading metrics safe for full glyph rendering', (
    tester,
  ) async {
    final theme = BusGoTheme.light;

    expect(theme.textTheme.headlineSmall?.height, greaterThan(1.1));
    expect(theme.textTheme.titleLarge?.height, greaterThan(1.1));

    final request = BookingRequestModel(
      id: 'BK-1001',
      customerId: 'customer-1',
      customerName: 'Demo Customer',
      ownerId: 'owner-1',
      busId: 'bus-1',
      busName: 'Luxury Coach',
      pickup: 'Colombo',
      destination: 'Kandy',
      startDate: DateTime(2026, 9, 20, 9, 0),
      endDate: DateTime(2026, 9, 20, 12, 0),
      passengerCount: 2,
      tripType: 'Round trip',
      specialRequirements: '',
      estimatedAmount: 2500,
      status: BookingRequestStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      paymentReference: 'REF-12345',
      paymentSubmittedAt: DateTime(2026, 9, 18, 15, 30),
      createdAt: DateTime(2026, 9, 16),
      updatedAt: DateTime(2026, 9, 18),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: PaymentDetailsScreen(request: request),
      ),
    );

    expect(find.text('Payment Details'), findsWidgets);
    expect(find.text('Booking'), findsOneWidget);
  });
}
