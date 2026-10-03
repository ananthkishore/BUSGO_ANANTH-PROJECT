import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/booking_status.dart';
import '../../models/booking_request_model.dart';
import '../../models/bus_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../widgets/busgo_ui.dart';

class RequestTripScreen extends StatefulWidget {
  const RequestTripScreen({super.key, required this.bus});

  final BusModel bus;

  @override
  State<RequestTripScreen> createState() => _RequestTripScreenState();
}

class _RequestTripScreenState extends State<RequestTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _passengersController = TextEditingController();
  final _requirementsController = TextEditingController();
  String _tripType = 'College Tour';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  static const _tripTypes = [
    'College Tour',
    'Corporate Trip',
    'Wedding',
    'Family Trip',
    'School Trip',
    'Tourist Trip',
    'Festival',
    'Event',
    'Other',
  ];

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _passengersController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) _endDate = null;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() ||
        _startDate == null ||
        _endDate == null) {
      setState(() {});
      return;
    }
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    debugPrint('[BUSGO FIRESTORE DEBUG] Customer Firebase UID: ${user.uid}');
    debugPrint('[BUSGO FIRESTORE DEBUG] Customer role: ${user.role.name}');
    debugPrint(
      '[BUSGO FIRESTORE DEBUG] Selected bus: ${widget.bus.id}, busOwnerUid: ${widget.bus.ownerId}, busStatus: ${widget.bus.status}',
    );

    setState(() => _isSubmitting = true);
    try {
      final request = BookingRequestModel(
        id: '',
        customerId: user.uid,
        customerName: user.name,
        ownerId: widget.bus.ownerId,
        busId: widget.bus.id,
        busName: widget.bus.name,
        pickup: _pickupController.text.trim(),
        destination: _destinationController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        passengerCount: int.parse(_passengersController.text),
        tripType: _tripType,
        specialRequirements: _requirementsController.text.trim(),
        estimatedAmount:
            (widget.bus.estimatedPricePerDay ?? 0) *
            (_endDate!.difference(_startDate!).inDays + 1),
        status: BookingRequestStatus.pendingOwner,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final repository = context.read<BookingRequestRepository>();
      final existingRequest = await repository.findExistingActiveRequest(
        request,
      );
      if (existingRequest != null) {
        debugPrint(
          '[BOOKING] Existing active request already exists for this trip: ${existingRequest.id}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request already sent.')),
          );
          context.go('/customer/request-sent');
        }
        return;
      }

      final requestId = await repository.createRequest(request);
      debugPrint('[BOOKING] Request created successfully');
      debugPrint('[BOOKING] requestId = $requestId');
      if (mounted) context.go('/customer/request-sent');
    } catch (error) {
      debugPrint('[BOOKING] creation failed = $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is Exception
                ? error.toString().replaceFirst('Exception: ', '')
                : 'Unable to send your request. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request this whole bus'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: Request this whole bus');
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              BusGoSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BusGoBusImage(
                      imageUrl: widget.bus.imageUrl,
                      height: 150,
                      borderRadius: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: BusGoStatusChip(
                        label: 'WHOLE-BUS BOOKING',
                        tone: BusGoStatusTone.info,
                        icon: Icons.directions_bus_filled_rounded,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request this whole bus',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.bus.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.bus.busType} | capacity ${widget.bus.capacity}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: [
                              BusGoPill(
                                label: widget.bus.isAc ? 'AC' : 'Non-AC',
                                icon: Icons.ac_unit_rounded,
                              ),
                              BusGoPill(
                                label: widget.bus.serviceLocation,
                                icon: Icons.location_on_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Trip details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pickupController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Pickup location',
                  prefixIcon: Icon(Icons.trip_origin_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _destinationController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      label: 'Travel date',
                      date: _startDate,
                      onTap: () => _chooseDate(start: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateButton(
                      label: 'Return date',
                      date: _endDate,
                      onTap: () => _chooseDate(start: false),
                    ),
                  ),
                ],
              ),
              if (_startDate == null || _endDate == null)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    'Choose both travel dates',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passengersController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  if (count == null || count <= 0) {
                    return 'Enter the approximate passenger count';
                  }
                  if (count > widget.bus.capacity) {
                    return 'This exceeds the bus capacity';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Approximate passengers',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tripType,
                decoration: const InputDecoration(
                  labelText: 'Trip type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final type in _tripTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) =>
                    setState(() => _tripType = value ?? _tripType),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _requirementsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Special requirements (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              BusGoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The owner reviews your request first. BUSGO confirms availability only after owner acceptance.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimated cost: ${_estimatedLabel()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BusGoPrimaryButton(
                onPressed: _isSubmitting ? null : _submit,
                icon: Icons.send_rounded,
                loading: _isSubmitting,
                label: 'Send Booking Request',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_rounded),
    label: Text(
      date == null ? label : '${date.day}/${date.month}/${date.year}',
    ),
  );

  String _estimatedLabel() {
    if (_startDate == null ||
        _endDate == null ||
        widget.bus.estimatedPricePerDay == null) {
      return 'To be confirmed';
    }
    final days = _endDate!.difference(_startDate!).inDays + 1;
    return '${widget.bus.estimatedPricePerDay! * days}';
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
}
