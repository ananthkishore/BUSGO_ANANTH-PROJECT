import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/payment_status.dart';
import '../../models/booking_request_model.dart';
import '../../repositories/booking_request_repository.dart';
import '../../widgets/busgo_ui.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _referenceController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingState = true;
  late BookingRequestModel _request = widget.request;

  @override
  void initState() {
    super.initState();
    _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    try {
      final latest = await context.read<BookingRequestRepository>().getById(
        widget.request.id,
      );
      if (!mounted) return;
      setState(() {
        _request = latest ?? widget.request;
        _isLoadingState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingState = false);
    }
  }

  bool get _paymentAlreadyCompleted =>
      _request.paymentStatus == PaymentStatus.submitted ||
      _request.paymentStatus == PaymentStatus.paid;

  bool get _paymentAwaitingVerification =>
      _request.paymentStatus == PaymentStatus.submitted;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _paymentAlreadyCompleted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment already submitted. Awaiting Admin verification.',
          ),
        ),
      );
      return;
    }
    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your UTR or transaction reference.'),
        ),
      );
      return;
    }

    final repository = context.read<BookingRequestRepository>();
    try {
      final latest = await repository.getById(widget.request.id);
      final isAlreadyPaid =
          latest?.paymentStatus == PaymentStatus.submitted ||
          latest?.paymentStatus == PaymentStatus.paid;
      if (isAlreadyPaid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment already submitted. Awaiting Admin verification.',
            ),
          ),
        );
        setState(() => _request = latest ?? _request);
        return;
      }
    } catch (_) {
      // fall through to the existing payment flow below
    }

    setState(() => _isSubmitting = true);
    try {
      await repository.submitPayment(
        request: _request,
        paymentReference: reference,
      );
      if (!mounted) return;
      final updatedRequest =
          await repository.getById(_request.id) ??
          _request.copyWith(
            paymentStatus: PaymentStatus.submitted,
            paymentReference: reference,
          );
      setState(() {
        _request = updatedRequest;
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment submitted successfully.\nAdmin will verify your payment within 24 hours.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.contains('already submitted') ||
                    message.contains('Awaiting Admin verification')
                ? 'Payment already submitted. Awaiting Admin verification.'
                : 'Payment could not be completed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: Payment');
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
                  BusGoStatusChip(
                    label: 'PAYMENT REQUIRED',
                    tone: BusGoStatusTone.warning,
                    icon: Icons.lock_clock_rounded,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    request.busName ?? 'Whole-bus booking',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('${request.pickup}  to  ${request.destination}'),
                  Text(
                    '${_date(request.startDate)} - ${_date(request.endDate)}',
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount due',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '₹${request.estimatedAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
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
                    'Payment reference',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete payment using the BUSGO payment instructions, then enter the UTR or transaction reference below.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _referenceController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'UTR / transaction reference',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoadingState) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_paymentAwaitingVerification) ...[
              BusGoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Submitted',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Awaiting Admin Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment submitted successfully.\nAdmin will verify your payment within 24 hours.',
                    ),
                    const SizedBox(height: 12),
                    if ((_request.paymentReference ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      Text('Reference: ${_request.paymentReference!.trim()}'),
                    ],
                    if (_request.paymentSubmittedAt != null) ...[
                      Text(
                        'Submitted: ${_request.paymentSubmittedAt!.toLocal().toString()}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BusGoPrimaryButton(
                label: 'Awaiting Admin Verification',
                icon: Icons.check_circle_outline_rounded,
                onPressed: null,
              ),
            ] else if (_paymentAlreadyCompleted) ...[
              BusGoPrimaryButton(
                label: _request.paymentStatus == PaymentStatus.paid
                    ? 'Payment Verified'
                    : 'Payment Submitted',
                icon: Icons.check_rounded,
                onPressed: null,
              ),
            ] else ...[
              BusGoPrimaryButton(
                label: _isSubmitting ? 'Submitting payment...' : 'Pay Now',
                icon: Icons.lock_rounded,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}
