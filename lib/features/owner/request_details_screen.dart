import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../models/bus_model.dart';
import '../../models/booking_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../repositories/bus_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerRequestDetailsScreen extends StatefulWidget {
  const OwnerRequestDetailsScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  State<OwnerRequestDetailsScreen> createState() =>
      _OwnerRequestDetailsScreenState();
}

class _OwnerRequestDetailsScreenState extends State<OwnerRequestDetailsScreen> {
  bool _busy = false;
  bool _openingPaymentDetails = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<BookingRequestRepository>().ownerAccept(
        request: widget.request,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) _showError('The request could not be accepted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    final repository = context.read<BookingRequestRepository>();
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject request?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Bus unavailable, maintenance...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await repository.transitionStatus(
        requestId: widget.request.id,
        nextStatus: BookingRequestStatus.ownerRejected,
        rejectionReason: reason,
        ownerId: widget.request.ownerId,
        customerId: widget.request.customerId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) _showError('The request could not be rejected.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPaymentDetails() async {
    if (_openingPaymentDetails) return;
    setState(() => _openingPaymentDetails = true);
    try {
      await context.push('/payment-details', extra: widget.request);
    } finally {
      if (mounted) setState(() => _openingPaymentDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final actionable = request.status == BookingRequestStatus.pendingOwner;
    final owner = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      backgroundColor: BusGoTokens.canvas,
      body: SafeArea(
        child: StreamBuilder<List<BusModel>>(
          stream: context.read<BusRepository>().watchForOwner(request.ownerId),
          builder: (context, busSnapshot) {
            final bus = busSnapshot.data
                ?.where((item) => item.id == request.busId)
                .firstOrNull;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: BusGoTokens.navy,
                    ),
                    const SizedBox(width: 2),
                    Expanded(child: BusGoBrandMark(compact: true)),
                    BusGoProfileAvatar(
                      imageUrl: owner?.profileImageUrl,
                      size: 38,
                      label: _initial(owner?.name),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Trip Details',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete information about this trip',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: BusGoTokens.muted),
                ),
                const SizedBox(height: 18),
                _tripOverview(request),
                const SizedBox(height: 14),
                _customerInformation(request),
                const SizedBox(height: 14),
                _busInformation(request, bus, busSnapshot),
                const SizedBox(height: 14),
                _timeline(request),
                const SizedBox(height: 14),
                _paymentInformation(request),
                if (request.hasSubmittedReview) ...[
                  const SizedBox(height: 14),
                  _reviewInformation(request),
                ],
                if (request.specialRequirements.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _requirements(request.specialRequirements),
                ],
                if (actionable) ...[
                  const SizedBox(height: 18),
                  BusGoPrimaryButton(
                    label: _busy ? 'Accepting...' : 'Accept Request',
                    icon: Icons.check_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _accept,
                  ),
                  const SizedBox(height: 10),
                  BusGoSecondaryButton(
                    label: _busy ? 'Processing...' : 'Reject Request',
                    icon: Icons.close_rounded,
                    onPressed: _busy ? null : _reject,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tripOverview(BookingRequestModel request) {
    return BusGoSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_fallback(request.pickup, 'Pickup')} → ${_fallback(request.destination, 'Destination')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              BusGoStatusChip(
                label: request.status.label,
                tone: _statusTone(request.status),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${_date(request.startDate)}  |  ${_time(request.startDate)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BusGoTokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _overviewMetric(
                  Icons.groups_2_outlined,
                  '${request.passengerCount}',
                  'Passengers',
                ),
              ),
              Expanded(
                child: _overviewMetric(
                  Icons.business_center_outlined,
                  _fallback(request.tripType, 'Whole-bus trip'),
                  'Trip Type',
                ),
              ),
              Expanded(
                child: _overviewMetric(
                  Icons.currency_rupee_rounded,
                  '₹${request.estimatedAmount.toStringAsFixed(0)}',
                  'Total Amount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric(IconData icon, String value, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2ECF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BusGoTokens.blue, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BusGoTokens.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerInformation(BookingRequestModel request) {
    final name = (request.customerName ?? '').trim();
    return BusGoSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.person_outline_rounded, 'Customer Information'),
          const Divider(height: 20),
          _detailLine(
            Icons.person_outline_rounded,
            name.isEmpty ? 'Customer name unavailable' : name,
          ),
          const SizedBox(height: 9),
          _detailLine(Icons.phone_outlined, 'Phone not available'),
          const SizedBox(height: 9),
          _detailLine(Icons.email_outlined, 'Email not available'),
        ],
      ),
    );
  }

  Widget _busInformation(
    BookingRequestModel request,
    BusModel? bus,
    AsyncSnapshot<List<BusModel>> snapshot,
  ) {
    final busName = (request.busName ?? '').trim();
    if (snapshot.connectionState == ConnectionState.waiting && bus == null) {
      return const BusGoLoadingState(label: 'Loading bus information...');
    }
    return BusGoSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.directions_bus_outlined, 'Bus Information'),
          const SizedBox(height: 12),
          if (bus == null)
            _detailLine(
              Icons.info_outline_rounded,
              busName.isEmpty ? 'Bus information unavailable' : busName,
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 82,
                  child: BusGoBusImage(
                    imageUrl: bus.imageUrl,
                    height: 82,
                    borderRadius: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fallback(
                          bus.registrationNumber,
                          'Registration unavailable',
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: BusGoTokens.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(_fallback(bus.name, 'Bus model unavailable')),
                      const SizedBox(height: 4),
                      Text(
                        '${bus.capacity} Seats  |  ${bus.isAc ? 'AC' : 'Non-AC'}  |  ${_fallback(bus.busType, 'Bus')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BusGoTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _timeline(BookingRequestModel request) {
    final paymentDate = request.paymentSubmittedAt;
    final events = <(String, DateTime)>[
      ('Booking Request Received', request.createdAt),
    ];
    if (request.ownerDecision == 'ACCEPTED' ||
        request.status != BookingRequestStatus.pendingOwner) {
      events.add(('Trip Accepted', request.updatedAt));
    }
    if (request.paymentStatus == PaymentStatus.paid && paymentDate != null) {
      events.add(('Payment Received', paymentDate));
    }
    if (request.status == BookingRequestStatus.completed) {
      events.add(('Trip Completed', request.updatedAt));
    }

    return BusGoSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.schedule_rounded, 'Trip Timeline'),
          const SizedBox(height: 12),
          for (var index = 0; index < events.length; index++)
            _timelineEvent(
              title: events[index].$1,
              date: events[index].$2,
              isLast: index == events.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _timelineEvent({
    required String title,
    required DateTime date,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xFFDDF7EA),
                child: Icon(
                  Icons.check_rounded,
                  color: Color(0xFF0A9F6E),
                  size: 15,
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 28, color: const Color(0xFFB7E8D0)),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_date(date)}  ${_time(date)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentInformation(BookingRequestModel request) {
    final paymentReference = (request.paymentReference ?? '').trim();
    return InkWell(
      onTap: _openingPaymentDetails ? null : _openPaymentDetails,
      borderRadius: BorderRadius.circular(18),
      child: BusGoSurface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _iconBox(Icons.credit_card_outlined, BusGoTokens.blue),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹${request.estimatedAmount.toStringAsFixed(0)}  ·  ${request.paymentStatus.label}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                  ),
                  if (paymentReference.isNotEmpty)
                    Text(
                      'Reference: $paymentReference',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                    ),
                  if (request.paymentStatus == PaymentStatus.submitted)
                    Text(
                      'Awaiting admin verification',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (request.paymentStatus == PaymentStatus.paid)
                    Text(
                      'Payment verified · Booking confirmed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF0A9F6E),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (request.paymentSubmittedAt != null)
                    Text(
                      'Submitted: ${_date(request.paymentSubmittedAt!)} ${_time(request.paymentSubmittedAt!)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                    ),
                ],
              ),
            ),
            _openingPaymentDetails
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: BusGoTokens.blue,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _reviewInformation(BookingRequestModel request) {
    final feedback = (request.reviewFeedback ?? '').trim();
    final submittedAt = request.reviewSubmittedAt;
    return BusGoSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.rate_review_outlined, 'Customer Feedback'),
          const SizedBox(height: 12),
          if (request.reviewRating != null)
            _detailLine(
              Icons.star_rounded,
              'Rating: ${request.reviewRating} / 5',
            ),
          if (feedback.isNotEmpty) ...[
            if (request.reviewRating != null) const SizedBox(height: 9),
            _detailLine(Icons.chat_bubble_outline_rounded, feedback),
          ],
          if (submittedAt != null) ...[
            const SizedBox(height: 9),
            _detailLine(
              Icons.schedule_rounded,
              'Submitted: ${_date(submittedAt)} ${_time(submittedAt)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _requirements(String requirements) {
    return BusGoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.notes_rounded, 'Trip Requirements'),
          const SizedBox(height: 10),
          Text(requirements),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        _iconBox(icon, BusGoTokens.blue),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detailLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: BusGoTokens.blue, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BusGoTokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  BusGoStatusTone _statusTone(BookingRequestStatus status) {
    switch (status) {
      case BookingRequestStatus.completed:
        return BusGoStatusTone.positive;
      case BookingRequestStatus.cancelled:
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
        return BusGoStatusTone.negative;
      case BookingRequestStatus.pendingOwner:
        return BusGoStatusTone.warning;
      default:
        return BusGoStatusTone.info;
    }
  }

  String _fallback(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  String _initial(String? name) {
    final value = (name ?? '').trim();
    return value.isEmpty ? 'O' : value.substring(0, 1).toUpperCase();
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}
