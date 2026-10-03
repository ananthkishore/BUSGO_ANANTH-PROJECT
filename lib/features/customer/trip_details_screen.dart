import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../models/booking_request_model.dart';
import '../../repositories/booking_request_repository.dart';
import '../../widgets/busgo_ui.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  late BookingRequestModel _request = widget.request;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _loadLatestRequest();
  }

  Future<void> _loadLatestRequest() async {
    try {
      final repository = context.read<BookingRequestRepository>();
      final latest = await repository.getById(widget.request.id);
      final resolved = latest ?? widget.request;
      final synced = await repository.ensureLifecycleState(request: resolved);
      if (!mounted) return;
      setState(() {
        _request = synced;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _request = widget.request);
    }
  }

  bool get _isTripCompleted =>
      _request.status == BookingRequestStatus.completed ||
      BookingRequestRepository.shouldCompleteTrip(_request);

  bool get _canReview => _isTripCompleted && !_isReviewSubmitted;

  bool get _isReviewSubmitted => _request.hasSubmittedReview;

  int get _timelineDoneCount {
    if (_isReviewSubmitted) return 7;
    if (_request.status == BookingRequestStatus.completed) return 6;
    if (BookingRequestRepository.shouldCompleteTrip(_request)) return 6;
    switch (_request.status) {
      case BookingRequestStatus.pendingOwner:
        return 1;
      case BookingRequestStatus.ownerAccepted:
      case BookingRequestStatus.adminReview:
        return 2;
      case BookingRequestStatus.paymentRequired:
        return _request.paymentStatus == PaymentStatus.paid ||
                _request.paymentStatus == PaymentStatus.submitted
            ? 4
            : 3;
      case BookingRequestStatus.confirmed:
        return 5;
      case BookingRequestStatus.completed:
        return 6;
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
      case BookingRequestStatus.cancelled:
        return 1;
    }
  }

  int? get _currentTimelineIndex {
    if (_isReviewSubmitted) return null;
    if (_request.status == BookingRequestStatus.completed) return 6;
    if (BookingRequestRepository.shouldCompleteTrip(_request)) return 5;
    switch (_request.status) {
      case BookingRequestStatus.pendingOwner:
        return 0;
      case BookingRequestStatus.ownerAccepted:
        return 1;
      case BookingRequestStatus.adminReview:
        return 2;
      case BookingRequestStatus.paymentRequired:
        return 3;
      case BookingRequestStatus.confirmed:
        return 5;
      case BookingRequestStatus.completed:
        return 6;
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
      case BookingRequestStatus.cancelled:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final paymentButtonVisible =
        request.status == BookingRequestStatus.paymentRequired &&
        request.paymentStatus != PaymentStatus.submitted &&
        request.paymentStatus != PaymentStatus.paid;
    final paymentCardVisible =
        request.paymentStatus == PaymentStatus.submitted ||
        request.paymentStatus == PaymentStatus.paid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: Trip details');
            debugPrint('previousScreen: previous screen');
            debugPrint('navigationType: ${context.canPop() ? 'pop' : 'no-op'}');
            debugPrint('canPop: ${context.canPop()}');
            debugPrint('[/BUSGO BACK NAVIGATION]');
            if (context.canPop()) {
              context.pop();
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SummaryCard(
              request: request,
              statusTone: _tone,
              statusLabel: request.status.label.toUpperCase(),
            ),
            const SizedBox(height: 16),
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timeline_rounded,
                        size: 18,
                        color: BusGoTokens.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Booking timeline',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTimeline(),
                ],
              ),
            ),
            if (request.specialRequirements.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              BusGoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sticky_note_2_outlined,
                          color: BusGoTokens.blue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Additional requirements',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3EBF8)),
                      ),
                      child: Text(
                        request.specialRequirements,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: BusGoTokens.navy,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (paymentCardVisible) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: request.paymentStatus == PaymentStatus.submitted
                      ? const Color(0xFFEAF6FF)
                      : const Color(0xFFEAFBF2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: request.paymentStatus == PaymentStatus.submitted
                        ? const Color(0xFFBFDBFE)
                        : const Color(0xFFCAF0D8),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: request.paymentStatus == PaymentStatus.submitted
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF1CA76A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        request.paymentStatus == PaymentStatus.submitted
                            ? Icons.pending_actions_rounded
                            : Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.paymentStatus == PaymentStatus.submitted
                                ? 'Payment Submitted'
                                : 'Payment Verified',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color:
                                      request.paymentStatus ==
                                          PaymentStatus.submitted
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF0E7A52),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            request.paymentStatus == PaymentStatus.submitted
                                ? 'Awaiting Admin Verification\nAdmin will verify your payment within 24 hours.'
                                : 'Your payment has been verified and your booking is confirmed.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color:
                                      request.paymentStatus ==
                                          PaymentStatus.submitted
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF2E7D5B),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (paymentButtonVisible) ...[
              const SizedBox(height: 16),
              BusGoPrimaryButton(
                label: 'Pay Now',
                icon: Icons.lock_rounded,
                onPressed: () =>
                    context.push('/customer/payment', extra: request),
              ),
            ],
            if (_canReview) ...[
              const SizedBox(height: 16),
              BusGoPrimaryButton(
                label: 'Rate & Review',
                icon: Icons.star_rounded,
                onPressed: _showReviewDialog,
              ),
            ],
            if (_isReviewSubmitted) ...[
              const SizedBox(height: 16),
              BusGoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF5B642),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Review',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F7EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '✓ Submitted',
                            style: TextStyle(
                              color: Color(0xFF0B7A4F),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your review',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        final active = index < (_request.reviewRating ?? 0);
                        return Icon(
                          active
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: active
                              ? const Color(0xFFF5B642)
                              : const Color(0xFFCBD5E1),
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    if ((_request.reviewFeedback ?? '').trim().isNotEmpty) ...[
                      Text(
                        _request.reviewFeedback ?? '',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: BusGoTokens.navy,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Thanks for giving feedback!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BusGoTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showReviewDialog() async {
    if (!_canReview) return;
    final controller = TextEditingController();
    var rating = 5;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate & Review'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How was your trip?'),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        final active = starNumber <= rating;
                        return Expanded(
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: isSubmitting
                                ? null
                                : () =>
                                      setDialogState(() => rating = starNumber),
                            icon: Icon(
                              active
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: active ? Colors.amber : BusGoTokens.muted,
                              size: 28,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      enabled: !isSubmitting,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Feedback',
                        hintText: 'Tell us about your journey',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDialogState(() => isSubmitting = true);
                          Navigator.of(dialogContext).pop(true);
                        },
                  child: isSubmitting
                      ? const Text('Submitting review...')
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    try {
      final repository = context.read<BookingRequestRepository>();
      await repository.submitReview(
        request: _request,
        rating: rating,
        feedback: controller.text,
      );
      final refreshed = await repository.getById(_request.id);
      if (!mounted) return;
      setState(() {
        _request =
            refreshed ??
            _request.copyWith(
              reviewRating: rating,
              reviewFeedback: controller.text.trim(),
              reviewSubmittedAt: DateTime.now(),
            );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for giving feedback!')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'Unable to submit review right now.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      controller.dispose();
    }
  }

  Widget _buildTimeline() {
    const steps = [
      'Request sent',
      'Owner accepted',
      'Admin confirmed',
      'Payment',
      'Booking confirmed',
      'Trip completed',
      'Review',
    ];
    final doneCount = _timelineDoneCount;
    final currentIndex = _currentTimelineIndex;

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineRow(
            label: steps[index],
            isDone: index < doneCount,
            isCurrent: currentIndex == index,
            isLast: index == steps.length - 1,
            timestamp: _timelineTimestamp(index),
          ),
      ],
    );
  }

  DateTime? _timelineTimestamp(int index) {
    switch (index) {
      case 0:
        return _request.createdAt;
      case 1:
        return _request.updatedAt;
      case 2:
        return _request.updatedAt;
      case 3:
        return _request.paymentSubmittedAt ?? _request.paymentRequestedAt;
      case 4:
        return _request.paymentSubmittedAt ?? _request.updatedAt;
      case 5:
        return _request.status == BookingRequestStatus.completed
            ? _request.updatedAt
            : null;
      case 6:
        return _request.reviewSubmittedAt;
      default:
        return null;
    }
  }

  BusGoStatusTone get _tone {
    switch (_request.status) {
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
      case BookingRequestStatus.cancelled:
        return BusGoStatusTone.negative;
      case BookingRequestStatus.completed:
      case BookingRequestStatus.confirmed:
        return BusGoStatusTone.positive;
      case BookingRequestStatus.paymentRequired:
        return BusGoStatusTone.warning;
      case BookingRequestStatus.pendingOwner:
      case BookingRequestStatus.ownerAccepted:
      case BookingRequestStatus.adminReview:
        return BusGoStatusTone.info;
    }
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    required this.timestamp,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final circleColor = isDone
        ? const Color(0xFF1C9A66)
        : isCurrent
        ? BusGoTokens.blue
        : const Color(0xFFCDD6E4);
    final lineColor = isDone || isCurrent
        ? BusGoTokens.blue.withValues(alpha: 0.35)
        : const Color(0xFFCDD6E4);
    final textColor = isDone || isCurrent
        ? BusGoTokens.navy
        : BusGoTokens.muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isDone ? circleColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleColor, width: 2),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : isCurrent
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: BusGoTokens.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: lineColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: textColor),
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      _formatTimelineDate(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimelineDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.request,
    required this.statusTone,
    required this.statusLabel,
  });

  final BookingRequestModel request;
  final BusGoStatusTone statusTone;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final busName = request.busName ?? 'Whole-bus trip';
    final total = request.estimatedAmount > 0
        ? '₹${request.estimatedAmount.toStringAsFixed(0)}'
        : '₹0';

    return BusGoSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 168,
              width: double.infinity,
              child: Stack(
                children: [
                  const BusGoBusImage(
                    imageUrl: null,
                    height: 168,
                    borderRadius: 0,
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: BusGoStatusChip(
                      label: statusLabel,
                      tone: statusTone,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(busName, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: BusGoTokens.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${request.pickup} to ${request.destination}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: Icons.people_alt_rounded,
                      label: '${request.passengerCount} people',
                    ),
                    _InfoPill(
                      icon: Icons.event_rounded,
                      label: request.tripType,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3EBF8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated total',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip date',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_date(request.startDate)} - ${_date(request.endDate)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: BusGoTokens.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
