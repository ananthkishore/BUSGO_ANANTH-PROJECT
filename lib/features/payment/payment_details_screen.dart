import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../models/booking_request_model.dart';
import '../../widgets/busgo_ui.dart';

class PaymentDetailsUnavailableScreen extends StatelessWidget {
  const PaymentDetailsUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[PAYMENT_DETAILS] missing bookingId; refusing to open payment details',
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: BusGoErrorState(
          title: 'Payment details are unavailable for this booking.',
          message:
              'The booking reference was not available. Please go back and try again.',
          onRetry: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

class PaymentDetailsScreen extends StatelessWidget {
  const PaymentDetailsScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Payment Details'),
        leading: IconButton(
          tooltip: 'Back to trip details',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Details',
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: true,
                    ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _detail(
                    context,
                    Icons.payments_outlined,
                    'Payment status',
                    request.paymentStatus.label,
                  ),
                  _detail(
                    context,
                    Icons.currency_rupee_rounded,
                    'Amount',
                    '₹${request.estimatedAmount.toStringAsFixed(0)}',
                  ),
                  if ((request.paymentReference ?? '').trim().isNotEmpty)
                    _detail(
                      context,
                      Icons.tag_rounded,
                      'Payment reference',
                      request.paymentReference!.trim(),
                    ),
                  if (request.paymentSubmittedAt != null)
                    _detail(
                      context,
                      Icons.schedule_rounded,
                      'Submitted',
                      _dateTime(request.paymentSubmittedAt!),
                    ),
                  _detail(
                    context,
                    Icons.verified_outlined,
                    'Verification status',
                    _verificationLabel(request.paymentStatus),
                  ),
                  _detail(
                    context,
                    Icons.assignment_outlined,
                    'Booking status',
                    request.status.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking',
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: true,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detail(context, Icons.tag, 'Booking ID', request.id),
                  _detail(
                    context,
                    Icons.route_outlined,
                    'Route',
                    '${request.pickup} → ${request.destination}',
                  ),
                  if ((request.busName ?? '').trim().isNotEmpty)
                    _detail(
                      context,
                      Icons.directions_bus_outlined,
                      'Bus',
                      request.busName!.trim(),
                    ),
                  if ((request.customerName ?? '').trim().isNotEmpty)
                    _detail(
                      context,
                      Icons.person_outline_rounded,
                      'Customer',
                      request.customerName!.trim(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: BusGoTokens.blue),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Not provided' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _verificationLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return 'Payment verified';
      case PaymentStatus.submitted:
        return 'Awaiting Admin Verification';
      case PaymentStatus.rejected:
        return 'Payment rejected';
      case PaymentStatus.requested:
      case PaymentStatus.notRequested:
        return 'Not verified';
    }
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${_month(local.month)} ${local.year}, '
        '$hour:$minute $period';
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
