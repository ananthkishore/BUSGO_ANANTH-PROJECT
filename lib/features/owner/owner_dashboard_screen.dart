import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/app_roles.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../core/errors/auth_failure.dart';
import '../../models/bus_model.dart';
import '../../models/booking_request_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../repositories/bus_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  static String safeDisplayName(String? value) {
    final cleaned = (value ?? '').trim();
    return cleaned.isEmpty ? 'there' : cleaned;
  }

  static String profileInitials(String? value) {
    final cleaned = (value ?? '').trim();
    if (cleaned.isEmpty) return 'O';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedIndex = 0;
  final _busSearchController = TextEditingController();
  final _requestSearchController = TextEditingController();
  final _earningsHistorySearchController = TextEditingController();
  _BusFilter _busFilter = _BusFilter.all;
  _BusSort _busSort = _BusSort.newest;
  _RequestFilter _requestFilter = _RequestFilter.pending;
  _TripFilter _tripFilter = _TripFilter.upcoming;
  _EarningsFilter _earningsFilter = _EarningsFilter.allTime;
  _EarningsHistoryStatusFilter _earningsHistoryStatus =
      _EarningsHistoryStatusFilter.all;
  _OwnerNotificationFilter _ownerNotificationFilter =
      _OwnerNotificationFilter.all;
  String _ownerTripsSection = 'trips';
  int _notificationRetrySeed = 0;
  DateTimeRange? _earningsCustomRange;
  final Set<String> _busyRequestIds = <String>{};
  final Set<String> _deletingBusIds = <String>{};
  final Set<String> _openingOwnerDestinationKeys = <String>{};
  Timer? _tripDateRefreshTimer;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.directions_bus_outlined),
      selectedIcon: Icon(Icons.directions_bus_rounded),
      label: 'My Buses',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox_rounded),
      label: 'Requests',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route_rounded),
      label: 'Trips',
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
  void initState() {
    super.initState();
    _tripDateRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tripDateRefreshTimer?.cancel();
    _busSearchController.dispose();
    _requestSearchController.dispose();
    _earningsHistorySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      _buses(),
      _requests(),
      _trips(),
      _notifications(),
      _profile(),
    ];
    return BusGoAdaptiveScaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      selectedIndex: _selectedIndex,
      items: _destinations,
      onSelected: (index) => setState(() {
        _selectedIndex = index;
        if (index == 3) _ownerTripsSection = 'trips';
      }),
    );
  }

  Future<void> _openBusDetails(BusModel bus) async {
    final busId = bus.id.trim();
    final currentOwnerUid =
        context.read<AuthProvider>().currentUser?.uid ?? 'null';
    debugPrint('[BUSGO OWNER VIEW BUS]');
    debugPrint('source: My Buses / owner notification');
    debugPrint('action: VIEW');
    debugPrint('currentOwnerUid: $currentOwnerUid');
    debugPrint('selectedBusId: $busId');
    debugPrint('busId: $busId');
    debugPrint('selectedBusDocumentId: $busId');
    debugPrint('busName: ${bus.name}');
    debugPrint('registrationNumber: ${bus.registrationNumber}');
    debugPrint('currentStatus: ${bus.status}');
    debugPrint('route: /owner/bus-details');
    debugPrint('destination: OwnerBusManagementDetailsScreen');
    debugPrint('[/BUSGO OWNER VIEW BUS]');
    debugPrint('[BUSGO VIEW BUS DETAILS]');
    debugPrint('busId: $busId');
    debugPrint('destination: /owner/bus-details');
    debugPrint('documentExists: checked by details stream');
    debugPrint('[/BUSGO VIEW BUS DETAILS]');

    if (busId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this bus details.')),
      );
      return;
    }

    await _pushOwnerDestination(
      key: 'bus:$busId',
      route: '/owner/bus-details',
      extra: busId,
    );
  }

  Future<void> _openEditBus(BusModel bus) async {
    final ownerUid = context.read<AuthProvider>().currentUser?.uid ?? 'null';
    debugPrint('[BUSGO OWNER BUS ACTION]');
    debugPrint('action: EDIT');
    debugPrint('ownerUid: $ownerUid');
    debugPrint('busId: ${bus.id}');
    debugPrint('busName: ${bus.name}');
    debugPrint('registrationNumber: ${bus.registrationNumber}');
    debugPrint('currentStatus: ${bus.status}');
    debugPrint('[/BUSGO OWNER BUS ACTION]');
    await _pushOwnerDestination(
      key: 'edit-bus:${bus.id}',
      route: '/owner/edit-bus',
      extra: bus.id,
    );
  }

  Future<void> _confirmDeleteBus(BusModel bus) async {
    if (!_deletingBusIds.add(bus.id)) return;
    final ownerUid = context.read<AuthProvider>().currentUser?.uid ?? 'null';
    debugPrint('[BUSGO OWNER BUS ACTION]');
    debugPrint('action: DELETE');
    debugPrint('ownerUid: $ownerUid');
    debugPrint('busId: ${bus.id}');
    debugPrint('busName: ${bus.name}');
    debugPrint('registrationNumber: ${bus.registrationNumber}');
    debugPrint('currentStatus: ${bus.status}');
    debugPrint('[/BUSGO OWNER BUS ACTION]');
    try {
      final deleted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          var deleting = false;
          String? errorMessage;
          return StatefulBuilder(
            builder: (context, setDialogState) => PopScope(
              canPop: !deleting,
              child: AlertDialog(
                title: const Text('Delete this bus?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This bus will be removed from your buses.'),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: deleting
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: deleting
                        ? null
                        : () async {
                            setDialogState(() {
                              deleting = true;
                              errorMessage = null;
                            });
                            try {
                              await context
                                  .read<BusRepository>()
                                  .deleteOwnerBus(busId: bus.id);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                deleting = false;
                                errorMessage = error is AuthFailure
                                    ? error.message
                                    : 'Unable to delete this bus. Please try again.';
                              });
                            }
                          },
                    child: Text(deleting ? 'Deleting...' : 'Delete'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (deleted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus deleted successfully.')),
        );
      }
    } finally {
      _deletingBusIds.remove(bus.id);
    }
  }

  Future<void> _openOwnerRequestDetails(BookingRequestModel request) async {
    final bookingId = request.id.trim();
    if (bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this booking details.')),
      );
      return;
    }

    debugPrint('[BUSGO OWNER NAV]');
    debugPrint('source: owner dashboard');
    debugPrint('action: open request details');
    debugPrint('bookingId: $bookingId');
    debugPrint('busId: ${request.busId}');
    debugPrint('destination: /owner/request-details');
    debugPrint('[/BUSGO OWNER NAV]');
    await _pushOwnerDestination(
      key: 'booking:$bookingId',
      route: '/owner/request-details',
      extra: request,
    );
  }

  Future<void> _pushOwnerDestination({
    required String key,
    required String route,
    required Object extra,
  }) async {
    if (!mounted || !_openingOwnerDestinationKeys.add(key)) return;
    try {
      await context.push(route, extra: extra);
    } finally {
      _openingOwnerDestinationKeys.remove(key);
    }
  }

  Widget _dashboard() {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return _dashboardPage(
        child: _dashboardShell(
          displayName: 'there',
          child: const BusGoLoadingState(label: 'Loading owner profile...'),
        ),
      );
    }

    return StreamBuilder<List<BusModel>>(
      stream: context.read<BusRepository>().watchForOwner(user.uid),
      builder: (context, busSnapshot) {
        return StreamBuilder<List<BookingRequestModel>>(
          stream: context.read<BookingRequestRepository>().watchForOwner(
            user.uid,
          ),
          builder: (context, requestSnapshot) {
            final firstName = user.name.trim().split(RegExp(r'\s+')).first;
            final displayName = firstName.isEmpty ? 'there' : firstName;
            final shellChild = _dashboardDataContent(
              buses: busSnapshot.data,
              requests: requestSnapshot.data,
              busError: busSnapshot.hasError,
              requestError: requestSnapshot.hasError,
            );

            return _dashboardPage(
              child: _dashboardShell(
                displayName: displayName,
                child: shellChild,
              ),
            );
          },
        );
      },
    );
  }

  Widget _dashboardPage({required Widget child}) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );

  Widget _dashboardShell({required String displayName, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ownerHeader(displayName),
        const SizedBox(height: 18),
        _ownerHero(displayName),
        const SizedBox(height: 18),
        child,
      ],
    );
  }

  Widget _dashboardDataContent({
    required List<BusModel>? buses,
    required List<BookingRequestModel>? requests,
    required bool busError,
    required bool requestError,
  }) {
    if (busError || requestError) {
      return BusGoErrorState(
        title: "Couldn't load dashboard data",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() {}),
      );
    }
    if (buses == null || requests == null) {
      return const BusGoLoadingState(label: 'Loading your dashboard...');
    }

    final pendingRequests = requests
        .where((request) => request.status == BookingRequestStatus.pendingOwner)
        .length;
    final completedTrips = requests
        .where((request) => request.status == BookingRequestStatus.completed)
        .length;
    final earnings = requests
        .where((request) => request.paymentStatus == PaymentStatus.paid)
        .fold<double>(0, (total, request) => total + request.estimatedAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dashboardStats(
          buses: buses.length,
          pendingRequests: pendingRequests,
          completedTrips: completedTrips,
          earnings: earnings,
        ),
        const SizedBox(height: 22),
        _sectionHeader(
          title: 'Recent Booking Requests',
          actionLabel: 'See all',
          onAction: () => setState(() => _selectedIndex = 2),
        ),
        const SizedBox(height: 10),
        if (requests.isEmpty)
          const BusGoEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No booking requests yet',
            message: 'New whole-bus customer requests will appear here.',
          )
        else
          for (final request in requests.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(
                request: request,
                compact: true,
                onDetails: () => _openOwnerRequestDetails(request),
              ),
            ),
        const SizedBox(height: 12),
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.25,
          children: [
            _quickAction(
              icon: Icons.directions_bus_rounded,
              label: 'Manage Buses',
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            _quickAction(
              icon: Icons.description_outlined,
              label: 'View Bookings',
              onTap: () => setState(() => _selectedIndex = 2),
            ),
            _quickAction(
              icon: Icons.bar_chart_rounded,
              label: 'Earnings',
              onTap: () => setState(() {
                _selectedIndex = 3;
                _ownerTripsSection = 'earnings';
              }),
            ),
            _quickAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              onTap: () => context.push('/owner/messages'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _sectionHeader(
          title: 'Your Buses',
          actionLabel: 'See all',
          onAction: () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(height: 10),
        if (buses.isEmpty)
          BusGoEmptyState(
            icon: Icons.directions_bus_outlined,
            title: 'No buses registered yet',
            message: 'Add a bus to start receiving whole-bus trip requests.',
            actionLabel: 'Add New Bus',
            onAction: () => context.push('/owner/add-bus'),
          )
        else
          for (final bus in buses.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BusCard(
                bus: bus,
                compact: true,
                onDetails: () => _openBusDetails(bus),
              ),
            ),
      ],
    );
  }

  Widget _ownerHero(String displayName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 224,
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
                  size: 112,
                ),
              ),
            ),
            Container(color: const Color(0xFF061B2D).withValues(alpha: 0.56)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Hello, $displayName',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage Your\nBuses, Grow\nYour Business',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Receive booking requests, manage your fleet and serve more customers.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      height: 1.35,
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

  Widget _dashboardStats({
    required int buses,
    required int pendingRequests,
    required int completedTrips,
    required double earnings,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 380
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: columns == 1
              ? 104
              : columns == 2
              ? 118
              : 132,
          children: [
            _statCard(
              title: 'Total Buses',
              value: '$buses',
              icon: Icons.directions_bus_rounded,
              color: BusGoTokens.blue,
              compact: true,
            ),
            _statCard(
              title: 'Pending Requests',
              value: '$pendingRequests',
              icon: Icons.pending_actions_rounded,
              color: BusGoTokens.orange,
              compact: true,
            ),
            _statCard(
              title: 'Completed Trips',
              value: '$completedTrips',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF0A9F6E),
              compact: true,
            ),
            _statCard(
              title: 'Total Earnings',
              value: '₹${earnings.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF7047D6),
              compact: true,
            ),
          ],
        );
      },
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: onTap == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : BusGoTokens.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownerHeader(String name) {
    final authProvider = context.watch<AuthProvider>();
    final label = name.isEmpty ? 'O' : name[0].toUpperCase();

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
          onPressed: () => setState(() => _selectedIndex = 4),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: BusGoTokens.blue,
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _selectedIndex = 5),
          child: BusGoProfileAvatar(
            imageUrl: authProvider.currentUser?.profileImageUrl,
            size: 42,
            label: label,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel)),
    ],
  );

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool compact = false,
  }) => BusGoSurface(
    padding: EdgeInsets.all(compact ? 9 : 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 29 : 38,
              height: compact ? 29 : 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: compact ? 16 : 20),
            ),
            const Spacer(),
          ],
        ),
        SizedBox(height: compact ? 7 : 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 10 : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              (compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
        ),
      ],
    ),
  );

  Widget _requests() {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return _requestsPage(
        displayName: 'there',
        child: const BusGoLoadingState(label: 'Loading booking requests...'),
      );
    }

    final firstName = user.name.trim().split(RegExp(r'\s+')).first;
    final displayName = firstName.isEmpty ? 'there' : firstName;
    debugPrint('[OWNER REQUESTS] authenticated owner UID = ${user.uid}');
    debugPrint('[OWNER REQUESTS] query = booking_requests where ownerId');
    return StreamBuilder<List<BookingRequestModel>>(
      stream: context.read<BookingRequestRepository>().watchForOwner(user.uid),
      builder: (context, snapshot) => _requestsPage(
        displayName: displayName,
        child: _requestsContent(snapshot),
      ),
    );
  }

  Widget _requestsPage({required String displayName, required Widget child}) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ownerHeader(displayName),
                const SizedBox(height: 22),
                Text(
                  'Booking Requests',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review and manage customer booking requests',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _requestsContent(AsyncSnapshot<List<BookingRequestModel>> snapshot) {
    if (snapshot.hasError) {
      return BusGoErrorState(
        title: "Couldn't load booking requests",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() {}),
      );
    }
    final requests = snapshot.data;
    if (requests == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _requestFilterSkeleton(),
          const SizedBox(height: 12),
          const BusGoLoadingState(label: 'Loading booking requests...'),
        ],
      );
    }

    final query = _requestSearchController.text.trim().toLowerCase();
    debugPrint(
      '[OWNER REQUESTS] returned=${requests.length} ids=${requests.map((request) => request.id).join(',')}',
    );
    debugPrint(
      '[OWNER REQUESTS] ownerIds=${requests.map((request) => request.ownerId).toSet().join(',')} statuses=${requests.map((request) => request.status.value).join(',')} payments=${requests.map((request) => request.paymentStatus.value).join(',')}',
    );
    final filteredRequests = requests.where((request) {
      final searchableDate =
          '${request.startDate.day}/${request.startDate.month}/${request.startDate.year}';
      final searchableText = [
        request.pickup,
        request.destination,
        request.customerName ?? '',
        request.busName ?? '',
        request.id,
        request.tripType,
        searchableDate,
      ].join(' ').toLowerCase();
      return _requestFilter.matches(request.status) &&
          (query.isEmpty || searchableText.contains(query));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _requestTabs(requests),
        const SizedBox(height: 12),
        TextField(
          controller: _requestSearchController,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search by route, date or customer name...',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredRequests.isEmpty)
          BusGoEmptyState(
            icon: Icons.inbox_outlined,
            title: _requestFilter == _RequestFilter.pending
                ? 'No pending booking requests'
                : 'No ${_requestFilter.label.toLowerCase()} booking requests',
            message: query.isEmpty
                ? 'New customer requests for your buses will appear here.'
                : 'Try another route, date or customer name.',
          )
        else
          for (final request in filteredRequests)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestCard(
                request: request,
                busy: _busyRequestIds.contains(request.id),
                onAccept: () => _handleRequestAction(request, accept: true),
                onReject: () => _handleRequestAction(request, accept: false),
                onDetails: () => _openOwnerRequestDetails(request),
              ),
            ),
      ],
    );
  }

  Widget _requestTabs(List<BookingRequestModel> requests) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _RequestFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _RequestFilter.values[index];
          final count = requests
              .where((request) => filter.matches(request.status))
              .length;
          final selected = filter == _requestFilter;
          final colorScheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text('${filter.label} ($count)'),
            selected: selected,
            onSelected: (_) => setState(() => _requestFilter = filter),
            selectedColor: colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }

  Widget _requestFilterSkeleton() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buses() {
    final user = context.watch<AuthProvider>().currentUser;
    final ownerName = user?.name.trim().split(RegExp(r'\s+')).first;
    final displayName = ownerName == null || ownerName.isEmpty
        ? 'there'
        : ownerName;

    if (user == null) {
      return _fleetPage(
        displayName: displayName,
        child: const BusGoLoadingState(label: 'Loading your fleet...'),
      );
    }

    return StreamBuilder<List<BusModel>>(
      stream: context.read<BusRepository>().watchForOwner(user.uid).map((
        buses,
      ) {
        debugPrint('[MY BUSES] current UID = ${user.uid}');
        debugPrint('[MY BUSES] documents returned = ${buses.length}');
        debugPrint('[MY BUSES] buses parsed = ${buses.length}');
        return buses;
      }),
      builder: (context, snapshot) =>
          _fleetPage(displayName: displayName, child: _fleetContent(snapshot)),
    );
  }

  Widget _fleetPage({required String displayName, required Widget child}) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ownerHeader(displayName),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Buses',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your buses and track their approval status',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fleetContent(AsyncSnapshot<List<BusModel>> snapshot) {
    if (snapshot.hasError) {
      return BusGoErrorState(
        title: "Couldn't load your buses",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() {}),
      );
    }
    final buses = snapshot.data;
    if (buses == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fleetStatSkeleton(),
          const SizedBox(height: 18),
          const BusGoLoadingState(label: 'Loading your fleet...'),
        ],
      );
    }

    final query = _busSearchController.text.trim().toLowerCase();
    final filteredBuses = buses.where((bus) {
      final matchesQuery =
          query.isEmpty ||
          bus.registrationNumber.toLowerCase().contains(query) ||
          bus.name.toLowerCase().contains(query) ||
          bus.busType.toLowerCase().contains(query);
      return matchesQuery &&
          _busFilter.matches(
            bus.status,
            hasPendingUpdate: bus.hasPendingUpdate,
            hasRejectedUpdate: bus.hasRejectedUpdate,
          );
    }).toList()..sort(_busSort.compare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _busSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search your buses...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_BusSort>(
              tooltip: 'Sort buses',
              initialValue: _busSort,
              onSelected: (sort) => setState(() => _busSort = sort),
              itemBuilder: (context) => [
                for (final sort in _BusSort.values)
                  PopupMenuItem(
                    value: sort,
                    child: Row(
                      children: [
                        Icon(
                          _busSort == sort
                              ? Icons.check_rounded
                              : Icons.sort_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(sort.label),
                      ],
                    ),
                  ),
              ],
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sort_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _fleetFilterChips(buses),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/owner/add-bus'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: BusGoTokens.blue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text('Add New Bus'),
        ),
        const SizedBox(height: 18),
        if (buses.isEmpty)
          BusGoEmptyState(
            icon: Icons.directions_bus_outlined,
            title: 'No buses added yet',
            message: 'Add your first bus to get started.',
            actionLabel: 'Add New Bus',
            onAction: () => context.push('/owner/add-bus'),
          )
        else if (filteredBuses.isEmpty)
          const BusGoEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No buses match your search',
            message: 'Try another number, model or status.',
          )
        else
          for (final bus in filteredBuses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BusCard(
                bus: bus,
                fleet: true,
                onDetails: () => _openBusDetails(bus),
                onEdit: bus.hasPendingUpdate ? null : () => _openEditBus(bus),
                onDelete: () => _confirmDeleteBus(bus),
              ),
            ),
      ],
    );
  }

  Widget _fleetFilterChips(List<BusModel> buses) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _BusFilter.values[index];
          final selected = _busFilter == filter;
          final count = buses
              .where(
                (bus) => filter.matches(
                  bus.status,
                  hasPendingUpdate: bus.hasPendingUpdate,
                  hasRejectedUpdate: bus.hasRejectedUpdate,
                ),
              )
              .length;
          final colorScheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text('${filter.label} ($count)'),
            selected: selected,
            onSelected: (_) => setState(() => _busFilter = filter),
            selectedColor: colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }

  Widget _fleetStatSkeleton() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.55,
      children: List.generate(
        4,
        (_) => Container(
          height: 66,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _trips() {
    final user = context.watch<AuthProvider>().currentUser;
    final firstName = user?.name.trim().split(RegExp(r'\s+')).first;
    final displayName = firstName == null || firstName.isEmpty
        ? 'there'
        : firstName;

    if (user == null) {
      return _ownerTripsPage(
        displayName: displayName,
        child: const BusGoLoadingState(label: 'Loading your earnings...'),
      );
    }

    return StreamBuilder<List<BookingRequestModel>>(
      stream: context.read<BookingRequestRepository>().watchForOwner(user.uid),
      builder: (context, snapshot) {
        if (_ownerTripsSection != 'trips') {
          return _ownerTripsPage(
            displayName: displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_earningsContent(snapshot)],
            ),
          );
        }
        return StreamBuilder<List<BusModel>>(
          stream: context.read<BusRepository>().watchForOwner(user.uid),
          builder: (context, busSnapshot) => _ownerTripsPage(
            displayName: displayName,
            child: _tripsContent(snapshot, busSnapshot),
          ),
        );
      },
    );
  }

  Widget _ownerTripsPage({required String displayName, required Widget child}) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ownerHeader(displayName),
                const SizedBox(height: 22),
                Text(
                  _ownerTripsSection == 'trips'
                      ? 'My Trips'
                      : 'Earnings History',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _ownerTripsSection == 'trips'
                      ? 'View your confirmed and scheduled trips'
                      : 'Track all your earnings from completed trips',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'trips', label: Text('Trips')),
                    ButtonSegment(value: 'earnings', label: Text('Earnings')),
                  ],
                  selected: {_ownerTripsSection},
                  onSelectionChanged: (selection) =>
                      setState(() => _ownerTripsSection = selection.first),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tripsContent(
    AsyncSnapshot<List<BookingRequestModel>> snapshot,
    AsyncSnapshot<List<BusModel>> busSnapshot,
  ) {
    if (snapshot.hasError || busSnapshot.hasError) {
      return BusGoErrorState(
        title: "Couldn't load trips",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() {}),
      );
    }
    final requests = snapshot.data;
    final buses = busSnapshot.data;
    if (requests == null || buses == null) {
      return const BusGoLoadingState(label: 'Loading your trips...');
    }
    for (final request in requests) {
      final category = BookingRequestRepository.classifyTripByDate(request);
      debugPrint('[MY_TRIPS_DEBUG]');
      debugPrint('bookingId: ${request.id}');
      debugPrint('ownerId: ${request.ownerId}');
      debugPrint('startDate: ${_debugDate(request.startDate)}');
      debugPrint('endDate: ${_debugDate(request.endDate)}');
      debugPrint('bookingStatus: ${request.status.value}');
      debugPrint('paymentStatus: ${request.paymentStatus.value}');
      debugPrint('calculatedCategory: ${category.name.toUpperCase()}');
    }
    final trips = requests.where(_isOwnerTrip).toList();
    final filteredTrips = trips
        .where((request) => _tripFilter.matches(request))
        .toList();
    if (trips.isEmpty) {
      return const BusGoEmptyState(
        icon: Icons.route_outlined,
        title: 'No trips yet',
        message: 'Confirmed trips for your buses will appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tripTabs(trips),
        const SizedBox(height: 14),
        if (filteredTrips.isEmpty)
          BusGoEmptyState(
            icon: Icons.route_outlined,
            title: 'No ${_tripFilter.label.toLowerCase()} trips',
            message: 'Trips in this status will appear here.',
          )
        else
          for (final trip in filteredTrips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OwnerTripCard(
                request: trip,
                bus: buses.where((bus) => bus.id == trip.busId).firstOrNull,
                onDetails: () => _openOwnerRequestDetails(trip),
              ),
            ),
      ],
    );
  }

  bool _isOwnerTrip(BookingRequestModel request) =>
      BookingRequestRepository.isEligibleOwnerTrip(request);

  String _debugDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Widget _tripTabs(List<BookingRequestModel> trips) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _TripFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _TripFilter.values[index];
          final selected = filter == _tripFilter;
          final count = trips.where(filter.matches).length;
          final colorScheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text('${filter.label} ($count)'),
            selected: selected,
            onSelected: (_) => setState(() => _tripFilter = filter),
            selectedColor: colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          );
        },
      ),
    );
  }

  Widget _earningsContent(AsyncSnapshot<List<BookingRequestModel>> snapshot) {
    if (snapshot.hasError) {
      return BusGoErrorState(
        title: "Couldn't load earnings",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() {}),
      );
    }
    final requests = snapshot.data;
    if (requests == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _earningsFilterSkeleton(),
          const SizedBox(height: 12),
          _earningsSummarySkeleton(),
          const SizedBox(height: 12),
          const BusGoLoadingState(label: 'Loading your earnings...'),
        ],
      );
    }

    final periodRequests = requests
        .where(
          (request) => _earningsFilter.matches(
            request.startDate,
            customRange: _earningsCustomRange,
          ),
        )
        .toList();
    final query = _earningsHistorySearchController.text.trim().toLowerCase();
    final history = periodRequests.where((request) {
      final searchText = [
        request.pickup,
        request.destination,
        request.customerName ?? '',
        request.tripType,
        '${request.startDate.day}/${request.startDate.month}/${request.startDate.year}',
      ].join(' ').toLowerCase();
      return _earningsHistoryStatus.matches(request) &&
          (query.isEmpty || searchText.contains(query));
    }).toList();
    final paid = periodRequests
        .where((request) => request.paymentStatus == PaymentStatus.paid)
        .toList();
    debugPrint(
      '[OWNER EARNINGS] paid booking IDs = ${paid.map((request) => request.id).join(',')}; earnings are derived from paid bookings and no records are added here',
    );
    final completedTrips = periodRequests
        .where((request) => request.status == BookingRequestStatus.completed)
        .length;
    final pendingTrips = periodRequests
        .where(
          (request) =>
              request.status == BookingRequestStatus.pendingOwner ||
              request.status == BookingRequestStatus.ownerAccepted ||
              request.status == BookingRequestStatus.paymentRequired,
        )
        .length;
    final total = paid.fold<double>(
      0,
      (sum, request) => sum + request.estimatedAmount,
    );
    final pendingEarnings = periodRequests
        .where(
          (request) =>
              request.paymentStatus == PaymentStatus.requested ||
              request.paymentStatus == PaymentStatus.submitted ||
              request.status == BookingRequestStatus.paymentRequired,
        )
        .fold<double>(0, (sum, request) => sum + request.estimatedAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _earningsFilters(),
        const SizedBox(height: 14),
        _earningsSummary(
          total: total,
          totalTrips: paid.length,
          completedTrips: completedTrips,
          pendingTrips: pendingTrips,
          pendingEarnings: pendingEarnings,
        ),
        const SizedBox(height: 16),
        _earningsHistorySearch(),
        const SizedBox(height: 16),
        _earningsChart(paid),
        if (paid.isNotEmpty) ...[
          const SizedBox(height: 16),
          _monthlyEarnings(paid),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Earnings History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _earningsFilter = _EarningsFilter.allTime),
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const BusGoEmptyState(
            icon: Icons.payments_outlined,
            title: 'No earnings found',
            message: 'Eligible earnings for this period will appear here.',
          )
        else
          for (final trip in history.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OwnerTripCard(
                request: trip,
                onDetails: () => _openOwnerRequestDetails(trip),
              ),
            ),
        const SizedBox(height: 8),
        _payoutInformation(),
      ],
    );
  }

  Widget _earningsFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _EarningsFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _EarningsFilter.values[index];
          final selected = filter == _earningsFilter;
          final colorScheme = Theme.of(context).colorScheme;
          return ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            onSelected: (_) async {
              if (filter == _EarningsFilter.custom) {
                await _pickEarningsRange();
              } else {
                setState(() {
                  _earningsFilter = filter;
                  _earningsCustomRange = null;
                });
              }
            },
            selectedColor: colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          );
        },
      ),
    );
  }

  Widget _earningsHistorySearch() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchField = TextField(
          controller: _earningsHistorySearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by route, date or customer name...',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        );
        final filterButton = OutlinedButton.icon(
          onPressed: _showEarningsHistoryFilters,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filter'),
        );
        if (!constraints.hasBoundedWidth || constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [searchField, const SizedBox(height: 8), filterButton],
          );
        }
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 8),
            filterButton,
          ],
        );
      },
    );
  }

  Future<void> _showEarningsHistoryFilters() async {
    final selected = await showModalBottomSheet<_EarningsHistoryStatusFilter>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Filter earnings',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final filter in _EarningsHistoryStatusFilter.values)
              ListTile(
                leading: Icon(
                  filter == _earningsHistoryStatus
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: filter == _earningsHistoryStatus
                      ? BusGoTokens.blue
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(filter.label),
                onTap: () => Navigator.pop(context, filter),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _earningsHistoryStatus = selected);
    }
  }

  Future<void> _pickEarningsRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _earningsCustomRange,
    );
    if (selected != null && mounted) {
      setState(() {
        _earningsFilter = _EarningsFilter.custom;
        _earningsCustomRange = selected;
      });
    }
  }

  Widget _earningsSummary({
    required double total,
    required int totalTrips,
    required int completedTrips,
    required int pendingTrips,
    required double pendingEarnings,
  }) {
    return BusGoSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Total Earnings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '₹${total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _earningsFilter.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryMetric(
                Icons.directions_bus_rounded,
                'Total Trips',
                '$totalTrips',
              ),
              _summaryMetric(
                Icons.check_circle_outline_rounded,
                'Completed',
                '$completedTrips',
              ),
              _summaryMetric(
                Icons.schedule_rounded,
                'Pending',
                '$pendingTrips • ₹${pendingEarnings.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(IconData icon, String label, String value) {
    return SizedBox(
      width: 112,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: BusGoTokens.blue, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRequestAction(
    BookingRequestModel request, {
    required bool accept,
  }) async {
    if (_busyRequestIds.contains(request.id)) return;
    String? rejectionReason;
    if (!accept) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject request?'),
          content: TextField(
            controller: controller,
            maxLines: 2,
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
      rejectionReason = controller.text.trim();
      controller.dispose();
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busyRequestIds.add(request.id));
    try {
      final repository = context.read<BookingRequestRepository>();
      if (accept) {
        await repository.ownerAccept(request: request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Accepted. Waiting for BUSGO admin review.'),
            ),
          );
        }
      } else {
        await repository.transitionStatus(
          requestId: request.id,
          nextStatus: BookingRequestStatus.ownerRejected,
          rejectionReason: rejectionReason,
          ownerId: request.ownerId,
          customerId: request.customerId,
          busId: request.busId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request rejected.')));
        }
      }
    } catch (error) {
      debugPrint('[OWNER REQUEST ACTION] failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update this request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequestIds.remove(request.id));
    }
  }

  Widget _monthlyEarnings(List<BookingRequestModel> paid) {
    final totals = <String, double>{};
    final dates = <String, DateTime>{};
    for (final request in paid) {
      final key = '${request.startDate.year}-${request.startDate.month}';
      totals[key] = (totals[key] ?? 0) + request.estimatedAmount;
      dates[key] = DateTime(request.startDate.year, request.startDate.month);
    }
    final periods = totals.keys.toList()
      ..sort((left, right) => dates[right]!.compareTo(dates[left]!));
    const monthLabels = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return BusGoSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Earnings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final period in periods.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.calendar_month_outlined,
                color: BusGoTokens.blue,
              ),
              title: Text(
                '${monthLabels[dates[period]!.month - 1]} ${dates[period]!.year}',
              ),
              trailing: Text(
                '₹${totals[period]!.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _earningsChart(List<BookingRequestModel> paid) {
    if (paid.isEmpty) {
      return const BusGoEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No earnings data for this period',
        message: 'Select another period to view your real earnings trend.',
      );
    }

    final latest = paid
        .map((request) => request.startDate)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final months = List.generate(
      6,
      (index) => DateTime(latest.year, latest.month - 5 + index),
    );
    final values = months.map((month) {
      return paid
          .where(
            (request) =>
                request.startDate.year == month.year &&
                request.startDate.month == month.month,
          )
          .fold<double>(0, (sum, request) => sum + request.estimatedAmount);
    }).toList();
    final maxValue = values.reduce(
      (left, right) => left > right ? left : right,
    );
    const monthLabels = [
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
    ];

    return BusGoSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < values.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxValue == 0
                                    ? 0.04
                                    : (values[index] / maxValue).clamp(0.04, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: index == values.length - 1
                                        ? BusGoTokens.blue
                                        : const Color(0xFF79C6F7),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            monthLabels[months[index].month - 1],
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                          ),
                        ],
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

  Widget _earningsFilterSkeleton() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _earningsSummarySkeleton() {
    return Container(
      height: 164,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _payoutInformation() {
    return InkWell(
      onTap: () => context.push('/owner/payout-information'),
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: BusGoTokens.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payout Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Manage your payout method and bank details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BusGoTokens.blue),
          ],
        ),
      ),
    );
  }

  Widget _notifications() {
    final user = context.watch<AuthProvider>().currentUser;
    final firstName = user?.name.trim().split(RegExp(r'\s+')).first;
    final displayName = firstName == null || firstName.isEmpty
        ? 'there'
        : firstName;

    if (user == null) {
      return _notificationsPage(
        displayName: displayName,
        child: const BusGoLoadingState(label: 'Loading your notifications...'),
      );
    }

    return StreamBuilder<List<NotificationModel>>(
      key: ValueKey('owner-notifications-$_notificationRetrySeed'),
      stream: context.read<NotificationRepository>().watchForUser(user.uid),
      builder: (context, snapshot) => _notificationsPage(
        displayName: displayName,
        child: _notificationsContent(snapshot, user.uid),
      ),
    );
  }

  Widget _notificationsPage({
    required String displayName,
    required Widget child,
  }) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ownerHeader(displayName),
                const SizedBox(height: 22),
                Text(
                  'Alerts & Notifications',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stay updated with your bookings, trips and important information',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _notificationsContent(
    AsyncSnapshot<List<NotificationModel>> snapshot,
    String recipientId,
  ) {
    if (snapshot.hasError) {
      return BusGoErrorState(
        title: "Couldn't load your notifications",
        message: 'Please check your connection and try again.',
        onRetry: () => setState(() => _notificationRetrySeed++),
      );
    }
    final notifications = snapshot.data;
    if (notifications == null) {
      return Column(
        children: [
          _ownerNotificationFilterSkeleton(),
          const SizedBox(height: 14),
          const BusGoLoadingState(label: 'Loading notifications...'),
        ],
      );
    }

    final filtered = notifications
        .where(_ownerNotificationFilter.matches)
        .toList();
    final hasUnread = notifications.any((notification) => !notification.isRead);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ownerNotificationTabs(notifications),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: hasUnread
                ? () => context.read<NotificationRepository>().markAllAsRead(
                    recipientId,
                  )
                : null,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Mark all as read'),
          ),
        ),
        if (notifications.isEmpty)
          const BusGoEmptyState(
            icon: Icons.notifications_none_rounded,
            title: "You're all caught up!",
            message: "We'll notify you when there's something new.",
          )
        else if (filtered.isEmpty)
          const BusGoEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No notifications in this filter',
            message: 'Try another notification category.',
          )
        else
          for (final notification in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OwnerNotificationCard(
                notification: notification,
                onTap: () async {
                  if (!notification.isRead) {
                    await context.read<NotificationRepository>().markAsRead(
                      notification.id,
                    );
                  }
                  await _openOwnerNotification(notification, recipientId);
                },
              ),
            ),
      ],
    );
  }

  Widget _ownerNotificationTabs(List<NotificationModel> notifications) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _OwnerNotificationFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _OwnerNotificationFilter.values[index];
          final count = notifications.where(filter.matches).length;
          final selected = filter == _ownerNotificationFilter;
          return ChoiceChip(
            label: Text('${filter.label} ($count)'),
            selected: selected,
            onSelected: (_) =>
                setState(() => _ownerNotificationFilter = filter),
            selectedColor: BusGoTokens.blue,
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected
                  ? BusGoTokens.blue
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          );
        },
      ),
    );
  }

  Widget _ownerNotificationFilterSkeleton() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Future<void> _openOwnerNotification(
    NotificationModel notification,
    String recipientId,
  ) async {
    final normalized = notification.type.trim().toLowerCase();
    final bookingId = notification.relatedBookingId?.trim();
    final busId = notification.busIdForNavigation;
    final isBusNotification = normalized.startsWith('bus_');
    final isPaymentNotification =
        normalized.startsWith('payment_') || normalized == 'payment_required';
    debugPrint('[BUSGO NOTIFICATION TAP]');
    debugPrint('notificationId: ${notification.id}');
    debugPrint('type: ${notification.type}');
    debugPrint('recipientId: $recipientId');
    debugPrint('busId: ${busId ?? 'null'}');
    debugPrint('bookingId: ${bookingId ?? 'null'}');
    debugPrint('tripId: null');
    debugPrint('reviewId: null');
    debugPrint(
      'destination: ${isBusNotification
          ? '/owner/bus-details'
          : isPaymentNotification
          ? '/payment-details'
          : '/owner/request-details'}',
    );
    debugPrint('[/BUSGO NOTIFICATION TAP]');
    final conversationId = notification.conversationId?.trim();
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        (normalized == 'support_reply' ||
            normalized == 'owner_message' ||
            normalized == 'customer_message')) {
      if (conversationId != recipientId) {
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

    if (isBusNotification) {
      if (busId == null || busId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This notification is outdated and cannot be opened.',
              ),
            ),
          );
        }
        return;
      }
      try {
        final bus = await context.read<BusRepository>().getById(busId);
        debugPrint('[BUSGO NOTIFICATION LOAD]');
        debugPrint('type: ${notification.type}');
        debugPrint('documentId: $busId');
        debugPrint('collection: buses');
        debugPrint('exists: ${bus != null}');
        debugPrint('result: ${bus != null ? bus.id : 'not_found'}');
        debugPrint('[/BUSGO NOTIFICATION LOAD]');
        if (!mounted) return;
        if (bus != null && bus.ownerId == recipientId) {
          await _openBusDetails(bus);
          return;
        }
        if (bus == null) {
          await _showUnavailableBusNotification(notification, busId);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This notification is outdated and cannot be opened.',
            ),
          ),
        );
        return;
      } catch (error) {
        debugPrint('[BUSGO NOTIFICATION ERROR]');
        debugPrint('type: ${notification.type}');
        debugPrint('operation: load_bus');
        debugPrint('collection: buses');
        debugPrint('documentId: $busId');
        debugPrint('errorCode: ${error.runtimeType}');
        debugPrint('errorMessage: $error');
        debugPrint('[/BUSGO NOTIFICATION ERROR]');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to load the related bus. Please try again.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (bookingId == null || bookingId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This notification is outdated and cannot be opened.',
            ),
          ),
        );
      }
      return;
    }

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
      if (request == null || request.ownerId != recipientId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This notification is outdated and cannot be opened.',
            ),
          ),
        );
        return;
      }

      if (isPaymentNotification) {
        await _pushOwnerDestination(
          key: 'payment:$bookingId',
          route: '/payment-details',
          extra: request,
        );
      } else {
        await _openOwnerRequestDetails(request);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load the related booking. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showUnavailableBusNotification(
    NotificationModel notification,
    String busId,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 12),
            Text('Bus ID: $busId'),
            const SizedBox(height: 12),
            const Text(
              'This bus no longer exists, so its details cannot be loaded.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _profile() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          sliver: SliverToBoxAdapter(
            child: authProvider.isLoading
                ? _profileLoadingState()
                : user == null
                ? BusGoErrorState(
                    title: "Couldn't load profile",
                    message: 'Please check your connection and try again.',
                    onRetry: () => context.go('/login'),
                  )
                : _profileContent(user, authProvider),
          ),
        ),
      ],
    );
  }

  Widget _profileContent(AppUser user, AuthProvider authProvider) {
    final displayName = user.name.trim().isEmpty
        ? 'Not provided'
        : user.name.trim();
    final initials = OwnerDashboardScreen.profileInitials(user.name);
    final phoneValue = (user.phone ?? '').trim();
    final emailValue = user.email.trim().isEmpty
        ? 'Not provided'
        : user.email.trim();
    final phone = phoneValue.isEmpty ? 'Not provided' : phoneValue;
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<BusModel>>(
      stream: context.read<BusRepository>().watchForOwner(user.uid),
      builder: (context, busSnapshot) {
        final registeredBusesText = busSnapshot.hasError
            ? 'Unable to load bus count'
            : !busSnapshot.hasData
            ? 'Loading buses...'
            : busSnapshot.data!.length == 1
            ? '1 Registered Bus'
            : '${busSnapshot.data!.length} Registered Buses';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _profileHeaderRow(authProvider, displayName),
            const SizedBox(height: 18),
            Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your profile, fleet, and account settings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            BusGoSurface(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  BusGoProfileAvatar(
                    imageUrl: user.profileImageUrl,
                    size: 74,
                    label: initials,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emailValue,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            user.role.label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _profileSection(
              title: 'Personal Information',
              icon: Icons.person_outline_rounded,
              trailing: Icon(Icons.edit_outlined, color: colorScheme.primary),
              onTap: () => context.push('/edit-profile'),
              children: [
                _profileInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Full Name',
                  value: displayName,
                ),
                _profileInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: emailValue,
                ),
                _profileInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _profileShortcut(
              title: 'My Buses',
              subtitle: registeredBusesText,
              icon: Icons.directions_bus_outlined,
              onTap: () => setState(() => _selectedIndex = 1),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Earnings',
              subtitle: 'Track your verified earnings',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => setState(() {
                _selectedIndex = 3;
                _ownerTripsSection = 'earnings';
              }),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Notifications',
              subtitle: 'Review updates and trip alerts',
              icon: Icons.notifications_none_rounded,
              onTap: () => setState(() => _selectedIndex = 4),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Settings',
              subtitle: 'App preferences and account settings',
              icon: Icons.settings_outlined,
              onTap: () => context.push('/settings'),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Help & Support',
              subtitle: 'Find help and support information',
              icon: Icons.support_agent_rounded,
              onTap: () => context.push('/help'),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Security',
              subtitle: 'Change your account password',
              icon: Icons.lock_outline_rounded,
              onTap: () => context.push('/change-password'),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'About BUSGO',
              subtitle: 'Read the platform overview',
              icon: Icons.info_outline_rounded,
              onTap: () => context.push('/legal/agreement'),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Terms of Service',
              subtitle: 'Read BUSGO terms',
              icon: Icons.description_outlined,
              onTap: () => context.push('/legal/terms'),
            ),
            const SizedBox(height: 10),
            _profileShortcut(
              title: 'Privacy Policy',
              subtitle: 'Learn how account data is handled',
              icon: Icons.privacy_tip_outlined,
              onTap: () => context.push('/legal/privacy'),
            ),
            const SizedBox(height: 22),
            _logoutCard(authProvider),
          ],
        );
      },
    );
  }

  Widget _profileInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _profileShortcut({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _profileHeaderRow(AuthProvider authProvider, String displayName) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BusGoBrandMark(compact: true, light: isDark),
              const SizedBox(height: 6),
              Text(
                'Travel Together, Go Further',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<List<NotificationModel>>(
          stream: context.read<NotificationRepository>().watchForUser(
            authProvider.currentUser?.uid ?? '',
          ),
          builder: (context, notificationSnapshot) {
            final unreadCount =
                notificationSnapshot.data
                    ?.where((notification) => !notification.isRead)
                    .length ??
                0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedIndex = 4),
                  icon: const Icon(Icons.notifications_none_rounded),
                  tooltip: 'Notifications',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.primary,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _selectedIndex = 5),
          child: BusGoProfileAvatar(
            imageUrl: authProvider.currentUser?.profileImageUrl,
            size: 42,
            label: OwnerDashboardScreen.profileInitials(displayName),
          ),
        ),
      ],
    );
  }

  Widget _logoutCard(AuthProvider authProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: authProvider.isBusy
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text(
                    'Are you sure you want to sign out from your BUSGO account?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed != true || !mounted) return;

              await authProvider.signOut();
              if (mounted) context.go('/login');
            },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.errorContainer.withValues(alpha: 0.22)
              : const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? colorScheme.error.withValues(alpha: 0.7)
                : const Color(0xFFFFD4D4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.errorContainer
                    : const Color(0xFFFFE7E7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: isDark
                    ? colorScheme.onErrorContainer
                    : const Color(0xFFD92D20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logout',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? colorScheme.onSurface
                          : const Color(0xFFD92D20),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Sign out from your account',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? colorScheme.onSurfaceVariant
                          : const Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? colorScheme.onSurface : const Color(0xFFD92D20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < 5; index++) ...[
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

enum _OwnerNotificationFilter {
  all('All'),
  unread('Unread'),
  requests('Requests'),
  trips('Trips');

  const _OwnerNotificationFilter(this.label);

  final String label;

  bool matches(NotificationModel notification) {
    final normalized = notification.type.toLowerCase();
    switch (this) {
      case _OwnerNotificationFilter.all:
        return true;
      case _OwnerNotificationFilter.unread:
        return !notification.isRead;
      case _OwnerNotificationFilter.requests:
        return normalized.contains('booking') ||
            normalized.contains('request') ||
            normalized.contains('owner_accepted') ||
            normalized.contains('owner_rejected') ||
            normalized.contains('availability_review');
      case _OwnerNotificationFilter.trips:
        return normalized.contains('trip') ||
            normalized.contains('payment') ||
            normalized.contains('completed') ||
            normalized.contains('confirmed') ||
            normalized.contains('admin_rejected');
    }
  }
}

enum _EarningsHistoryStatusFilter {
  all('All'),
  completed('Completed'),
  pending('Pending'),
  cancelled('Cancelled');

  const _EarningsHistoryStatusFilter(this.label);

  final String label;

  bool matches(BookingRequestModel request) {
    switch (this) {
      case _EarningsHistoryStatusFilter.all:
        return true;
      case _EarningsHistoryStatusFilter.completed:
        return request.status == BookingRequestStatus.completed ||
            request.paymentStatus == PaymentStatus.paid;
      case _EarningsHistoryStatusFilter.pending:
        return request.status == BookingRequestStatus.pendingOwner ||
            request.status == BookingRequestStatus.ownerAccepted ||
            request.status == BookingRequestStatus.paymentRequired ||
            request.paymentStatus == PaymentStatus.requested ||
            request.paymentStatus == PaymentStatus.submitted;
      case _EarningsHistoryStatusFilter.cancelled:
        return request.status == BookingRequestStatus.cancelled ||
            request.status == BookingRequestStatus.ownerRejected ||
            request.status == BookingRequestStatus.adminRejected ||
            request.paymentStatus == PaymentStatus.rejected;
    }
  }
}

enum _EarningsFilter {
  thisMonth('This Month'),
  thisYear('This Year'),
  allTime('All Time'),
  custom('Custom');

  const _EarningsFilter(this.label);

  final String label;

  bool matches(DateTime date, {DateTimeRange? customRange}) {
    final now = DateTime.now();
    switch (this) {
      case _EarningsFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case _EarningsFilter.thisYear:
        return date.year == now.year;
      case _EarningsFilter.allTime:
        return true;
      case _EarningsFilter.custom:
        if (customRange == null) return false;
        final day = DateTime(date.year, date.month, date.day);
        final start = DateTime(
          customRange.start.year,
          customRange.start.month,
          customRange.start.day,
        );
        final end = DateTime(
          customRange.end.year,
          customRange.end.month,
          customRange.end.day,
          23,
          59,
          59,
        );
        return !day.isBefore(start) && !day.isAfter(end);
    }
  }
}

enum _BusFilter {
  all('All'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const _BusFilter(this.label);

  final String label;

  bool matches(
    String status, {
    bool hasPendingUpdate = false,
    bool hasRejectedUpdate = false,
  }) {
    final normalized = status.toLowerCase().replaceAll('-', '_').trim();
    switch (this) {
      case _BusFilter.all:
        return true;
      case _BusFilter.pending:
        return hasPendingUpdate ||
            normalized == 'pending' ||
            normalized == 'pending_approval';
      case _BusFilter.approved:
        return normalized == 'approved';
      case _BusFilter.rejected:
        return hasRejectedUpdate || normalized == 'rejected';
    }
  }
}

enum _BusSort {
  newest('Newest first'),
  oldest('Oldest first'),
  name('Name A-Z');

  const _BusSort(this.label);

  final String label;

  int compare(BusModel first, BusModel second) {
    switch (this) {
      case _BusSort.newest:
        return (second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
      case _BusSort.oldest:
        return (first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(
              second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
      case _BusSort.name:
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    }
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({
    required this.bus,
    required this.onDetails,
    this.onEdit,
    this.onDelete,
    this.compact = false,
    this.fleet = false,
  });

  final BusModel bus;
  final VoidCallback onDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool compact;
  final bool fleet;

  @override
  Widget build(BuildContext context) {
    if (fleet) return _buildFleet(context);
    if (compact) return _buildCompact(context);

    return BusGoSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BusGoBusImage(imageUrl: bus.imageUrl, height: 150),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bus.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    BusGoStatusChip(
                      label: _statusLabel(bus.status),
                      tone: _statusTone(bus.status),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${bus.registrationNumber} | ${bus.busType}'),
                Text(
                  '${bus.capacity} passengers | ${bus.isAc ? 'AC' : 'Non-AC'}',
                ),
                const SizedBox(height: 6),
                Text('Services: ${bus.serviceLocations.join(', ')}'),
                if (bus.tripTypes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final type in bus.tripTypes.take(3))
                        BusGoStatusChip(
                          label: type,
                          tone: BusGoStatusTone.info,
                        ),
                    ],
                  ),
                ],
                Text('Price per day: ${bus.estimatedPricePerDay}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: BusGoSecondaryButton(
              label: 'View Bus Details',
              icon: Icons.arrow_forward_rounded,
              onPressed: onDetails,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleet(BuildContext context) {
    return BusGoSurface(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 122,
                height: 106,
                child: BusGoBusImage(
                  imageUrl: bus.imageUrl,
                  height: 106,
                  borderRadius: 15,
                ),
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
                            bus.name.trim().isEmpty
                                ? 'Bus model not available'
                                : bus.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 44),
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (value) {
                            if (value == 'details') onDetails();
                            if (value == 'edit') onEdit?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'details',
                              child: Text('View details'),
                            ),
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bus.registrationNumber.trim().isEmpty
                          ? 'Registration not available'
                          : bus.registrationNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _busMeta(
                          context,
                          Icons.groups_2_outlined,
                          '${bus.capacity} Seats',
                        ),
                        _busMeta(
                          context,
                          Icons.directions_bus_outlined,
                          bus.busType.trim().isEmpty ? 'Bus' : bus.busType,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BusGoStatusChip(
                        label: _fleetStatusLabel(
                          bus.status,
                          hasPendingUpdate: bus.hasPendingUpdate,
                          hasRejectedUpdate: bus.hasRejectedUpdate,
                        ),
                        tone: _fleetStatusTone(
                          bus.status,
                          hasPendingUpdate: bus.hasPendingUpdate,
                          hasRejectedUpdate: bus.hasRejectedUpdate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bus.amenities.isNotEmpty || bus.tripTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final item in [...bus.amenities, ...bus.tripTypes].take(4))
                  BusGoStatusChip(label: item, tone: BusGoStatusTone.info),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Added ${_fleetDate(bus.createdAt)}  |  Updated ${_fleetDate(bus.updatedAt)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Details', maxLines: 1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(bus.hasPendingUpdate ? 'Pending' : 'Edit'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 3,
                    ),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fleetDate(DateTime? date) {
    if (date == null) return 'Not available';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _busMeta(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return BusGoSurface(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            child: SizedBox(
              width: 112,
              height: 112,
              child: BusGoBusImage(imageUrl: bus.imageUrl, height: 112),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bus.registrationNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      BusGoStatusChip(
                        label: _statusLabel(bus.status),
                        tone: _statusTone(bus.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bus.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${bus.capacity} passengers | ${bus.busType}'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'View bus details',
                      onPressed: onDetails,
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: BusGoTokens.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) =>
      status.replaceAll('_', ' ').toUpperCase();

  String _fleetStatusLabel(
    String status, {
    bool hasPendingUpdate = false,
    bool hasRejectedUpdate = false,
  }) {
    if (hasPendingUpdate) return 'Update Pending';
    if (hasRejectedUpdate) return 'Update Rejected';
    final normalized = status.toLowerCase().replaceAll('-', '_').trim();
    if (normalized == 'active' || normalized == 'approved') return 'Active';
    if (normalized == 'inactive' ||
        normalized == 'maintenance' ||
        normalized == 'rejected') {
      return 'Inactive';
    }
    if (normalized == 'pending' || normalized == 'pending_approval') {
      return 'Pending';
    }
    return status.replaceAll('_', ' ').trim().isEmpty
        ? 'Pending'
        : status.replaceAll('_', ' ').toUpperCase();
  }

  BusGoStatusTone _fleetStatusTone(
    String status, {
    bool hasPendingUpdate = false,
    bool hasRejectedUpdate = false,
  }) {
    if (hasPendingUpdate) return BusGoStatusTone.warning;
    if (hasRejectedUpdate) return BusGoStatusTone.negative;
    final normalized = status.toLowerCase().replaceAll('-', '_').trim();
    if (normalized == 'active' || normalized == 'approved') {
      return BusGoStatusTone.positive;
    }
    if (normalized == 'inactive' ||
        normalized == 'maintenance' ||
        normalized == 'rejected') {
      return BusGoStatusTone.negative;
    }
    return BusGoStatusTone.warning;
  }

  BusGoStatusTone _statusTone(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return BusGoStatusTone.positive;
      case 'maintenance':
      case 'pending':
      case 'pending_approval':
        return BusGoStatusTone.warning;
      case 'rejected':
        return BusGoStatusTone.negative;
      case 'inactive':
        return BusGoStatusTone.neutral;
      default:
        return BusGoStatusTone.info;
    }
  }
}

enum _RequestFilter {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected');

  const _RequestFilter(this.label);

  final String label;

  bool matches(BookingRequestStatus status) {
    switch (this) {
      case _RequestFilter.pending:
        return status == BookingRequestStatus.pendingOwner;
      case _RequestFilter.accepted:
        return status == BookingRequestStatus.ownerAccepted ||
            status == BookingRequestStatus.adminReview ||
            status == BookingRequestStatus.paymentRequired ||
            status == BookingRequestStatus.confirmed ||
            status == BookingRequestStatus.completed;
      case _RequestFilter.rejected:
        return status == BookingRequestStatus.ownerRejected ||
            status == BookingRequestStatus.adminRejected ||
            status == BookingRequestStatus.cancelled;
    }
  }
}

enum _TripFilter {
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  completed('Completed');

  const _TripFilter(this.label);

  final String label;

  bool matches(BookingRequestModel request) {
    final category = BookingRequestRepository.classifyTripByDate(request);
    return switch (this) {
      _TripFilter.upcoming => category == BookingTripCategory.upcoming,
      _TripFilter.ongoing => category == BookingTripCategory.ongoing,
      _TripFilter.completed => category == BookingTripCategory.completed,
    };
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    this.onDetails,
    this.compact = false,
    this.busy = false,
    this.onAccept,
    this.onReject,
  });

  final BookingRequestModel request;
  final VoidCallback? onDetails;
  final bool compact;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);

    final actionable = request.status == BookingRequestStatus.pendingOwner;
    final customerName = (request.customerName ?? '').trim();

    return BusGoSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _month(request.startDate),
                      style: const TextStyle(
                        color: BusGoTokens.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${request.startDate.day}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.pickup} → ${request.destination}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _requestMeta(
                      context,
                      Icons.groups_2_outlined,
                      '${request.passengerCount} Passengers',
                    ),
                    const SizedBox(height: 3),
                    _requestMeta(
                      context,
                      Icons.local_offer_outlined,
                      request.tripType,
                    ),
                    const SizedBox(height: 3),
                    _requestMeta(
                      context,
                      Icons.directions_bus_outlined,
                      request.busName?.trim().isNotEmpty == true
                          ? request.busName!.trim()
                          : 'Bus details unavailable',
                    ),
                    const SizedBox(height: 3),
                    _requestMeta(
                      context,
                      Icons.calendar_month_outlined,
                      _dateRange(request),
                    ),
                    const SizedBox(height: 3),
                    _requestMeta(
                      context,
                      Icons.schedule_outlined,
                      'Requested ${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                    ),
                  ],
                ),
              ),
              BusGoStatusChip(
                label: request.status.label.toUpperCase(),
                tone: _requestTone(request.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFDCEBFF),
                child: Text(
                  _customerInitial(request.customerName),
                  style: const TextStyle(
                    color: BusGoTokens.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  customerName.isEmpty
                      ? 'Customer details unavailable'
                      : customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'View request details',
                onPressed: onDetails,
                icon: const Icon(Icons.chevron_right_rounded),
                color: BusGoTokens.blue,
              ),
            ],
          ),
          if (request.specialRequirements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Requirements: ${request.specialRequirements}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Amount: ₹${request.estimatedAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              BusGoStatusChip(
                label: request.paymentStatus.label,
                tone: _paymentTone(request.paymentStatus),
              ),
            ],
          ),
          if (actionable) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : onAccept ??
                              () async {
                                await context
                                    .read<BookingRequestRepository>()
                                    .ownerAccept(request: request);
                              },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A9F6E),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : onReject ??
                              () => _reject(
                                context,
                                context.read<BookingRequestRepository>(),
                              ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0xFFF97068)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ] else if (request.status == BookingRequestStatus.ownerAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Waiting for BUSGO admin confirmation.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onDetails != null) ...[const SizedBox(height: 3)],
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final repository = context.read<BookingRequestRepository>();
    final actionable = request.status == BookingRequestStatus.pendingOwner;

    return BusGoSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _month(request.startDate),
                      style: const TextStyle(
                        color: BusGoTokens.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${request.startDate.day}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.pickup} → ${request.destination}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.passengerCount} passengers · ${request.tripType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              BusGoStatusChip(
                label: request.status.label,
                tone: _requestTone(request.status),
              ),
            ],
          ),
          if (actionable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context, repository),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0xFFF97068)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await repository.ownerAccept(request: request);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Accepted. Waiting for BUSGO admin confirmation.',
                            ),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A9F6E),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (onDetails != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDetails,
                child: const Text('View details'),
              ),
            ),
        ],
      ),
    );
  }

  String _month(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }

  Widget _requestMeta(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _dateRange(BookingRequestModel request) {
    final start =
        '${request.startDate.day}/${request.startDate.month}/${request.startDate.year}';
    final end =
        '${request.endDate.day}/${request.endDate.month}/${request.endDate.year}';
    return start == end ? start : '$start - $end';
  }

  String _customerInitial(String? name) {
    final value = (name ?? '').trim();
    return value.isEmpty ? 'C' : value.substring(0, 1).toUpperCase();
  }

  BusGoStatusTone _requestTone(BookingRequestStatus status) {
    switch (status) {
      case BookingRequestStatus.pendingOwner:
        return BusGoStatusTone.warning;
      case BookingRequestStatus.ownerRejected:
      case BookingRequestStatus.adminRejected:
      case BookingRequestStatus.cancelled:
        return BusGoStatusTone.negative;
      case BookingRequestStatus.ownerAccepted:
      case BookingRequestStatus.confirmed:
      case BookingRequestStatus.completed:
      case BookingRequestStatus.paymentRequired:
        return BusGoStatusTone.positive;
      default:
        return BusGoStatusTone.info;
    }
  }

  BusGoStatusTone _paymentTone(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return BusGoStatusTone.positive;
      case PaymentStatus.requested:
      case PaymentStatus.submitted:
        return BusGoStatusTone.warning;
      case PaymentStatus.rejected:
        return BusGoStatusTone.negative;
      case PaymentStatus.notRequested:
        return BusGoStatusTone.neutral;
    }
  }

  Future<void> _reject(
    BuildContext context,
    BookingRequestRepository repository,
  ) async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject request?'),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
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

    if (shouldReject == true) {
      await repository.transitionStatus(
        requestId: request.id,
        nextStatus: BookingRequestStatus.ownerRejected,
        rejectionReason: reason,
        ownerId: request.ownerId,
        customerId: request.customerId,
      );
    }
  }
}

class _OwnerTripCard extends StatelessWidget {
  const _OwnerTripCard({required this.request, this.bus, this.onDetails});

  final BookingRequestModel request;
  final BusModel? bus;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(request);
    final customer = request.customerName?.trim();
    final customerLabel = customer == null || customer.isEmpty
        ? 'Customer booking'
        : customer;
    final dateLabel =
        '${request.startDate.day} ${_month(request.startDate.month)} ${request.startDate.year}';
    return InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: bus == null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: BusGoTokens.blue,
                        size: 27,
                      ),
                    )
                  : BusGoBusImage(
                      imageUrl: bus!.imageUrl,
                      height: 78,
                      borderRadius: 16,
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.pickup.trim().isEmpty ? 'Pickup' : request.pickup} → ${request.destination.trim().isEmpty ? 'Destination' : request.destination}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$dateLabel · ${request.tripType.trim().isEmpty ? 'Whole-bus trip' : request.tripType}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${request.passengerCount} passengers',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BusGoStatusChip(label: status.$1, tone: status.$4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${request.estimatedAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (onDetails != null)
                  IconButton(
                    tooltip: 'View earning details',
                    onPressed: onDetails,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: BusGoTokens.blue,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

  (String, Color, IconData, BusGoStatusTone) _statusPresentation(
    BookingRequestModel request,
  ) {
    final category = BookingRequestRepository.classifyTripByDate(request);
    switch (category) {
      case BookingTripCategory.completed:
        return (
          'Completed',
          const Color(0xFF0A9F6E),
          Icons.check_rounded,
          BusGoStatusTone.positive,
        );
      case BookingTripCategory.ongoing:
        return (
          'Ongoing',
          BusGoTokens.blue,
          Icons.play_arrow_rounded,
          BusGoStatusTone.info,
        );
      case BookingTripCategory.upcoming:
        return (
          'Upcoming',
          BusGoTokens.blue,
          Icons.event_available_outlined,
          BusGoStatusTone.info,
        );
      case BookingTripCategory.ineligible:
        break;
    }
    if (request.status == BookingRequestStatus.cancelled ||
        request.status == BookingRequestStatus.ownerRejected ||
        request.status == BookingRequestStatus.adminRejected ||
        request.paymentStatus == PaymentStatus.rejected) {
      return (
        'Cancelled',
        const Color(0xFFD92D20),
        Icons.close_rounded,
        BusGoStatusTone.negative,
      );
    }
    if (request.paymentStatus == PaymentStatus.paid) {
      return (
        'Completed',
        const Color(0xFF0A9F6E),
        Icons.check_rounded,
        BusGoStatusTone.positive,
      );
    }
    if (request.status == BookingRequestStatus.pendingOwner ||
        request.status == BookingRequestStatus.ownerAccepted ||
        request.status == BookingRequestStatus.paymentRequired ||
        request.paymentStatus == PaymentStatus.requested ||
        request.paymentStatus == PaymentStatus.submitted) {
      return (
        'Pending',
        const Color(0xFFF59E0B),
        Icons.schedule_rounded,
        BusGoStatusTone.warning,
      );
    }
    return (
      request.status.label,
      BusGoTokens.blue,
      Icons.info_outline_rounded,
      BusGoStatusTone.info,
    );
  }
}

class _OwnerNotificationCard extends StatelessWidget {
  const _OwnerNotificationCard({required this.notification, this.onTap});

  final NotificationModel notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedType = notification.type.toLowerCase();
    final color = _colorForType(normalizedType);
    final title = notification.title.trim().isEmpty
        ? 'BUSGO update'
        : notification.title.trim();
    final message = notification.message.trim().isEmpty
        ? 'You have a new business update.'
        : notification.message.trim();
    final bookingReference = notification.relatedBookingId;
    final time = notification.createdAt;
    final timeLabel =
        '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? colorScheme.surfaceContainer
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? Theme.of(context).colorScheme.outlineVariant
                : BusGoTokens.blue.withValues(alpha: 0.28),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0B1F3A),
              blurRadius: 18,
              offset: Offset(0, 8),
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
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForType(normalizedType), color: color, size: 22),
            ),
            const SizedBox(width: 11),
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: notification.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w900,
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
                  const SizedBox(height: 5),
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
                    const SizedBox(height: 7),
                    Text(
                      'Related booking available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BusGoTokens.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(left: 7, top: 4),
                decoration: const BoxDecoration(
                  color: BusGoTokens.blue,
                  shape: BoxShape.circle,
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: BusGoTokens.blue),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('booking') || type.contains('request')) {
      return Icons.description_outlined;
    }
    if (type.contains('payment')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (type.contains('trip') || type.contains('completed')) {
      return Icons.route_rounded;
    }
    if (type.contains('bus') || type.contains('owner')) {
      return Icons.directions_bus_outlined;
    }
    if (type.contains('system') || type.contains('admin')) {
      return Icons.info_outline_rounded;
    }
    return Icons.notifications_active_outlined;
  }

  Color _colorForType(String type) {
    if (type.contains('payment')) return const Color(0xFF2563EB);
    if (type.contains('trip') || type.contains('completed')) {
      return const Color(0xFF0A9F6E);
    }
    if (type.contains('booking') || type.contains('request')) {
      return const Color(0xFF7047D6);
    }
    if (type.contains('system') || type.contains('admin')) {
      return const Color(0xFFF59E0B);
    }
    return BusGoTokens.blue;
  }
}
