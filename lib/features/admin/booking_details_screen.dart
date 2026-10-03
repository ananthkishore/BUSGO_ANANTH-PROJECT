import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../models/booking_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../widgets/busgo_ui.dart';

class AdminBookingDetailsScreen extends StatefulWidget {
  const AdminBookingDetailsScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends State<AdminBookingDetailsScreen> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser?.role != AppUserRole.admin) {
      _showError('Only admins can review this booking.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<BookingRequestRepository>().adminAccept(
        request: widget.request,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking approved successfully')),
      );
      context.go('/admin');
    } catch (_) {
      if (mounted) _showError('The booking could not be accepted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser?.role != AppUserRole.admin) {
      _showError('Only admins can review this booking.');
      return;
    }
    final repository = context.read<BookingRequestRepository>();
    final reasonController = TextEditingController(
      text: 'Bus is unavailable for the selected dates.',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject booking?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason'),
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
    if (confirmed != true || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await repository.adminReject(request: widget.request, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected successfully.')),
        );
        context.go('/admin');
      }
    } catch (_) {
      if (mounted) _showError('The booking could not be rejected.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPayment() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<BookingRequestRepository>().markPaymentPaid(
        request: widget.request,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) _showError('Payment could not be verified.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final currentUserRole = context.watch<AuthProvider>().currentUser?.role;
    final isAdmin = currentUserRole == AppUserRole.admin;
    final waitingForAdminReview =
        request.status == BookingRequestStatus.ownerAccepted ||
        request.status == BookingRequestStatus.adminReview;
    final paymentRequired =
        request.status == BookingRequestStatus.paymentRequired;
    final paymentSubmitted = request.paymentStatus == PaymentStatus.submitted;
    final tripConfirmed = request.status == BookingRequestStatus.confirmed;
    final showingAdminReviewActions =
        isAdmin && request.status == BookingRequestStatus.ownerAccepted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: Booking details');
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
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.busName ?? 'Whole-bus booking',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      BusGoStatusChip(
                        label: request.status.label.toUpperCase(),
                        tone: waitingForAdminReview
                            ? BusGoStatusTone.warning
                            : tripConfirmed
                            ? BusGoStatusTone.positive
                            : paymentRequired
                            ? BusGoStatusTone.info
                            : BusGoStatusTone.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Customer: ${request.customerName ?? request.customerId}',
                  ),
                  Text('Owner: ${request.ownerId}'),
                  const SizedBox(height: 10),
                  Text(
                    '${request.pickup}  to  ${request.destination}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_date(request.startDate)} - ${_date(request.endDate)}',
                  ),
                  Text(
                    '${request.passengerCount} people  •  ${request.tripType}',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Amount: ₹${request.estimatedAmount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BusGoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operations timeline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  BusGoTimeline(
                    steps: const [
                      'Customer request',
                      'Owner accepted',
                      'Admin review',
                      'Payment',
                      'Confirmed',
                      'Completed',
                    ],
                    activeIndex: _activeIndex,
                  ),
                ],
              ),
            ),
            if (waitingForAdminReview) ...[
              const SizedBox(height: 20),
              BusGoSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  request.status == BookingRequestStatus.ownerAccepted
                      ? 'Waiting for Admin Review'
                      : 'Waiting for Admin Approval',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ] else if (paymentRequired) ...[
              const SizedBox(height: 20),
              BusGoSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Payment Pending',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ] else if (tripConfirmed) ...[
              const SizedBox(height: 20),
              BusGoSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Trip Confirmed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            if (showingAdminReviewActions) ...[
              const SizedBox(height: 20),
              BusGoSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Review Required',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              BusGoPrimaryButton(
                label: _busy ? 'Accepting...' : 'Accept',
                icon: Icons.check_rounded,
                loading: _busy,
                onPressed: _busy ? null : _accept,
              ),
              const SizedBox(height: 10),
              BusGoSecondaryButton(
                label: _busy ? 'Processing...' : 'Reject',
                icon: Icons.close_rounded,
                onPressed: _busy ? null : _reject,
              ),
            ] else if (waitingForAdminReview) ...[
              const SizedBox(height: 20),
              BusGoSurface(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Waiting for Admin Review',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ] else if (paymentSubmitted) ...[
              const SizedBox(height: 20),
              BusGoPrimaryButton(
                label: _busy ? 'Verifying...' : 'Verify Payment',
                icon: Icons.payments_rounded,
                loading: _busy,
                onPressed: _busy ? null : _verifyPayment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  int get _activeIndex {
    switch (widget.request.status) {
      case BookingRequestStatus.pendingOwner:
        return 1;
      case BookingRequestStatus.ownerAccepted:
      case BookingRequestStatus.adminReview:
        return 2;
      case BookingRequestStatus.paymentRequired:
        return 3;
      case BookingRequestStatus.confirmed:
        return 4;
      case BookingRequestStatus.completed:
        return 5;
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
      case BookingRequestStatus.cancelled:
        return 1;
    }
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}
