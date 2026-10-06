import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_roles.dart';
import '../../core/constants/booking_status.dart';
import '../../models/booking_request_model.dart';
import '../../models/bus_search_query.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/busgo_ui.dart';
import '../../app/theme.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  int _selectedIndex = 0;
  _TripListFilter _tripFilter = _TripListFilter.all;
  _NotificationFilter _notificationFilter = _NotificationFilter.all;
  int _notificationRetrySeed = 0;
  final _searchFormKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _passengersController = TextEditingController();
  DateTime? _travelDate;
  DateTime? _returnDate;
  String _tripType = 'College Tour';

  static const _tripTypes = [
    'College Tour',
    'Corporate Trip',
    'School Trip',
    'Wedding',
    'Family Trip',
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
    super.dispose();
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route_rounded),
      label: 'My trips',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_none_rounded),
      selectedIcon: Icon(Icons.notifications_rounded),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BusGoAdaptiveScaffold(
      body: _selectedPage(),
      selectedIndex: _selectedIndex,
      items: _destinations,
      onSelected: (index) => setState(() => _selectedIndex = index),
    );
  }

  Widget _selectedPage() {
    switch (_selectedIndex) {
      case 1:
        return _trips();
      case 2:
        return _notifications();
      case 3:
        return _profile();
      case 0:
      default:
        return _home();
    }
  }

  Widget _home() {
    final authProvider = context.watch<AuthProvider>();
    final displayName = _safeCustomerFirstName(authProvider.currentUser?.name);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _customerHeader(displayName),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroCard(displayName),
                  const SizedBox(height: 18),
                  _searchHero(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Popular for You',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedIndex = 1),
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _popularTrips(),
                  const SizedBox(height: 18),
                  _promoCard(),
                  const SizedBox(height: 18),
                  _nextTrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeCustomerFirstName(String? fullName) {
    final cleaned = (fullName ?? '').trim();
    if (cleaned.isEmpty) return 'Customer';
    final first = cleaned
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .firstOrNull;
    return first == null || first.isEmpty ? 'Customer' : first;
  }

  Widget _customerHeader(String name) {
    final authProvider = context.watch<AuthProvider>();
    final profileLabel = name.isEmpty || name == 'Customer'
        ? 'C'
        : name[0].toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BusGoBrandMark(compact: true),
              const SizedBox(height: 6),
              Text(
                'Travel Together, Go Further',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _selectedIndex = 2),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Alerts',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEAF8F8),
            foregroundColor: BusGoTokens.blue,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _selectedIndex = 3),
          child: BusGoProfileAvatar(
            imageUrl: authProvider.currentUser?.profileImageUrl,
            size: 42,
            label: profileLabel,
          ),
        ),
      ],
    );
  }

  Widget _heroCard(String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [colorScheme.surfaceContainer, colorScheme.surfaceContainerHigh]
              : const [Color(0xFFEAFBFB), Color(0xFFF7FBFF)],
        ),
        border: Border.all(
          color: BusGoTokens.teal,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $name,',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan Your\nNext Trip',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Book entire buses for festivals,\ncolleges, companies and more.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 8,
                  right: 18,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD38A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Container(
                    width: 110,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8DDE8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 108,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFEFF0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 18,
                  right: 12,
                  child: Container(
                    width: 58,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7C82),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 26,
                  child: Container(
                    width: 44,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.terrain_rounded,
                      color: BusGoTokens.blue,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _popularTrips() {
    final categories = [
      ('Festival Trips', Icons.celebration_rounded, 'Festival'),
      ('College Trips', Icons.school_rounded, 'College'),
      ('Company Trips', Icons.business_center_rounded, 'Corporate'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final category in categories)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _tripType = category.$3);
              final query = BusSearchQuery(
                pickup: _pickupController.text.trim(),
                destination: _destinationController.text.trim(),
                travelDate: _travelDate ?? DateTime.now(),
                returnDate: _returnDate,
                passengerCount: int.tryParse(_passengersController.text) ?? 1,
                tripType: category.$3,
              );
              context.push('/customer/search', extra: query);
            },
            child: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A102C4A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.$2, color: BusGoTokens.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.$1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _promoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0F2747), Color(0xFF0A7C82)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel Together',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make Better Memories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Safe • Comfortable • Affordable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.directions_bus_filled_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextTrip() {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<List<BookingRequestModel>>(
      stream: context.read<BookingRequestRepository>().watchForCustomer(
        user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BusGoErrorState(
            title: "Couldn't load your next trip",
            message: 'Please check your connection and try again.',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const BusGoLoadingState(label: 'Checking your trips...');
        }
        final upcoming =
            (snapshot.data ?? const <BookingRequestModel>[])
                .where(
                  (request) =>
                      request.endDate.isAfter(DateTime.now()) &&
                      request.status != BookingRequestStatus.cancelled &&
                      request.status != BookingRequestStatus.completed &&
                      request.status != BookingRequestStatus.ownerRejected &&
                      request.status != BookingRequestStatus.adminRejected,
                )
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));
        if (upcoming.isEmpty) {
          return BusGoEmptyState(
            icon: Icons.route_outlined,
            title: 'No upcoming trips',
            message: 'Plan your next journey with BUSGO.',
            actionLabel: 'Book a bus',
            onAction: () => context.push('/customer/search'),
          );
        }
        final request = upcoming.first;
        return _NextTripCard(
          request: request,
          onView: () => context.push('/customer/trip-details', extra: request),
        );
      },
    );
  }

  Widget _searchHero() {
    final userName = _safeCustomerFirstName(
      context.read<AuthProvider>().currentUser?.name,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BusGoTokens.teal),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _searchFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where are you heading, $userName?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Book an entire bus for your next group journey.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Whole-bus charter search',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pickupController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _searchDecoration(
                'From',
                'Select location',
                Icons.trip_origin_rounded,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a pickup location'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Swap pickup and destination',
                onPressed: _swapLocations,
                icon: const Icon(
                  Icons.swap_vert_rounded,
                  color: BusGoTokens.blue,
                ),
              ),
            ),
            const SizedBox(height: 2),
            TextFormField(
              controller: _destinationController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _searchDecoration(
                'To',
                'Select location',
                Icons.location_on_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a destination';
                }
                if (value.trim().toLowerCase() ==
                    _pickupController.text.trim().toLowerCase()) {
                  return 'Pickup and destination must be different';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth >= 360;
                final travelDate = _searchDateButton(
                  'Travel date',
                  _travelDate,
                  true,
                );
                final passengers = TextFormField(
                  controller: _passengersController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: _searchDecoration(
                    'Passengers',
                    'Select count',
                    Icons.groups_rounded,
                  ),
                  validator: (value) {
                    final passengerCount = int.tryParse(value ?? '');
                    return passengerCount == null || passengerCount <= 0
                        ? 'Enter passenger count'
                        : null;
                  },
                );

                return useRow
                    ? Row(
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: travelDate,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: passengers,
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          travelDate,
                          const SizedBox(height: 10),
                          passengers,
                        ],
                      );
              },
            ),
            const SizedBox(height: 10),
            _searchDateButton('Return date (optional)', _returnDate, false),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _tripTypes.contains(_tripType)
                  ? _tripType
                  : _tripTypes.first,
              dropdownColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              isExpanded: true,
              decoration: _searchDecoration(
                'Trip type',
                'Select trip type',
                Icons.category_outlined,
              ),
              items: [
                for (final type in _tripTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  setState(() => _tripType = value ?? _tripType),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _searchBuses,
                style: FilledButton.styleFrom(
                  backgroundColor: BusGoTokens.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'SEARCH WHOLE BUSES',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _searchDecoration(String label, String hint, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.primary),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: colorScheme.onSurface),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.primary,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    );
  }

  Widget _searchDateButton(String label, DateTime? date, bool isStart) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => _chooseSearchDate(isStart: isStart),
      icon: Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
      label: Text(
        date == null ? label : '${date.day}/${date.month}/${date.year}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurface),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant),
        backgroundColor: colorScheme.surfaceContainerHighest,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _chooseSearchDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: isStart
          ? (_travelDate ?? DateTime.now())
          : (_returnDate ?? _travelDate ?? DateTime.now()),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isStart) {
        _travelDate = date;
        final returnDate = _returnDate;
        if (returnDate != null && returnDate.isBefore(date)) {
          _returnDate = null;
        }
      } else {
        _returnDate = date;
      }
    });
  }

  void _searchBuses() {
    final formState = _searchFormKey.currentState;
    if (formState == null || !formState.validate()) return;
    final travelDate = _travelDate;
    if (travelDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a travel date')));
      return;
    }
    context.push(
      '/customer/search',
      extra: BusSearchQuery(
        pickup: _pickupController.text.trim(),
        destination: _destinationController.text.trim(),
        travelDate: travelDate,
        returnDate: _returnDate,
        passengerCount: int.parse(_passengersController.text),
        tripType: _tripType,
      ),
    );
  }

  void _swapLocations() {
    final pickup = _pickupController.text;
    _pickupController.text = _destinationController.text;
    _destinationController.text = pickup;
    setState(() {});
  }

  Widget _trips() {
    final user = context.watch<AuthProvider>().currentUser;
    return _pageScaffold(
      title: 'My Trips',
      subtitle: 'View and manage your trips',
      child: user == null
          ? const BusGoLoadingState(label: 'Preparing your trips...')
          : StreamBuilder<List<BookingRequestModel>>(
              stream: context.read<BookingRequestRepository>().watchForCustomer(
                user.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return BusGoErrorState(
                    title: "Couldn't load your trips",
                    message: 'Please check your connection and try again.',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const BusGoLoadingState(
                    label: 'Loading your trips...',
                  );
                }

                final requests = sortBookingRequestsByNewestFirst(
                  snapshot.data ?? const [],
                );
                if (requests.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BusGoEmptyState(
                        icon: Icons.route_outlined,
                        title: 'No trips yet',
                        message: 'Start your first whole-bus journey.',
                        actionLabel: 'Search Buses',
                      ),
                      const SizedBox(height: 18),
                      _planAnotherTripCard(),
                    ],
                  );
                }

                final filteredRequests = requests
                    .where(_tripFilter.matches)
                    .toList();
                if (filteredRequests.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BusGoEmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        title: 'No trips in this filter',
                        message:
                            'Try another trip status to view your bookings.',
                      ),
                      const SizedBox(height: 18),
                      _planAnotherTripCard(),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _TripListFilter.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final filter = _TripListFilter.values[index];
                          return ChoiceChip(
                            label: Text(filter.label),
                            selected: _tripFilter == filter,
                            onSelected: (_) =>
                                setState(() => _tripFilter = filter),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final request in filteredRequests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CustomerTripCard(
                          request: request,
                          onTap: () => context.push(
                            '/customer/trip-details',
                            extra: request,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _planAnotherTripCard(),
                  ],
                );
              },
            ),
    );
  }

  Widget _notifications() {
    final user = context.watch<AuthProvider>().currentUser;
    return _pageScaffold(
      title: 'Notifications',
      subtitle: 'Stay updated with your trips',
      child: user == null
          ? const BusGoLoadingState(label: 'Loading your alerts...')
          : StreamBuilder<List<NotificationModel>>(
              key: ValueKey('customer-notifications-$_notificationRetrySeed'),
              stream: context.read<NotificationRepository>().watchForUser(
                user.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return BusGoErrorState(
                    title: "Couldn't load your latest updates",
                    message: 'Please check your connection and try again.',
                    onRetry: () => setState(() => _notificationRetrySeed++),
                  );
                }
                if (!snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _notificationFilters(),
                      const SizedBox(height: 14),
                      const BusGoLoadingState(
                        label: 'Loading notifications...',
                      ),
                    ],
                  );
                }

                final notifications =
                    snapshot.data ?? const <NotificationModel>[];
                if (notifications.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _notificationFilters(),
                      const SizedBox(height: 14),
                      const BusGoEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message:
                            'Your trip and account updates will appear here.',
                      ),
                      const SizedBox(height: 18),
                      _promotionalAlertCard(),
                    ],
                  );
                }

                final filteredNotifications = notifications
                    .where(
                      (notification) =>
                          _notificationFilter.matches(notification.type),
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _notificationFilters(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: notifications.every((item) => item.isRead)
                            ? null
                            : () async {
                                await context
                                    .read<NotificationRepository>()
                                    .markAllAsRead(user.uid);
                              },
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Mark all as read'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (filteredNotifications.isEmpty)
                      const BusGoEmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        title: 'No alerts in this filter',
                        message: 'Try another type to view your updates.',
                      )
                    else ...[
                      for (final notification in filteredNotifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NotificationCard(
                            notification: notification,
                            onTap: () async {
                              debugPrint(
                                '[BUSGO NAV] Customer notification tapped: id=${notification.id} bookingId=${notification.relatedBookingId ?? 'null'} type=${notification.type}',
                              );
                              if (!notification.isRead) {
                                await context
                                    .read<NotificationRepository>()
                                    .markAsRead(notification.id);
                              }
                              await _openCustomerNotification(
                                notification,
                                user.uid,
                              );
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),
                    _promotionalAlertCard(),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _openCustomerNotification(
    NotificationModel notification,
    String customerId,
  ) async {
    final bookingId = notification.relatedBookingId?.trim();
    final busId = notification.relatedBusId?.trim();
    debugPrint('[BUSGO NOTIFICATION TAP]');
    debugPrint('notificationId: ${notification.id}');
    debugPrint('type: ${notification.type}');
    debugPrint('title: ${notification.title}');
    debugPrint('recipientId: $customerId');
    debugPrint('busId: ${busId ?? 'null'}');
    debugPrint('bookingId: ${bookingId ?? 'null'}');
    debugPrint('tripId: null');
    debugPrint('reviewId: null');
    debugPrint('destination: ${notification.type}');
    debugPrint('[/BUSGO NOTIFICATION TAP]');
    final conversationId = notification.conversationId?.trim();
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        (notification.type == 'support_reply' ||
            notification.type == 'customer_message' ||
            notification.type == 'owner_message')) {
      if (conversationId != customerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot access this support conversation.'),
          ),
        );
        return;
      }
      context.push('/support/$conversationId');
      return;
    }
    if (bookingId != null && bookingId.isNotEmpty) {
      try {
        final request = await context.read<BookingRequestRepository>().getById(
          bookingId,
        );
        debugPrint('[BUSGO NOTIFICATION LOAD]');
        debugPrint('type: ${notification.type}');
        debugPrint('documentId: $bookingId');
        debugPrint('collection: booking_requests');
        debugPrint('exists: ${request != null}');
        debugPrint('result: ${request != null ? request.id : 'not_found'}');
        debugPrint('[/BUSGO NOTIFICATION LOAD]');
        if (!mounted) return;
        if (request != null && request.customerId == customerId) {
          final route = switch (request.status) {
            BookingRequestStatus.paymentRequired => '/customer/payment',
            BookingRequestStatus.confirmed => '/customer/trip-details',
            BookingRequestStatus.completed => '/customer/trip-details',
            _ => '/customer/trip-details',
          };
          debugPrint(
            '[BUSGO NAV] Customer notification opening $route for bookingId=$bookingId',
          );
          context.push(route, extra: request);
          return;
        }
        if (request != null && request.customerId != customerId) {
          debugPrint(
            '[BUSGO NAV] Customer notification rejected: bookingId=$bookingId is not for customerId=$customerId',
          );
        }
      } catch (error) {
        debugPrint('[BUSGO NOTIFICATION ERROR]');
        debugPrint('type: ${notification.type}');
        debugPrint('operation: load_booking');
        debugPrint('collection: booking_requests');
        debugPrint('documentId: $bookingId');
        debugPrint('errorCode: ${error.runtimeType}');
        debugPrint('errorMessage: $error');
        debugPrint('[/BUSGO NOTIFICATION ERROR]');
        debugPrint('[BUSGO NAV] Customer notification fetch failed: $error');
      }
    }

    if (!mounted) return;
    final normalized = notification.type.toLowerCase();
    if (normalized.contains('trip') ||
        normalized.contains('booking') ||
        normalized.contains('payment')) {
      setState(() => _selectedIndex = 1);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bookingId == null || bookingId.isEmpty
              ? 'This notification does not include a booking reference.'
              : 'This booking is no longer available to open.',
        ),
      ),
    );
  }

  Widget _profile() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    return _pageScaffold(
      title: 'My Profile',
      subtitle: 'Manage your account and preferences',
      child: authProvider.isLoading
          ? _profileLoadingState()
          : user == null
          ? BusGoErrorState(
              title: "Couldn't load your profile",
              message: 'Please check your connection and try again.',
              onRetry: () => context.go('/login'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _profileHero(),
                const SizedBox(height: 18),
                _profileCard(user),
                const SizedBox(height: 22),
                Text(
                  'Account & support',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _customerSettingTile(
                  title: 'Personal Information',
                  subtitle: 'Name, email and phone number',
                  icon: Icons.person_outline_rounded,
                  onTap: () => context.push('/edit-profile'),
                ),
                _customerSettingTile(
                  title: 'Notifications',
                  subtitle: 'View updates about your trips',
                  icon: Icons.notifications_none_rounded,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _customerSettingTile(
                  title: 'Help & Support',
                  subtitle: 'Answers about accounts and whole-bus trips',
                  icon: Icons.support_agent_rounded,
                  onTap: () => context.push('/help'),
                ),
                _customerSettingTile(
                  title: 'Settings',
                  subtitle: 'App settings, privacy and security',
                  icon: Icons.settings_outlined,
                  onTap: () => context.push('/settings'),
                ),
                _customerSettingTile(
                  title: 'My Trips',
                  subtitle: 'View your whole-bus booking history',
                  icon: Icons.route_outlined,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _customerSettingTile(
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  icon: Icons.lock_outline_rounded,
                  onTap: () => context.push('/change-password'),
                ),
                _customerSettingTile(
                  title: 'Terms & Conditions',
                  subtitle: 'Review BUSGO policies',
                  icon: Icons.description_outlined,
                  onTap: () => context.push('/legal/terms'),
                ),
                _customerSettingTile(
                  title: 'Cancellation Policy',
                  subtitle: 'Learn about booking cancellations',
                  icon: Icons.assignment_late_outlined,
                  onTap: () => context.push('/legal/cancellation'),
                ),
                _customerSettingTile(
                  title: 'Privacy Policy',
                  subtitle: 'How BUSGO handles your information',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => context.push('/legal/privacy'),
                ),
                _customerSettingTile(
                  title: 'About BUSGO',
                  subtitle: 'App information and platform overview',
                  icon: Icons.info_outline_rounded,
                  onTap: () => context.push('/legal/agreement'),
                ),
                const SizedBox(height: 12),
                _profilePromoCard(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: authProvider.isBusy
                        ? null
                        : () async {
                            await authProvider.signOut();
                            if (mounted) context.go('/login');
                          },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 156,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F2747), Color(0xFF0A7C82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white24,
                  size: 86,
                ),
              ),
            ),
            Container(color: const Color(0xFF061B2D).withValues(alpha: 0.48)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'BUSGO',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Travel Together, Go Further',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(AppUser user) {
    final name = user.name.trim().isEmpty ? 'Not provided' : user.name.trim();
    final email = user.email.trim().isEmpty ? 'Not provided' : user.email;
    final phoneValue = (user.phone ?? '').trim();
    final phone = phoneValue.isEmpty ? 'Not provided' : phoneValue;
    final avatarLabel = name.substring(0, 1).toUpperCase();

    return BusGoSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              BusGoProfileAvatar(
                imageUrl: user.profileImageUrl,
                size: 72,
                label: avatarLabel,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Account type: ${user.role.label}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BusGoTokens.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => context.push('/edit-profile'),
                icon: const Icon(Icons.edit_outlined),
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _profileDetailRow(Icons.email_outlined, email),
          const SizedBox(height: 10),
          _profileDetailRow(Icons.phone_outlined, phone),
        ],
      ),
    );
  }

  Widget _profileDetailRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _profilePromoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2747), Color(0xFF0A7C82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Travel Together',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Make Better Memories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for being a part of BUSGO!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.directions_bus_filled_rounded,
            color: Colors.white70,
            size: 52,
          ),
        ],
      ),
    );
  }

  Widget _profileLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 156,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEF5),
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        const SizedBox(height: 18),
        const BusGoLoadingState(label: 'Loading your profile...'),
      ],
    );
  }

  Widget _notificationFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _NotificationFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _NotificationFilter.values[index];
          return ChoiceChip(
            label: Text(filter.label),
            selected: _notificationFilter == filter,
            onSelected: (_) => setState(() => _notificationFilter = filter),
          );
        },
      ),
    );
  }

  Widget _promotionalAlertCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2747), Color(0xFF0A7C82)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Never Miss an Update',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get notified about your trips, payments and important updates.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.directions_bus_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BusGoSurface(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: onTap == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: onTap == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _planAnotherTripCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan Another Trip?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Book a whole bus for your next group journey.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: () => context.push('/customer/search'),
            style: FilledButton.styleFrom(
              backgroundColor: BusGoTokens.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Search Buses'),
          );

          if (!constraints.hasBoundedWidth || constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [description, const SizedBox(height: 12), action],
            );
          }

          return Row(
            children: [
              Expanded(child: description),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _pageScaffold({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final authProvider = context.watch<AuthProvider>();
    final name = _safeCustomerFirstName(authProvider.currentUser?.name);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _customerHeader(name),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SizedBox(width: double.infinity, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextTripCard extends StatelessWidget {
  const _NextTripCard({required this.request, required this.onView});

  final BookingRequestModel request;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final date = '${request.startDate.day} ${_month(request.startDate.month)}';
    return BusGoSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                color: BusGoTokens.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.busName ?? 'BUSGO trip',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TripPoint(label: request.pickup, alignEnd: false),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: BusGoTokens.blue,
                ),
              ),
              Expanded(
                child: _TripPoint(label: request.destination, alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text('$date • ${request.passengerCount} passengers'),
              const Spacer(),
              TextButton(onPressed: onView, child: const Text('View trip')),
            ],
          ),
        ],
      ),
    );
  }

  String _month(int value) => const [
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
  ][value - 1];
}

class _TripPoint extends StatelessWidget {
  const _TripPoint({required this.label, required this.alignEnd});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          alignEnd ? 'TO' : 'FROM',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _CustomerTripCard extends StatelessWidget {
  const _CustomerTripCard({required this.request, required this.onTap});

  final BookingRequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabelFor(request.status);
    final pickup = request.pickup.trim().isEmpty ? 'Pickup' : request.pickup;
    final destination = request.destination.trim().isEmpty
        ? 'Destination'
        : request.destination;
    final passengers = request.passengerCount > 0
        ? '${request.passengerCount} passengers'
        : 'Passengers';
    final tripDate = _formatDate(request.startDate);
    final tripType = request.tripType.trim().isEmpty
        ? 'Whole-bus trip'
        : request.tripType;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: BusGoSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 152,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: BusGoBusImage(
                      imageUrl: null,
                      height: 152,
                      borderRadius: 0,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.96)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: TextButton.icon(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surfaceContainerHigh
                            : Colors.white.withValues(alpha: 0.96),
                        foregroundColor: BusGoTokens.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$pickup → $destination',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _TripMetaChip(
                        icon: Icons.calendar_month_rounded,
                        label: tripDate,
                      ),
                      _TripMetaChip(
                        icon: Icons.groups_rounded,
                        label: passengers,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tripType,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (request.estimatedAmount > 0)
                        Text(
                          '₹${request.estimatedAmount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF8F8),
                        foregroundColor: BusGoTokens.blue,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('View Details →'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  String _statusLabelFor(BookingRequestStatus status) {
    switch (status) {
      case BookingRequestStatus.cancelled:
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
        return 'Cancelled';
      case BookingRequestStatus.completed:
        return 'Completed';
      case BookingRequestStatus.paymentRequired:
      case BookingRequestStatus.confirmed:
      case BookingRequestStatus.ownerAccepted:
      case BookingRequestStatus.adminReview:
      case BookingRequestStatus.pendingOwner:
        return 'Upcoming';
    }
  }
}

class _TripMetaChip extends StatelessWidget {
  const _TripMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BusGoTokens.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BookingRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive =
        status == BookingRequestStatus.paymentRequired ||
        status == BookingRequestStatus.confirmed ||
        status == BookingRequestStatus.completed;
    final isNegative =
        status == BookingRequestStatus.cancelled ||
        status == BookingRequestStatus.ownerRejected ||
        status == BookingRequestStatus.adminRejected;
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
      backgroundColor: isPositive
          ? colorScheme.tertiaryContainer
          : isNegative
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isPositive
            ? colorScheme.onTertiaryContainer
            : isNegative
            ? colorScheme.onErrorContainer
            : colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
    );
  }
}

enum _TripListFilter {
  all('All'),
  upcoming('Upcoming'),
  completed('Completed'),
  cancelled('Cancelled');

  const _TripListFilter(this.label);

  final String label;

  bool matches(BookingRequestModel request) {
    switch (this) {
      case _TripListFilter.all:
        return true;
      case _TripListFilter.upcoming:
        return request.status != BookingRequestStatus.cancelled &&
            request.status != BookingRequestStatus.completed &&
            request.status != BookingRequestStatus.ownerRejected &&
            request.status != BookingRequestStatus.adminRejected;
      case _TripListFilter.completed:
        return request.status == BookingRequestStatus.completed;
      case _TripListFilter.cancelled:
        return request.status == BookingRequestStatus.cancelled ||
            request.status == BookingRequestStatus.ownerRejected ||
            request.status == BookingRequestStatus.adminRejected;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, this.onTap});

  final NotificationModel notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedType = notification.type.toLowerCase();
    final tint = _tintForType(normalizedType);
    final time = notification.createdAt;
    final timeLabel =
        '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    final title = notification.title.trim().isEmpty
        ? 'BUSGO update'
        : notification.title;
    final message = notification.message.trim().isEmpty
        ? 'New update from BUSGO.'
        : notification.message;
    final bookingReference = notification.relatedBookingId;
    final isRead = notification.isRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead
                ? colorScheme.outlineVariant
                : tint.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: isRead ? 0.12 : 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForType(normalizedType), color: tint, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (bookingReference != null &&
                      bookingReference.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trip reference: $bookingReference',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: BusGoTokens.blue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: BusGoTokens.blue,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: BusGoTokens.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _tintForType(String normalizedType) {
    if (normalizedType.contains('payment')) return const Color(0xFFF59E0B);
    if (normalizedType.contains('system') || normalizedType.contains('admin')) {
      return const Color(0xFF8B5CF6);
    }
    if (normalizedType.contains('cancel') ||
        normalizedType.contains('warning')) {
      return const Color(0xFFEF4444);
    }
    if (normalizedType.contains('trip') ||
        normalizedType.contains('booking') ||
        normalizedType.contains('owner') ||
        normalizedType.contains('bus')) {
      return const Color(0xFF2563EB);
    }
    return const Color(0xFF10B981);
  }

  IconData _iconForType(String type) {
    final normalized = type;
    if (normalized.contains('payment')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (normalized.contains('cancel') || normalized.contains('warning')) {
      return Icons.warning_amber_rounded;
    }
    if (normalized.contains('trip') ||
        normalized.contains('booking') ||
        normalized.contains('owner') ||
        normalized.contains('bus')) {
      return Icons.directions_bus_outlined;
    }
    if (normalized.contains('system') || normalized.contains('admin')) {
      return Icons.info_outline_rounded;
    }
    return Icons.notifications_active_rounded;
  }
}

enum _NotificationFilter {
  all('All'),
  trips('Trips'),
  payments('Payments'),
  system('System');

  const _NotificationFilter(this.label);

  final String label;

  bool matches(String type) {
    if (this == all) return true;
    final normalized = type.toLowerCase();
    return switch (this) {
      all => true,
      trips =>
        normalized.contains('owner') ||
            normalized.contains('trip') ||
            normalized.contains('booking') ||
            normalized.contains('review'),
      payments => normalized.contains('payment'),
      system =>
        !normalized.contains('owner') &&
            !normalized.contains('trip') &&
            !normalized.contains('booking') &&
            !normalized.contains('review') &&
            !normalized.contains('payment'),
    };
  }
}
