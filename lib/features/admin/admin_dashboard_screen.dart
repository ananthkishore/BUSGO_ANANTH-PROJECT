import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/app_roles.dart';
import '../../core/constants/booking_status.dart';
import '../../core/constants/payment_status.dart';
import '../../models/bus_model.dart';
import '../../models/booking_request_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/booking_request_repository.dart';
import '../../repositories/bus_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/busgo_ui.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  int _retrySeed = 0;
  String _ownerFilter = 'all';
  String _busFilter = 'all';
  String _tripFilter = 'all';
  String _requestFilter = 'pending';
  String _moreSection = 'home';
  final List<String> _moreSectionHistory = [];
  String _notificationFilter = 'all';
  String _reportPeriod = '30d';
  final _ownerSearchController = TextEditingController();
  final _busSearchController = TextEditingController();
  final _tripSearchController = TextEditingController();
  final _requestSearchController = TextEditingController();
  final _helpSearchController = TextEditingController();
  String? _selectedBusId;

  void _openMoreSection(String section, {bool resetHistory = false}) {
    setState(() {
      if (resetHistory) {
        _moreSectionHistory.clear();
      } else {
        _moreSectionHistory.add(_moreSection);
      }
      _moreSection = section;
    });
  }

  void _backMoreSection() {
    setState(() {
      _moreSection = _moreSectionHistory.isEmpty
          ? 'home'
          : _moreSectionHistory.removeLast();
    });
  }

  @override
  void dispose() {
    _ownerSearchController.dispose();
    _busSearchController.dispose();
    _tripSearchController.dispose();
    _requestSearchController.dispose();
    _helpSearchController.dispose();
    super.dispose();
  }

  bool _adminProfileNavigationBusy = false;

  void _retryAdminData() => setState(() => _retrySeed++);

  void _openAdminProfile({String source = 'header'}) {
    if (_adminProfileNavigationBusy) return;
    final user = context.read<AuthProvider>().currentUser;
    debugPrint(
      '[BUSGO ADMIN AVATAR TAP]\nuid=${user?.uid ?? 'unknown'}\nrole=${user?.role.name ?? 'unknown'}\nsourceScreen=$source\ndestination=Admin Profile\n[/BUSGO ADMIN AVATAR TAP]',
    );
    _adminProfileNavigationBusy = true;
    setState(() {
      _selectedIndex = 5;
      _moreSectionHistory.clear();
      _moreSection = 'profile';
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _adminProfileNavigationBusy = false);
      }
    });
  }

  Widget _adminError(String title, Object? error) => BusGoErrorState(
    title: title,
    message: _errorMessage(error),
    onRetry: _retryAdminData,
  );

  String _errorMessage(Object? error) {
    final text = error?.toString() ?? '';
    final lower = text.toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission')) {
      return 'Admin access was denied. Verify the signed-in profile has role = admin and deploy firestore.rules.';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'Firebase is unavailable. Check the connection and retry.';
    }
    if (lower.contains('failed-precondition')) {
      return 'Firebase needs configuration before this data can load.';
    }
    return 'The Firebase request failed. Check the debug log and retry.';
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox_rounded),
      label: 'Requests',
    ),
    NavigationDestination(
      icon: Icon(Icons.directions_bus_outlined),
      selectedIcon: Icon(Icons.directions_bus_rounded),
      label: 'Buses',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Owners',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route_rounded),
      label: 'Trips',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz_rounded),
      selectedIcon: Icon(Icons.more_horiz_rounded),
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      _requests(),
      _buses(),
      _owners(),
      _trips(),
      _more(),
    ];
    return BusGoAdaptiveScaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      selectedIndex: _selectedIndex,
      items: _destinations,
      onSelected: (index) => setState(() => _selectedIndex = index),
    );
  }

  Widget _dashboard() => _adminHomePage(
    child: StreamBuilder<List<AppUser>>(
      key: ValueKey('admin-owners-$_retrySeed'),
      stream: context.read<UserRepository>().watchOwners(),
      builder: (context, ownerSnapshot) {
        if (ownerSnapshot.hasError) {
          return _adminError('Owner data unavailable', ownerSnapshot.error);
        }
        if (!ownerSnapshot.hasData) {
          return const BusGoLoadingState(label: 'Loading operations data...');
        }
        return StreamBuilder<List<BusModel>>(
          key: ValueKey('admin-buses-$_retrySeed'),
          stream: context.read<BusRepository>().watchAll(),
          builder: (context, busSnapshot) {
            if (busSnapshot.hasError) {
              return _adminError('Fleet data unavailable', busSnapshot.error);
            }
            if (!busSnapshot.hasData) {
              return const BusGoLoadingState(label: 'Loading fleet data...');
            }
            return StreamBuilder<List<BookingRequestModel>>(
              key: ValueKey('admin-bookings-$_retrySeed'),
              stream: context.read<BookingRequestRepository>().watchAll(),
              builder: (context, requestSnapshot) {
                if (requestSnapshot.hasError) {
                  return _adminError(
                    'Booking data unavailable',
                    requestSnapshot.error,
                  );
                }
                if (!requestSnapshot.hasData) {
                  return const BusGoLoadingState(
                    label: 'Loading booking data...',
                  );
                }
                return StreamBuilder<List<NotificationModel>>(
                  key: ValueKey('admin-dashboard-notifications-$_retrySeed'),
                  stream: _adminNotificationsStream(),
                  builder: (context, notificationSnapshot) {
                    if (notificationSnapshot.hasError) {
                      return _adminError(
                        'Activity data unavailable',
                        notificationSnapshot.error,
                      );
                    }
                    if (!notificationSnapshot.hasData) {
                      return const BusGoLoadingState(
                        label: 'Loading recent activity...',
                      );
                    }
                    final owners = ownerSnapshot.data!;
                    final buses = busSnapshot.data!;
                    final requests = requestSnapshot.data!;
                    final customerIds = requests
                        .map((request) => request.customerId)
                        .where((id) => id.isNotEmpty)
                        .toSet();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _adminHomeHeader(
                          context
                              .watch<AuthProvider>()
                              .currentUser
                              ?.name
                              .trim(),
                        ),
                        const SizedBox(height: 16),
                        _adminWelcomeHero(
                          context
                              .watch<AuthProvider>()
                              .currentUser
                              ?.name
                              .trim(),
                          buses,
                        ),
                        const SizedBox(height: 18),
                        _adminSummaryGrid(
                          totalUsers: owners.length + customerIds.length + 1,
                          owners: owners.length,
                          buses: buses.length,
                          bookings: requests.length,
                        ),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader(
                          'Quick Actions',
                          actionLabel: 'See all',
                          onAction: () => setState(() => _selectedIndex = 5),
                        ),
                        const SizedBox(height: 10),
                        _adminQuickActions(),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader(
                          'Recent Activity',
                          actionLabel: 'View all',
                          onAction: () => setState(() {
                            _selectedIndex = 5;
                            _moreSectionHistory.clear();
                            _moreSection = 'notifications';
                          }),
                        ),
                        const SizedBox(height: 10),
                        _adminRecentActivity(
                          notificationSnapshot.data!,
                          requests,
                        ),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader("Today's Overview"),
                        const SizedBox(height: 10),
                        _adminTodayOverview(requests),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    ),
  );

  /*
        child: const BusGoLoadingState(label: 'Loading admin account...'),

    return _morePage(
      title: 'Notifications',
      child: StreamBuilder<List<NotificationModel>>(
        stream: context.read<NotificationRepository>().watchForUser(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _adminError("Couldn't load notifications", snapshot.error);
          }
          if (!snapshot.hasData) {
            return const BusGoLoadingState(label: 'Loading notifications...');
          }
          final notifications = snapshot.data!;
          final unread = notifications.where((item) => !item.isRead).length;
          final filtered = notifications.where(_matchesNotificationFilter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _adminHomeHeader(user.name.trim()),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: BusGoTokens.navy, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text('Stay updated with all important activities', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: unread == 0 ? null : () => _markAllNotificationsRead(user.uid),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark All Read'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _notificationFilters(notifications, unread),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                BusGoEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: notifications.isEmpty ? 'No notifications yet' : 'No notifications in this filter',
                  message: notifications.isEmpty ? 'Important platform activity will appear here.' : 'Try another notification category.',
                )
              else
                for (final notification in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminNotificationCard(
                      notification: notification,
                      onTap: () async {
                        debugPrint(
                          '[BUSGO NAV] Admin notification tapped: id=${notification.id} bookingId=${notification.relatedBookingId ?? 'null'} type=${notification.type}',
                        );
                        if (!notification.isRead) {
                          await context
                              .read<NotificationRepository>()
                              .markAsRead(notification.id);
                        }
                        await _openAdminNotification(notification, user.uid);
                      },
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _notificationFilters(List<NotificationModel> notifications, int unread) {
    final counts = <String, int>{};
    for (final notification in notifications) {
      final category = _notificationCategory(notification);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _notificationFilterChip('all', 'All (${notifications.length})'),
          _notificationFilterChip('unread', 'Unread ($unread)'),
          _notificationFilterChip('system', 'System (${counts['system'] ?? 0})'),
          _notificationFilterChip('booking', 'Bookings (${counts['booking'] ?? 0})'),
          _notificationFilterChip('owner', 'Owners (${counts['owner'] ?? 0})'),
          _notificationFilterChip('bus', 'Buses (${counts['bus'] ?? 0})'),
          _notificationFilterChip('trip', 'Trips (${counts['trip'] ?? 0})'),
        ],
      ),
    );
  }

  Future<void> _markAllNotificationsRead(String userId) async {
    try {
      await context.read<NotificationRepository>().markAllAsRead(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to mark notifications as read: $error')));
      }
    }
  }

  String _notificationCategory(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    if (type.contains('owner')) return 'owner';
    if (type.contains('bus')) return 'bus';
    if (type.contains('booking') || type.contains('request')) return 'booking';
    if (type.contains('trip')) return 'trip';
    return 'system';
  }
                          bookings: requests.length,
                        ),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader(
                          'Quick Actions',
                          actionLabel: 'See all',
                          onAction: () => setState(() => _selectedIndex = 5),
                        ),
                        const SizedBox(height: 10),
                        _adminQuickActions(),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader(
                          'Recent Activity',
                          actionLabel: 'View all',
                          onAction: () {
                            setState(() {
                              _selectedIndex = 5;
                              _moreSectionHistory.clear();
                              _moreSection = 'notifications';
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        _adminRecentActivity(notifications, requests),
                        const SizedBox(height: 22),
                        _adminDashboardSectionHeader("Today's Overview"),
                        const SizedBox(height: 10),
                        _adminTodayOverview(requests),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    ),
  );

  */

  Widget _adminHomePage({required Widget child}) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    ],
  );

  Stream<List<NotificationModel>> _adminNotificationsStream() {
    final adminId = context.read<AuthProvider>().currentUser?.uid;
    if (adminId == null || adminId.isEmpty) return Stream.value(const []);
    return context.read<NotificationRepository>().watchForUser(adminId);
  }

  Widget _adminWelcomeHero(String? adminName, List<BusModel> buses) {
    final name = adminName?.trim().isNotEmpty == true
        ? adminName!.trim()
        : 'Admin';
    final imageUrl = buses
        .map((bus) => bus.imageUrl)
        .firstWhere(
          (url) => url?.trim().isNotEmpty == true,
          orElse: () => null,
        );
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF7FF), Color(0xFFF8FBFF)],
        ),
        border: Border.all(color: const Color(0xFFDDEBF7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Let's keep BUSGO running smoothly\nand make travel better for everyone.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BusGoTokens.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 19,
                      color: BusGoTokens.blue,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_adminWeekday(now.weekday)}, ${now.day} ${_adminMonth(now.month)} ${now.year}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BusGoTokens.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 116,
            height: 126,
            child: BusGoBusImage(
              imageUrl: imageUrl,
              height: 126,
              borderRadius: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminSummaryGrid({
    required int totalUsers,
    required int owners,
    required int buses,
    required int bookings,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _adminSummaryCard(
          'Total Users',
          '$totalUsers',
          Icons.people_alt_rounded,
          const Color(0xFF1769E0),
        ),
        _adminSummaryCard(
          'Total Bus Owners',
          '$owners',
          Icons.person_rounded,
          const Color(0xFF7047D6),
        ),
        _adminSummaryCard(
          'Total Buses',
          '$buses',
          Icons.directions_bus_rounded,
          BusGoTokens.blue,
        ),
        _adminSummaryCard(
          'Total Bookings',
          '$bookings',
          Icons.calendar_month_rounded,
          const Color(0xFF7047D6),
        ),
      ],
    );
  }

  Widget _adminSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return BusGoSurface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BusGoTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminDashboardSectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _adminQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.35,
      children: [
        _adminDashboardAction(
          'Owner Management',
          Icons.person_add_alt_1_rounded,
          () => setState(() => _selectedIndex = 3),
          const Color(0xFF0A9F6E),
        ),
        _adminDashboardAction(
          'Bus Submissions',
          Icons.directions_bus_rounded,
          () => setState(() => _selectedIndex = 2),
          BusGoTokens.blue,
        ),
        _adminDashboardAction(
          'All Buses',
          Icons.directions_bus_rounded,
          () => setState(() => _selectedIndex = 2),
          BusGoTokens.blue,
        ),
        _adminDashboardAction(
          'Trips Management',
          Icons.route_rounded,
          () => setState(() => _selectedIndex = 4),
          const Color(0xFFF59E0B),
        ),
        _adminDashboardAction(
          'Customer Requests',
          Icons.people_alt_rounded,
          () => setState(() => _selectedIndex = 1),
          const Color(0xFF7047D6),
        ),
        _adminDashboardAction(
          'Reports & Analytics',
          Icons.bar_chart_rounded,
          () => setState(() {
            _selectedIndex = 5;
            _moreSectionHistory.clear();
            _moreSection = 'reports';
          }),
          const Color(0xFFE0445C),
        ),
      ],
    );
  }

  Widget _adminDashboardAction(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BusGoTokens.blue),
          ],
        ),
      ),
    );
  }

  Widget _adminRecentActivity(
    List<NotificationModel> notifications,
    List<BookingRequestModel> requests,
  ) {
    final adminId = context.read<AuthProvider>().currentUser?.uid ?? '';

    if (notifications.isEmpty && requests.isEmpty) {
      return const BusGoEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No recent activity',
        message: 'New platform activity will appear here.',
      );
    }
    if (notifications.isNotEmpty) {
      return Column(
        children: [
          for (final notification in notifications.take(4))
            _adminActivityTile(
              icon: _adminActivityIcon(notification.type),
              title: notification.title.trim().isEmpty
                  ? 'BUSGO update'
                  : notification.title,
              subtitle: notification.message.trim().isEmpty
                  ? 'Platform activity'
                  : notification.message,
              time: _relativeTime(notification.createdAt),
              color: _adminActivityColor(notification.type),
              onTap: () async {
                if (!notification.isRead) {
                  await context.read<NotificationRepository>().markAsRead(
                    notification.id,
                  );
                }
                if (!mounted) return;
                await _openAdminNotification(notification, adminId);
              },
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final request in requests.take(4))
          _adminActivityTile(
            icon: Icons.route_rounded,
            title: 'New booking activity',
            subtitle: '${request.pickup} → ${request.destination}',
            time: _relativeTime(request.updatedAt),
            color: BusGoTokens.blue,
            badge: request.status.label,
            onTap: () => context.push('/admin/booking-details', extra: request),
          ),
      ],
    );
  }

  Widget _adminActivityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    String? badge,
    VoidCallback? onTap,
  }) {
    final content = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (badge != null) _adminActivityBadge(badge, color),
        const SizedBox(width: 5),
        Text(
          time,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
        ),
        const Icon(Icons.chevron_right_rounded, color: BusGoTokens.blue),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BusGoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: content,
              ),
      ),
    );
  }

  Widget _adminActivityBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );

  Widget _adminTodayOverview(List<BookingRequestModel> requests) {
    final today = DateTime.now();
    final counts = List<int>.generate(6, (index) {
      final day = DateTime(today.year, today.month, today.day - (5 - index));
      return requests.where((request) {
        final date = request.startDate;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).length;
    });
    final maxCount = counts.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final todayCount = counts.last;
    return BusGoSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: BusGoTokens.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Bookings",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BusGoTokens.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$todayCount today',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '$todayCount',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < counts.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxCount == 0
                                    ? 0.04
                                    : (counts[index] / maxCount).clamp(0.04, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: index == counts.length - 1
                                        ? BusGoTokens.blue
                                        : const Color(0xFF79A9F5),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _adminShortDay(today.weekday, 5 - index),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: BusGoTokens.muted,
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

  IconData _adminActivityIcon(String type) {
    final value = type.toLowerCase();
    if (value.contains('owner')) {
      return Icons.person_add_alt_1_rounded;
    }
    if (value.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    if (value.contains('booking') || value.contains('trip')) {
      return Icons.calendar_month_rounded;
    }
    if (value.contains('warning') || value.contains('complaint')) {
      return Icons.error_outline_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _adminActivityColor(String type) {
    final value = type.toLowerCase();
    if (value.contains('owner')) {
      return const Color(0xFF0A9F6E);
    }
    if (value.contains('bus')) {
      return BusGoTokens.blue;
    }
    if (value.contains('warning') || value.contains('complaint')) {
      return const Color(0xFFE0445C);
    }
    return const Color(0xFF7047D6);
  }

  String _adminMonth(int month) => const [
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

  String _adminWeekday(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  String _adminShortDay(int weekday, int daysAgo) => const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][DateTime.now().subtract(Duration(days: daysAgo)).weekday - 1];

  Widget _adminHomeHeader(String? adminName) {
    final authProvider = context.watch<AuthProvider>();
    final name = adminName?.isNotEmpty == true ? adminName! : 'Admin';
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BusGoBrandMark(compact: true),
              SizedBox(height: 3),
              Text(
                'Admin Panel',
                style: TextStyle(
                  color: BusGoTokens.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() {
            _selectedIndex = 5;
            _moreSectionHistory.clear();
            _moreSection = 'notifications';
          }),
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFE8F7F7),
            foregroundColor: BusGoTokens.blue,
          ),
        ),
        const SizedBox(width: 8),
        BusGoProfileAvatar(
          imageUrl: authProvider.currentUser?.profileImageUrl,
          size: 42,
          label: name[0].toUpperCase(),
          onTap: () => _openAdminProfile(source: 'dashboard'),
          tooltip: 'Open admin profile',
        ),
      ],
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  Widget _requests() => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(
          child: StreamBuilder<List<BookingRequestModel>>(
            key: ValueKey('admin-request-control-$_retrySeed'),
            stream: context.read<BookingRequestRepository>().watchAll(),
            builder: (context, requestSnapshot) {
              if (requestSnapshot.hasError) {
                return _adminError(
                  "Couldn't load customer requests",
                  requestSnapshot.error,
                );
              }
              if (!requestSnapshot.hasData) {
                return const BusGoLoadingState(
                  label: 'Loading customer requests...',
                );
              }

              return StreamBuilder<List<BusModel>>(
                stream: context.read<BusRepository>().watchAll(),
                builder: (context, busSnapshot) {
                  if (busSnapshot.hasError) {
                    return _adminError(
                      "Couldn't load request buses",
                      busSnapshot.error,
                    );
                  }
                  if (!busSnapshot.hasData) {
                    return const BusGoLoadingState(
                      label: 'Loading request details...',
                    );
                  }

                  final allRequests = requestSnapshot.data!;
                  final buses = {
                    for (final bus in busSnapshot.data!) bus.id: bus,
                  };
                  final pending = allRequests.where(_isPendingRequest).length;
                  final accepted = allRequests.where(_isAcceptedRequest).length;
                  final rejected = allRequests.where(_isRejectedRequest).length;
                  final search = _requestSearchController.text
                      .trim()
                      .toLowerCase();
                  final requests = allRequests.where((request) {
                    final searchable =
                        '${request.customerName ?? ''} ${request.customerId} ${request.busName ?? ''} ${request.pickup} ${request.destination} ${request.tripType} ${request.specialRequirements}'
                            .toLowerCase();
                    final matchesSearch =
                        search.isEmpty || searchable.contains(search);
                    final matchesFilter = switch (_requestFilter) {
                      'pending' => _isPendingRequest(request),
                      'accepted' => _isAcceptedRequest(request),
                      'rejected' => _isRejectedRequest(request),
                      _ => true,
                    };
                    return matchesSearch && matchesFilter;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _adminHomeHeader(
                        context.watch<AuthProvider>().currentUser?.name.trim(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Customer Requests',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: BusGoTokens.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'View and manage customer support requests',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BusGoTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _requestSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Search by name, email, subject or ticket ID...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: PopupMenuButton<String>(
                            tooltip: 'Filter requests',
                            initialValue: _requestFilter,
                            icon: const Icon(Icons.tune_rounded),
                            onSelected: (value) =>
                                setState(() => _requestFilter = value),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'all', child: Text('All')),
                              PopupMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              PopupMenuItem(
                                value: 'accepted',
                                child: Text('Accepted'),
                              ),
                              PopupMenuItem(
                                value: 'rejected',
                                child: Text('Rejected'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _requestFilterChip(
                              'all',
                              'All (${allRequests.length})',
                            ),
                            _requestFilterChip('pending', 'Pending ($pending)'),
                            _requestFilterChip(
                              'accepted',
                              'Accepted ($accepted)',
                            ),
                            _requestFilterChip(
                              'rejected',
                              'Rejected ($rejected)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (requests.isEmpty)
                        const BusGoEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No requests found',
                          message: 'Try another search or status filter.',
                        )
                      else
                        for (final request in requests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AdminCustomerRequestCard(
                              request: request,
                              bus: buses[request.busId],
                              onDetails: () => context.push(
                                '/admin/booking-details',
                                extra: request,
                              ),
                            ),
                          ),
                      const SizedBox(height: 6),
                      _requestSummary(
                        total: allRequests.length,
                        pending: pending,
                        accepted: accepted,
                        rejected: rejected,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _requestSummary({
    required int total,
    required int pending,
    required int accepted,
    required int rejected,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.15,
    children: [
      _requestSummaryCard('Total Requests', total, BusGoTokens.blue),
      _requestSummaryCard('Pending', pending, const Color(0xFFD9535B)),
      _requestSummaryCard('Accepted', accepted, const Color(0xFFE99A24)),
      _requestSummaryCard('Rejected', rejected, const Color(0xFF159A68)),
    ],
  );

  Widget _requestSummaryCard(String label, int count, Color color) =>
      BusGoSurface(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  bool _isPendingRequest(BookingRequestModel request) =>
      request.status == BookingRequestStatus.pendingOwner ||
      request.status == BookingRequestStatus.ownerAccepted ||
      request.status == BookingRequestStatus.adminReview;

  bool _isAcceptedRequest(BookingRequestModel request) =>
      request.status == BookingRequestStatus.confirmed ||
      request.status == BookingRequestStatus.paymentRequired ||
      request.status == BookingRequestStatus.completed;

  bool _isRejectedRequest(BookingRequestModel request) =>
      request.status == BookingRequestStatus.ownerRejected ||
      request.status == BookingRequestStatus.adminRejected ||
      request.status == BookingRequestStatus.cancelled;

  Widget _requestFilterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _requestFilter == value,
      onSelected: (_) => setState(() => _requestFilter = value),
      labelStyle: TextStyle(
        color: _requestFilter == value ? Colors.white : BusGoTokens.navy,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: BusGoTokens.blue,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _requestFilter == value
            ? BusGoTokens.blue
            : const Color(0xFFDCE6F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  Widget _buses() => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(
          child: StreamBuilder<List<AppUser>>(
            key: ValueKey('admin-bus-owners-$_retrySeed'),
            stream: context.read<UserRepository>().watchOwners(),
            builder: (context, ownerSnapshot) {
              if (ownerSnapshot.hasError) {
                return _adminError(
                  "Couldn't load bus owners",
                  ownerSnapshot.error,
                );
              }
              if (!ownerSnapshot.hasData) {
                return const BusGoLoadingState(label: 'Loading bus owners...');
              }

              return StreamBuilder<List<BusModel>>(
                key: ValueKey('admin-fleet-$_retrySeed'),
                stream: context.read<BusRepository>().watchAll(),
                builder: (context, busSnapshot) {
                  if (busSnapshot.hasError) {
                    return _adminError(
                      "Couldn't load buses",
                      busSnapshot.error,
                    );
                  }
                  if (!busSnapshot.hasData) {
                    return const BusGoLoadingState(label: 'Loading buses...');
                  }

                  final allBuses = busSnapshot.data!;
                  final owners = {
                    for (final owner in ownerSnapshot.data!) owner.uid: owner,
                  };
                  final selectedBus = _selectedBusId == null
                      ? null
                      : allBuses
                            .where((bus) => bus.id == _selectedBusId)
                            .firstOrNull;
                  if (selectedBus != null) {
                    return _busVerificationView(
                      selectedBus,
                      owners[selectedBus.ownerId],
                    );
                  }
                  final pending = allBuses
                      .where(
                        (bus) =>
                            bus.status == 'pending_approval' ||
                            bus.hasPendingUpdate,
                      )
                      .length;
                  final approved = allBuses
                      .where((bus) => bus.status == 'approved')
                      .length;
                  final rejected = allBuses
                      .where((bus) => bus.status == 'rejected')
                      .length;
                  final search = _busSearchController.text.trim().toLowerCase();
                  final buses = allBuses.where((bus) {
                    final ownerName = owners[bus.ownerId]?.name ?? bus.ownerId;
                    final searchable =
                        '${bus.registrationNumber} ${bus.name} ${bus.busType} $ownerName'
                            .toLowerCase();
                    final matchesSearch =
                        search.isEmpty || searchable.contains(search);
                    final matchesStatus =
                        _busFilter == 'all' ||
                        (_busFilter == 'pending'
                            ? bus.status == 'pending_approval' ||
                                  bus.hasPendingUpdate
                            : bus.status == _busFilter);
                    return matchesSearch && matchesStatus;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _adminHomeHeader(
                        context.watch<AuthProvider>().currentUser?.name.trim(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'All Buses',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: BusGoTokens.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Manage and monitor all registered buses',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BusGoTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _busSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by bus number, owner or model...',
                          prefixIcon: Icon(Icons.search_rounded),
                          suffixIcon: PopupMenuButton<String>(
                            tooltip: 'Filter buses',
                            initialValue: _busFilter,
                            icon: const Icon(Icons.tune_rounded),
                            onSelected: (value) =>
                                setState(() => _busFilter = value),
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'all', child: Text('All')),
                              PopupMenuItem(
                                value: 'approved',
                                child: Text('Active'),
                              ),
                              PopupMenuItem(
                                value: 'rejected',
                                child: Text('Inactive'),
                              ),
                              PopupMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _busFilterChip('all', 'All (${allBuses.length})'),
                            _busFilterChip('approved', 'Active ($approved)'),
                            _busFilterChip('rejected', 'Inactive ($rejected)'),
                            _busFilterChip('pending', 'Pending ($pending)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (buses.isEmpty)
                        const BusGoEmptyState(
                          icon: Icons.directions_bus_outlined,
                          title: 'No buses found',
                          message: 'Try another search or status filter.',
                        )
                      else
                        for (final bus in buses)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AdminBusCard(
                              bus: bus,
                              ownerName: owners[bus.ownerId]?.name,
                              onOpen: () =>
                                  setState(() => _selectedBusId = bus.id),
                            ),
                          ),
                      const SizedBox(height: 6),
                      _busSummary(
                        total: allBuses.length,
                        pending: pending,
                        approved: approved,
                        rejected: rejected,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _busVerificationView(BusModel bus, AppUser? owner) {
    final status = bus.hasPendingUpdate
        ? 'Bus update pending'
        : bus.status == 'pending_approval'
        ? 'Pending'
        : bus.status == 'approved'
        ? 'Approved'
        : 'Rejected';
    final tone = bus.hasPendingUpdate || bus.status == 'pending_approval'
        ? BusGoStatusTone.warning
        : bus.status == 'approved'
        ? BusGoStatusTone.positive
        : BusGoStatusTone.negative;
    final admin = context.watch<AuthProvider>().currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to all buses',
              onPressed: () => setState(() => _selectedBusId = null),
              icon: const Icon(Icons.arrow_back_rounded),
              color: BusGoTokens.navy,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BusGoBrandMark(compact: true),
                  Text(
                    'Admin Panel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BusGoTokens.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => setState(() {
                _selectedIndex = 5;
                _moreSectionHistory.clear();
                _moreSection = 'notifications';
                _selectedBusId = null;
              }),
              icon: const Icon(Icons.notifications_none_rounded),
              color: BusGoTokens.blue,
            ),
            const SizedBox(width: 6),
            BusGoProfileAvatar(
              imageUrl: admin?.profileImageUrl,
              size: 40,
              label: _initial(admin?.name),
              onTap: () => _openAdminProfile(source: 'bus-detail'),
              tooltip: 'Open admin profile',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Verify Bus Details',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Review the information provided by the owner',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
        ),
        const SizedBox(height: 18),
        BusGoBusImage(imageUrl: bus.imageUrl, height: 190, borderRadius: 20),
        const SizedBox(height: 14),
        BusGoSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bus.registrationNumber.trim().isEmpty
                          ? 'Registration not provided'
                          : bus.registrationNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: BusGoTokens.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  BusGoStatusChip(label: status.toUpperCase(), tone: tone),
                ],
              ),
              const SizedBox(height: 5),
              Text('${bus.name} | ${bus.capacity} Seater'),
              Text('Submitted on ${_busDateTime(bus.createdAt)}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _busVerificationInfoCard(
          title: 'Bus Information',
          children: [
            _busInfoRow(Icons.directions_bus_outlined, 'Bus Model', bus.name),
            _busInfoRow(
              Icons.confirmation_number_outlined,
              'Bus Number',
              bus.registrationNumber,
            ),
            _busInfoRow(
              Icons.event_seat_outlined,
              'Seating Capacity',
              '${bus.capacity} seats',
            ),
            _busInfoRow(Icons.category_outlined, 'Bus Type', bus.busType),
            if (bus.isAc)
              _busInfoRow(Icons.ac_unit_rounded, 'Comfort', 'Air-conditioned'),
          ],
        ),
        if (bus.hasPendingUpdate && bus.pendingUpdate != null) ...[
          const SizedBox(height: 14),
          _busVerificationInfoCard(
            title: 'BUS UPDATE - Updated Information',
            children: [
              _busInfoRow(
                Icons.directions_bus_outlined,
                'Bus Model',
                _pendingText(bus, 'name'),
              ),
              _busInfoRow(
                Icons.confirmation_number_outlined,
                'Bus Number',
                _pendingText(bus, 'registrationNumber'),
              ),
              _busInfoRow(
                Icons.event_seat_outlined,
                'Seating Capacity',
                '${_pendingText(bus, 'capacity')} seats',
              ),
              _busInfoRow(
                Icons.category_outlined,
                'Bus Type',
                _pendingText(bus, 'busType'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _busVerificationInfoCard(
          title: 'Owner Information',
          trailing: owner == null
              ? null
              : IconButton(
                  tooltip: 'View owner details',
                  onPressed: () =>
                      context.push('/admin/owner-details', extra: owner),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  color: BusGoTokens.blue,
                ),
          children: [
            _busInfoRow(
              Icons.person_outline_rounded,
              'Name',
              owner?.name ?? 'Owner information unavailable',
            ),
            _busInfoRow(
              Icons.phone_outlined,
              'Phone',
              owner?.phone ?? 'Not provided',
            ),
            _busInfoRow(
              Icons.email_outlined,
              'Email',
              owner?.email ?? 'Not provided',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _busVerificationInfoCard(
          title: 'Submitted On',
          children: [
            _busInfoRow(
              Icons.calendar_today_outlined,
              'Date',
              _busDateTime(bus.createdAt),
            ),
          ],
        ),
        const SizedBox(height: 14),
        BusGoSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documents',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.description_outlined, color: BusGoTokens.muted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No submitted documents available for this bus.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (bus.status == 'pending_approval' || bus.hasPendingUpdate)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _updateBusVerificationStatus(bus, 'approved'),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _updateBusVerificationStatus(bus, 'rejected'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
              ),
            ],
          )
        else
          BusGoStatusChip(
            label: '${status.toUpperCase()} - NO ACTION REQUIRED',
            tone: tone,
          ),
      ],
    );
  }

  Widget _busVerificationInfoCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) => BusGoSurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _busInfoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: BusGoTokens.blue),
        const SizedBox(width: 10),
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value.trim().isEmpty ? 'Not provided' : value)),
      ],
    ),
  );

  String _pendingText(BusModel bus, String field) {
    final value = bus.pendingUpdate?[field];
    if (value == null) return 'Not provided';
    return value.toString().trim().isEmpty ? 'Not provided' : value.toString();
  }

  Future<void> _updateBusVerificationStatus(BusModel bus, String status) async {
    try {
      if (bus.hasPendingUpdate) {
        if (status == 'approved') {
          await context.read<BusRepository>().approveBusUpdate(bus.id);
        } else {
          await context.read<BusRepository>().rejectBusUpdate(bus.id);
        }
      } else {
        await context.read<BusRepository>().updateStatus(
          busId: bus.id,
          status: status,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? bus.hasPendingUpdate
                      ? 'Bus update approved successfully.'
                      : 'Bus approved successfully.'
                : bus.hasPendingUpdate
                ? 'Bus update rejected.'
                : 'Bus rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update bus status: $error')),
      );
    }
  }

  String _busDateTime(DateTime? value) {
    if (value == null) return 'Date not available';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year}, $hour:$minute $period';
  }

  String _initial(String? value) {
    final name = value?.trim() ?? '';
    return name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  Widget _busSummary({
    required int total,
    required int pending,
    required int approved,
    required int rejected,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.15,
    children: [
      _busSummaryCard('Total Buses', total, BusGoTokens.blue),
      _busSummaryCard('Active', approved, const Color(0xFF159A68)),
      _busSummaryCard('Inactive', rejected, const Color(0xFFD9535B)),
      _busSummaryCard('Pending', pending, const Color(0xFFE99A24)),
    ],
  );

  Widget _busSummaryCard(String label, int count, Color color) => BusGoSurface(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _busFilterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _busFilter == value,
      onSelected: (_) => setState(() => _busFilter = value),
      labelStyle: TextStyle(
        color: _busFilter == value ? Colors.white : BusGoTokens.navy,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: BusGoTokens.blue,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _busFilter == value ? BusGoTokens.blue : const Color(0xFFDCE6F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  Widget _owners() => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(
          child: StreamBuilder<List<AppUser>>(
            key: ValueKey('admin-owners-$_retrySeed'),
            stream: context.read<UserRepository>().watchOwners(),
            builder: (context, ownerSnapshot) {
              if (ownerSnapshot.hasError) {
                return _adminError("Couldn't load owners", ownerSnapshot.error);
              }
              if (!ownerSnapshot.hasData) {
                return const BusGoLoadingState(label: 'Loading owners...');
              }

              return StreamBuilder<List<BusModel>>(
                stream: context.read<BusRepository>().watchAll(),
                builder: (context, busSnapshot) {
                  if (busSnapshot.hasError) {
                    return _adminError(
                      "Couldn't load owner fleet data",
                      busSnapshot.error,
                    );
                  }
                  if (!busSnapshot.hasData) {
                    return const BusGoLoadingState(
                      label: 'Loading owner fleet...',
                    );
                  }

                  final owners = ownerSnapshot.data!;
                  final buses = busSnapshot.data!;
                  final counts = <String, int>{};
                  for (final bus in buses) {
                    counts[bus.ownerId] = (counts[bus.ownerId] ?? 0) + 1;
                  }
                  final search = _ownerSearchController.text
                      .trim()
                      .toLowerCase();
                  final filteredOwners = owners.where((owner) {
                    final status = owner.approvalStatus ?? 'approved';
                    final matchesStatus =
                        _ownerFilter == 'all' || status == _ownerFilter;
                    final searchable =
                        '${owner.name} ${owner.email} ${owner.phone ?? ''}'
                            .toLowerCase();
                    return matchesStatus &&
                        (search.isEmpty || searchable.contains(search));
                  }).toList();
                  final total = owners.length;
                  final active = owners
                      .where(
                        (owner) =>
                            (owner.approvalStatus ?? 'approved') == 'approved',
                      )
                      .length;
                  final inactive = owners
                      .where((owner) => owner.approvalStatus == 'rejected')
                      .length;
                  final pending = owners
                      .where((owner) => owner.approvalStatus == 'pending')
                      .length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _adminHomeHeader(
                        context.watch<AuthProvider>().currentUser?.name.trim(),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Bus Owners',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: BusGoTokens.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Manage and monitor all bus owners on the platform',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BusGoTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _ownerSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone or email...',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ownersFilterChip('all', 'All', total),
                            _ownersFilterChip('approved', 'Active', active),
                            _ownersFilterChip('rejected', 'Inactive', inactive),
                            _ownersFilterChip('pending', 'Pending', pending),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (filteredOwners.isEmpty)
                        const BusGoEmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No owners found',
                          message: 'Try another search or status filter.',
                        )
                      else
                        for (final owner in filteredOwners)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OwnerApprovalCard(
                              owner: owner,
                              busCount: counts[owner.uid] ?? 0,
                            ),
                          ),
                      const SizedBox(height: 6),
                      _ownerSummary(
                        total: total,
                        active: active,
                        inactive: inactive,
                        pending: pending,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _ownersFilterChip(String value, String label, int count) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label ($count)'),
      selected: _ownerFilter == value,
      onSelected: (_) => setState(() => _ownerFilter = value),
      selectedColor: BusGoTokens.blue,
      labelStyle: TextStyle(
        color: _ownerFilter == value ? Colors.white : BusGoTokens.navy,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _ownerFilter == value
            ? BusGoTokens.blue
            : const Color(0xFFDCE6F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  Widget _ownerSummary({
    required int total,
    required int active,
    required int inactive,
    required int pending,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.15,
    children: [
      _ownerSummaryCard('Total Owners', total, BusGoTokens.blue),
      _ownerSummaryCard('Active', active, const Color(0xFF159A68)),
      _ownerSummaryCard('Inactive', inactive, const Color(0xFFD9535B)),
      _ownerSummaryCard('Pending', pending, const Color(0xFFE99A24)),
    ],
  );

  Widget _ownerSummaryCard(String label, int count, Color color) =>
      BusGoSurface(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _trips() => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverToBoxAdapter(
          child: StreamBuilder<List<BookingRequestModel>>(
            key: ValueKey('admin-trips-$_retrySeed'),
            stream: context.read<BookingRequestRepository>().watchAll(),
            builder: (context, tripSnapshot) {
              if (tripSnapshot.hasError) {
                return _adminError("Couldn't load trips", tripSnapshot.error);
              }
              if (!tripSnapshot.hasData) {
                return const BusGoLoadingState(label: 'Loading trips...');
              }

              return StreamBuilder<List<AppUser>>(
                stream: context.read<UserRepository>().watchOwners(),
                builder: (context, ownerSnapshot) {
                  if (ownerSnapshot.hasError) {
                    return _adminError(
                      "Couldn't load trip owners",
                      ownerSnapshot.error,
                    );
                  }
                  if (!ownerSnapshot.hasData) {
                    return const BusGoLoadingState(
                      label: 'Loading trip owners...',
                    );
                  }

                  return StreamBuilder<List<BusModel>>(
                    stream: context.read<BusRepository>().watchAll(),
                    builder: (context, busSnapshot) {
                      if (busSnapshot.hasError) {
                        return _adminError(
                          "Couldn't load trip buses",
                          busSnapshot.error,
                        );
                      }
                      if (!busSnapshot.hasData) {
                        return const BusGoLoadingState(
                          label: 'Loading trip buses...',
                        );
                      }

                      final allTrips = tripSnapshot.data!
                          .where(
                            (request) =>
                                request.status ==
                                    BookingRequestStatus.confirmed ||
                                request.status ==
                                    BookingRequestStatus.paymentRequired ||
                                request.status ==
                                    BookingRequestStatus.completed ||
                                request.status ==
                                    BookingRequestStatus.cancelled,
                          )
                          .toList();
                      final owners = {
                        for (final owner in ownerSnapshot.data!)
                          owner.uid: owner,
                      };
                      final buses = {
                        for (final bus in busSnapshot.data!) bus.id: bus,
                      };
                      final now = DateTime.now();
                      final upcoming = allTrips
                          .where((trip) => _isUpcomingTrip(trip, now))
                          .length;
                      final completed = allTrips
                          .where(
                            (trip) =>
                                trip.status == BookingRequestStatus.completed,
                          )
                          .length;
                      final cancelled = allTrips
                          .where(
                            (trip) =>
                                trip.status == BookingRequestStatus.cancelled,
                          )
                          .length;
                      final search = _tripSearchController.text
                          .trim()
                          .toLowerCase();
                      final trips = allTrips.where((trip) {
                        final bus = buses[trip.busId];
                        final ownerName =
                            owners[trip.ownerId]?.name ?? trip.ownerId;
                        final searchable =
                            '${trip.pickup} ${trip.destination} ${bus?.registrationNumber ?? ''} ${bus?.name ?? trip.busName ?? ''} $ownerName'
                                .toLowerCase();
                        return (search.isEmpty ||
                                searchable.contains(search)) &&
                            _tripMatchesFilter(trip, now);
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _adminHomeHeader(
                            context
                                .watch<AuthProvider>()
                                .currentUser
                                ?.name
                                .trim(),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Trips Management',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: BusGoTokens.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Monitor and manage all scheduled trips',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: BusGoTokens.muted),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _tripSearchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Search by route, bus number or owner...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: PopupMenuButton<String>(
                                tooltip: 'Filter trips',
                                initialValue: _tripFilter,
                                icon: const Icon(Icons.tune_rounded),
                                onSelected: (value) =>
                                    setState(() => _tripFilter = value),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'all',
                                    child: Text('All'),
                                  ),
                                  PopupMenuItem(
                                    value: 'upcoming',
                                    child: Text('Upcoming'),
                                  ),
                                  PopupMenuItem(
                                    value: 'completed',
                                    child: Text('Completed'),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancelled',
                                    child: Text('Cancelled'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _tripFilterChip(
                                  'all',
                                  'All (${allTrips.length})',
                                ),
                                _tripFilterChip(
                                  'upcoming',
                                  'Upcoming ($upcoming)',
                                ),
                                _tripFilterChip(
                                  'completed',
                                  'Completed ($completed)',
                                ),
                                _tripFilterChip(
                                  'cancelled',
                                  'Cancelled ($cancelled)',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (trips.isEmpty)
                            const BusGoEmptyState(
                              icon: Icons.route_outlined,
                              title: 'No trips found',
                              message: 'Try another search or status filter.',
                            )
                          else
                            for (final trip in trips)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AdminTripCard(
                                  request: trip,
                                  bus: buses[trip.busId],
                                  ownerName: owners[trip.ownerId]?.name,
                                  onDetails: () => context.push(
                                    '/admin/booking-details',
                                    extra: trip,
                                  ),
                                ),
                              ),
                          const SizedBox(height: 6),
                          _tripSummary(
                            total: allTrips.length,
                            upcoming: upcoming,
                            completed: completed,
                            cancelled: cancelled,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  bool _isUpcomingTrip(BookingRequestModel trip, DateTime now) =>
      trip.startDate.isAfter(now) &&
      trip.status != BookingRequestStatus.cancelled &&
      trip.status != BookingRequestStatus.completed;

  bool _tripMatchesFilter(BookingRequestModel trip, DateTime now) {
    switch (_tripFilter) {
      case 'upcoming':
        return _isUpcomingTrip(trip, now);
      case 'completed':
        return trip.status == BookingRequestStatus.completed;
      case 'cancelled':
        return trip.status == BookingRequestStatus.cancelled;
      case 'all':
      default:
        return true;
    }
  }

  Widget _tripSummary({
    required int total,
    required int upcoming,
    required int completed,
    required int cancelled,
  }) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.15,
    children: [
      _tripSummaryCard('Total Trips', total, BusGoTokens.blue),
      _tripSummaryCard('Upcoming', upcoming, const Color(0xFF159A68)),
      _tripSummaryCard('Completed', completed, const Color(0xFF159A68)),
      _tripSummaryCard('Cancelled', cancelled, const Color(0xFFD9535B)),
    ],
  );

  Widget _tripSummaryCard(String label, int count, Color color) => BusGoSurface(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BusGoTokens.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tripFilterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _tripFilter == value,
      onSelected: (_) => setState(() => _tripFilter = value),
      labelStyle: TextStyle(
        color: _tripFilter == value ? Colors.white : BusGoTokens.navy,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: BusGoTokens.blue,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _tripFilter == value
            ? BusGoTokens.blue
            : const Color(0xFFDCE6F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  Widget _more() {
    switch (_moreSection) {
      case 'notifications':
        return _notifications();
      case 'help':
        return _helpSupport();
      case 'system':
        return _systemManagement();
      case 'reports':
        return _reports();
      case 'profile':
        return _profile();
      default:
        return _moreHome();
    }
  }

  Widget _moreHome() => _page(
    title: 'Admin tools',
    child: Column(
      children: [
        _toolTile(
          title: 'Notifications',
          subtitle: 'All system updates and activities',
          icon: Icons.notifications_none_rounded,
          section: 'notifications',
        ),
        _toolTile(
          title: 'System Management',
          subtitle: 'Manage platform settings and operations',
          icon: Icons.settings_outlined,
          section: 'system',
        ),
        _toolTile(
          title: 'Reports & Analytics',
          subtitle: 'Platform performance insights',
          icon: Icons.analytics_outlined,
          section: 'reports',
        ),
        _toolTile(
          title: 'Profile',
          subtitle: 'Your account details and settings',
          icon: Icons.person_outline_rounded,
          section: 'profile',
        ),
        _toolTile(
          title: 'Help & Support',
          subtitle: 'Find help and support information',
          icon: Icons.support_agent_rounded,
          section: 'help',
          onTap: () => context.push('/help'),
        ),
      ],
    ),
  );

  Widget _toolTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String section,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BusGoSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F7F7),
          foregroundColor: BusGoTokens.blue,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap ?? () => _openMoreSection(section),
      ),
    ),
  );

  Widget _morePage({required String title, required Widget child}) =>
      CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(title),
            floating: true,
            leading: IconButton(
              tooltip: 'Back to admin tools',
              onPressed: _backMoreSection,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      );

  Widget _notifications() {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return _morePage(
        title: 'Notifications',
        child: Column(
          children: [
            _notificationsHeader(),
            const SizedBox(height: 16),
            const BusGoLoadingState(label: 'Loading admin account...'),
          ],
        ),
      );
    }

    return _morePage(
      title: 'Notifications',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _notificationsHeader(),
          const SizedBox(height: 16),
          StreamBuilder<List<NotificationModel>>(
            stream: context.read<NotificationRepository>().watchForUser(
              user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _adminError(
                  'Couldn\'t load notifications',
                  snapshot.error,
                );
              }
              if (!snapshot.hasData) {
                return const BusGoLoadingState(
                  label: 'Loading notifications...',
                );
              }
              final notifications = snapshot.data!;
              if (notifications.isEmpty) {
                return const BusGoEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message: 'Important platform activity will appear here.',
                );
              }
              final filtered = notifications
                  .where(_matchesNotificationFilter)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (filtered.isEmpty)
                    const BusGoEmptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No notifications in this filter',
                      message: 'Try another notification category.',
                    ),
                  for (final notification in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AdminNotificationCard(
                        notification: notification,
                        onTap: () async {
                          debugPrint(
                            '[BUSGO NAV] Admin notification tapped: id=${notification.id} bookingId=${notification.relatedBookingId ?? 'null'} type=${notification.type}',
                          );
                          if (!notification.isRead) {
                            await context
                                .read<NotificationRepository>()
                                .markAsRead(notification.id);
                          }
                          await _openAdminNotification(notification, user.uid);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAdminNotification(
    NotificationModel notification,
    String adminId,
  ) async {
    final bookingId = notification.relatedBookingId?.trim();
    final busId = notification.busIdForNavigation;
    final notificationType = notification.type;
    final destination = switch (notificationType) {
      'booking_request' ||
      'payment_submitted' ||
      'payment_paid' ||
      'availability_review' => '/admin/booking-details',
      'bus_approved' ||
      'bus_rejected' ||
      'bus_update_submitted' ||
      'bus_update_approved' ||
      'bus_update_rejected' ||
      'bus_deleted_by_owner' => '/owner',
      _ => null,
    };
    debugPrint('[BUSGO RECENT ACTIVITY TAP]');
    debugPrint('type: $notificationType');
    debugPrint('activityId: ${notification.id}');
    debugPrint('bookingId: ${bookingId ?? 'null'}');
    debugPrint('paymentId: null');
    debugPrint('busId: ${busId ?? 'null'}');
    debugPrint('tripId: null');
    debugPrint('reviewId: null');
    debugPrint('destination: ${destination ?? 'fallback'}');
    debugPrint('[/BUSGO RECENT ACTIVITY TAP]');
    debugPrint('[BUSGO NOTIFICATION TAP]');
    debugPrint('notificationId: ${notification.id}');
    debugPrint('type: ${notification.type}');
    debugPrint('title: ${notification.title}');
    debugPrint('recipientId: $adminId');
    debugPrint('busId: ${busId ?? 'null'}');
    debugPrint('bookingId: ${bookingId ?? 'null'}');
    debugPrint('tripId: null');
    debugPrint('reviewId: null');
    debugPrint('destination: ${destination ?? 'fallback'}');
    debugPrint('[/BUSGO NOTIFICATION TAP]');
    if (notification.type == 'owner_message') {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(notification.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 16),
                Text('Owner: ${notification.relatedOwnerName ?? 'Unknown'}'),
                Text('Owner ID: ${notification.relatedOwnerId ?? 'Unknown'}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (notification.type == 'bus_deleted_by_owner') {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(notification.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 16),
                Text('Bus: ${notification.relatedBusName ?? 'Not available'}'),
                Text(
                  'Registration: ${notification.relatedRegistrationNumber?.trim().isNotEmpty == true ? notification.relatedRegistrationNumber : 'Not available'}',
                ),
                Text(
                  'Owner: ${notification.relatedOwnerName ?? 'Not available'}',
                ),
                Text(
                  'Owner ID: ${notification.relatedOwnerId ?? 'Not available'}',
                ),
                Text('Bus ID: ${notification.relatedBusId ?? 'Not available'}'),
                Text(
                  'Deleted: ${(notification.deletedAt ?? notification.createdAt).toLocal().toString().split('.').first}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (bookingId != null && bookingId.isNotEmpty) {
      try {
        final request = await context.read<BookingRequestRepository>().getById(
          bookingId,
        );
        debugPrint('[BUSGO RECENT ACTIVITY LOAD]');
        debugPrint('type: ${notification.type}');
        debugPrint('collection: booking_requests');
        debugPrint('documentId: $bookingId');
        debugPrint('exists: ${request != null}');
        debugPrint('result: ${request != null ? request.id : 'not_found'}');
        debugPrint('[/BUSGO RECENT ACTIVITY LOAD]');
        debugPrint('[BUSGO NOTIFICATION LOAD]');
        debugPrint('type: ${notification.type}');
        debugPrint('documentId: $bookingId');
        debugPrint('collection: booking_requests');
        debugPrint('exists: ${request != null}');
        debugPrint('result: ${request != null ? request.id : 'not_found'}');
        debugPrint('[/BUSGO NOTIFICATION LOAD]');
        if (!mounted) return;
        if (request != null) {
          debugPrint(
            '[BUSGO NAV] Admin notification opening booking details for bookingId=$bookingId',
          );
          context.push('/admin/booking-details', extra: request);
          return;
        }
      } catch (error) {
        debugPrint('[BUSGO RECENT ACTIVITY ERROR]');
        debugPrint('type: ${notification.type}');
        debugPrint('operation: load_booking');
        debugPrint('identifier: $bookingId');
        debugPrint('errorCode: ${error.runtimeType}');
        debugPrint('errorMessage: $error');
        debugPrint('[/BUSGO RECENT ACTIVITY ERROR]');
        debugPrint('[BUSGO NOTIFICATION ERROR]');
        debugPrint('type: ${notification.type}');
        debugPrint('operation: load_booking');
        debugPrint('collection: booking_requests');
        debugPrint('documentId: $bookingId');
        debugPrint('errorCode: ${error.runtimeType}');
        debugPrint('errorMessage: $error');
        debugPrint('[/BUSGO NOTIFICATION ERROR]');
        debugPrint('[BUSGO NAV] Admin notification fetch failed: $error');
      }
    }

    if (!mounted) return;
    final normalized = notification.type.toLowerCase();
    if (busId != null && busId.isNotEmpty && normalized.contains('bus')) {
      try {
        final bus = await context.read<BusRepository>().getById(busId);
        if (!mounted) return;
        if (bus == null) {
          await _showUnavailableBusNotification(notification, busId);
          return;
        }
        setState(() {
          _selectedIndex = 2;
          _selectedBusId = bus.id;
          _moreSectionHistory.clear();
          _moreSection = 'home';
        });
        return;
      } catch (error) {
        debugPrint('[BUSGO NAV] Bus notification fetch failed: $error');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this bus update.')),
      );
      return;
    }
    if (normalized.contains('booking') ||
        normalized.contains('request') ||
        normalized.contains('trip')) {
      _openMoreSection('requests');
      return;
    }
    if (normalized.contains('owner')) {
      _openMoreSection('owners');
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
              'This bus was deleted and is no longer available for review.',
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

  Widget _helpSupport() {
    final adminName = context.watch<AuthProvider>().currentUser?.name.trim();
    final query = _helpSearchController.text.trim();
    return _morePage(
      title: 'Help & Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _adminHomeHeader(adminName),
          const SizedBox(height: 18),
          Text(
            'Help & Support',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Get help, support and find answers',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _helpSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search FAQs, topics or keywords...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _helpSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _helpActionCard(
            title: 'BUSGO Help',
            subtitle: 'Read guidance for accounts and trips',
            icon: Icons.support_agent_rounded,
            color: BusGoTokens.blue,
            onTap: _openHelpCenter,
          ),
          _helpActionCard(
            title: 'View FAQs',
            subtitle: 'Find answers to common questions',
            icon: Icons.quiz_outlined,
            color: const Color(0xFF159A68),
            onTap: _openHelpCenter,
          ),
          const SizedBox(height: 10),
          Text(
            'Popular Topics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final topic in _helpTopics)
            _helpTopicCard(
              title: topic.$1,
              icon: topic.$2,
              color: topic.$3,
              onTap: _openHelpCenter,
            ),
          const SizedBox(height: 6),
          BusGoSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.help_center_outlined,
                  color: BusGoTokens.blue,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  'BUSGO help topics',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  query.isEmpty
                      ? 'Open the FAQ screen for account and trip guidance.'
                      : 'No topic title contains "$query". Open FAQs to browse all help topics.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BusGoSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Still need help?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Browse the BUSGO FAQs for account and trip guidance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _openHelpCenter,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Browse FAQs'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _helpTopics = [
    ('Account & Login', Icons.person_outline_rounded, BusGoTokens.blue),
    ('Bus Management', Icons.directions_bus_outlined, Color(0xFF159A68)),
    ('Trip Management', Icons.route_outlined, Color(0xFFF59E0B)),
    ('Booking & Reservations', Icons.book_outlined, Color(0xFF7047D6)),
    ('Payments & Transactions', Icons.payments_outlined, Color(0xFF159A9C)),
    ('Notifications', Icons.notifications_none_rounded, Color(0xFFE0447A)),
    ('Technical Support', Icons.build_outlined, Color(0xFFD9535B)),
  ];

  Widget _helpActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => _settingsRow(
    title: title,
    subtitle: subtitle,
    icon: icon,
    color: color,
    onTap: onTap,
  );

  Widget _helpTopicCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BusGoSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );

  void _openHelpCenter() => context.push('/help');

  Widget _notificationsHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _adminHomeHeader(context.watch<AuthProvider>().currentUser?.name.trim()),
      const SizedBox(height: 22),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Stay updated with all important activities',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final user = context.read<AuthProvider>().currentUser;
              if (user != null) _markAllNotificationsRead(user.uid);
            },
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Mark All Read'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _notificationFilterChip('all', 'All'),
            _notificationFilterChip('unread', 'Unread'),
            _notificationFilterChip('system', 'System'),
            _notificationFilterChip('booking', 'Bookings'),
            _notificationFilterChip('owner', 'Owners'),
            _notificationFilterChip('bus', 'Buses'),
            _notificationFilterChip('trip', 'Trips'),
          ],
        ),
      ),
    ],
  );

  Widget _notificationFilterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _notificationFilter == value,
      onSelected: (_) => setState(() => _notificationFilter = value),
      labelStyle: TextStyle(
        color: _notificationFilter == value ? Colors.white : BusGoTokens.navy,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: BusGoTokens.blue,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _notificationFilter == value
            ? BusGoTokens.blue
            : const Color(0xFFDCE6F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  );

  bool _matchesNotificationFilter(NotificationModel notification) {
    if (_notificationFilter == 'all') return true;
    if (_notificationFilter == 'unread') return !notification.isRead;
    final type = notification.type.toLowerCase();
    if (_notificationFilter == 'owner') return type.contains('owner');
    if (_notificationFilter == 'bus') return type.contains('bus');
    if (_notificationFilter == 'booking') {
      return type.contains('booking') || type.contains('request');
    }
    if (_notificationFilter == 'trip') return type.contains('trip');
    return !_matchesNotificationFilterForKnownType(type);
  }

  Future<void> _markAllNotificationsRead(String userId) async {
    try {
      await context.read<NotificationRepository>().markAllAsRead(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to mark notifications as read: $error'),
          ),
        );
      }
    }
  }

  bool _matchesNotificationFilterForKnownType(String type) =>
      type.contains('owner') ||
      type.contains('bus') ||
      type.contains('booking') ||
      type.contains('trip') ||
      type.contains('payment');

  Widget _systemManagement() {
    final authProvider = context.watch<AuthProvider>();
    return _morePage(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _adminHomeHeader(
            context.watch<AuthProvider>().currentUser?.name.trim(),
          ),
          const SizedBox(height: 18),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Manage system settings and preferences',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
          ),
          const SizedBox(height: 16),
          _settingsRow(
            title: 'General Settings',
            subtitle: 'Manage application preferences',
            icon: Icons.settings_outlined,
            color: BusGoTokens.blue,
            onTap: () => context.push('/settings'),
          ),
          _settingsRow(
            title: 'User Management',
            subtitle: 'Manage bus owners and user access',
            icon: Icons.people_outline_rounded,
            color: const Color(0xFF159A68),
            onTap: () => setState(() => _selectedIndex = 3),
          ),
          _settingsRow(
            title: 'Notification Settings',
            subtitle: 'View notification activity and updates',
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => _openMoreSection('notifications'),
          ),
          _settingsRow(
            title: 'Security Settings',
            subtitle: 'Update your account password',
            icon: Icons.shield_outlined,
            color: const Color(0xFF7047D6),
            onTap: () => context.push('/change-password'),
          ),
          _settingsRow(
            title: 'About BUSGO',
            subtitle: 'View app information and policies',
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF159A9C),
            onTap: () => context.push('/legal/agreement'),
          ),
          _settingsRow(
            title: 'Help & Support',
            subtitle: 'Read answers to common questions',
            icon: Icons.support_agent_rounded,
            color: const Color(0xFF159A68),
            onTap: () => context.push('/help'),
          ),
          const SizedBox(height: 8),
          _logoutCard(authProvider),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BusGoSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );

  Widget _reports() => _morePage(
    title: 'Reports & Analytics',
    child: StreamBuilder<List<BusModel>>(
      stream: context.read<BusRepository>().watchAll(),
      builder: (context, busSnapshot) {
        if (busSnapshot.hasError) {
          return _adminError("Couldn't load analytics", busSnapshot.error);
        }
        if (!busSnapshot.hasData) {
          return const BusGoLoadingState(label: 'Loading report data...');
        }
        return StreamBuilder<List<BookingRequestModel>>(
          stream: context.read<BookingRequestRepository>().watchAll(),
          builder: (context, requestSnapshot) {
            if (requestSnapshot.hasError) {
              return _adminError(
                "Couldn't load booking analytics",
                requestSnapshot.error,
              );
            }
            if (!requestSnapshot.hasData) {
              return const BusGoLoadingState(
                label: 'Loading booking analytics...',
              );
            }
            return StreamBuilder<List<AppUser>>(
              stream: context.read<UserRepository>().watchAll(),
              builder: (context, userSnapshot) {
                if (userSnapshot.hasError) {
                  return _adminError(
                    "Couldn't load user analytics",
                    userSnapshot.error,
                  );
                }
                if (!userSnapshot.hasData) {
                  return const BusGoLoadingState(
                    label: 'Loading user analytics...',
                  );
                }

                final buses = busSnapshot.data!;
                final users = userSnapshot.data!;
                final requests = requestSnapshot.data!;
                final start = _reportStart();
                final periodRequests = requests
                    .where(
                      (request) =>
                          _reportPeriod == 'all' ||
                          !request.createdAt.isBefore(start),
                    )
                    .toList();
                final owners = users
                    .where((user) => user.role == AppUserRole.owner)
                    .length;
                final approvedBuses = buses
                    .where((bus) => bus.status == 'approved')
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _adminHomeHeader(
                      context.watch<AuthProvider>().currentUser?.name.trim(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Reports & Analytics',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: BusGoTokens.navy,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Insights and statistics about your bus platform',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BusGoTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PopupMenuButton<String>(
                        initialValue: _reportPeriod,
                        onSelected: (value) =>
                            setState(() => _reportPeriod = value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: '7d',
                            child: Text('Last 7 Days'),
                          ),
                          PopupMenuItem(
                            value: '30d',
                            child: Text('Last 30 Days'),
                          ),
                          PopupMenuItem(
                            value: 'year',
                            child: Text('This Year'),
                          ),
                          PopupMenuItem(value: 'all', child: Text('All Time')),
                        ],
                        child: Chip(
                          avatar: const Icon(
                            Icons.calendar_month_outlined,
                            size: 17,
                          ),
                          label: Text(_reportPeriodLabel()),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFDCE6F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                      children: [
                        _reportMetricCard(
                          'Total Users',
                          users.length,
                          Icons.people_outline_rounded,
                          BusGoTokens.blue,
                        ),
                        _reportMetricCard(
                          'Bus Owners',
                          owners,
                          Icons.business_outlined,
                          const Color(0xFF7047D6),
                        ),
                        _reportMetricCard(
                          'Total Buses',
                          buses.length,
                          Icons.directions_bus_outlined,
                          const Color(0xFF159A68),
                        ),
                        _reportMetricCard(
                          'Total Bookings',
                          periodRequests.length,
                          Icons.route_outlined,
                          BusGoTokens.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _reportBookingsOverview(periodRequests),
                    const SizedBox(height: 14),
                    _reportTopRoutes(periodRequests),
                    const SizedBox(height: 14),
                    _reportBookingTrends(periodRequests),
                    const SizedBox(height: 14),
                    _reportBusUtilization(periodRequests, approvedBuses),
                    const SizedBox(height: 14),
                    _reportUserGrowth(users),
                  ],
                );
              },
            );
          },
        );
      },
    ),
  );

  DateTime _reportStart() {
    final now = DateTime.now();
    switch (_reportPeriod) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case 'year':
        return DateTime(now.year, 1, 1);
      case 'all':
        return DateTime(2000);
      case '30d':
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  String _reportPeriodLabel() => switch (_reportPeriod) {
    '7d' => 'Last 7 Days',
    'year' => 'This Year',
    'all' => 'All Time',
    _ => 'Last 30 Days',
  };

  Widget _reportMetricCard(
    String label,
    int value,
    IconData icon,
    Color color,
  ) => BusGoStatCard(label: label, value: '$value', icon: icon, accent: color);

  Widget _reportBookingsOverview(List<BookingRequestModel> requests) {
    if (requests.isEmpty) {
      return _reportEmpty(
        'Bookings Overview',
        'No booking data for this period.',
      );
    }
    final now = DateTime.now();
    final buckets = List<int>.filled(7, 0);
    for (final request in requests) {
      final age = now.difference(request.createdAt).inDays;
      final index = 6 - age.clamp(0, 6);
      buckets[index]++;
    }
    final maxValue = buckets.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return _reportSection(
      'Bookings Overview',
      Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _reportPeriodLabel(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BusGoTokens.muted),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < buckets.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${buckets[index]}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height:
                                105 *
                                (buckets[index] / maxValue).clamp(0.04, 1),
                            decoration: BoxDecoration(
                              color: BusGoTokens.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _reportDayLabel(now, 6 - index),
                            style: const TextStyle(fontSize: 10),
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

  Widget _reportTopRoutes(List<BookingRequestModel> requests) {
    final routes = <String, int>{};
    for (final request in requests) {
      final route = '${request.pickup} → ${request.destination}';
      routes[route] = (routes[route] ?? 0) + 1;
    }
    final ranked = routes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return _reportEmpty('Top Routes', 'No route data for this period.');
    }
    return _reportSection(
      'Top Routes',
      Column(
        children: [
          for (final route in ranked.take(5))
            _reportListRow(
              route.key,
              '${route.value} bookings',
              Icons.route_outlined,
            ),
        ],
      ),
    );
  }

  Widget _reportBookingTrends(List<BookingRequestModel> requests) {
    final categories = <String, int>{};
    for (final request in requests) {
      final category = request.tripType.trim().isEmpty
          ? 'Other'
          : request.tripType.trim();
      categories[category] = (categories[category] ?? 0) + 1;
    }
    final ranked = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return _reportEmpty(
        'Booking Trends',
        'No booking classification data for this period.',
      );
    }
    final total = requests.length;
    return _reportSection(
      'Booking Trends',
      Column(
        children: [
          for (final item in ranked.take(5))
            _reportListRow(
              item.key,
              '${(item.value * 100 / total).round()}% · ${item.value}',
              Icons.insights_outlined,
            ),
        ],
      ),
    );
  }

  Widget _reportBusUtilization(
    List<BookingRequestModel> requests,
    int approvedBuses,
  ) {
    if (approvedBuses == 0) {
      return _reportEmpty(
        'Bus Utilization',
        'No approved buses available for utilization analysis.',
      );
    }
    final usedBusIds = requests
        .map((request) => request.busId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final utilization = (usedBusIds.length / approvedBuses * 100)
        .clamp(0, 100)
        .round();
    return _reportSection(
      'Bus Utilization',
      Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: utilization / 100,
                  strokeWidth: 9,
                  color: BusGoTokens.blue,
                  backgroundColor: const Color(0xFFE5EEF8),
                ),
                Text(
                  '$utilization%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BusGoTokens.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${usedBusIds.length} of $approvedBuses approved buses have booking activity in this period.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportUserGrowth(List<AppUser> users) {
    if (users.isEmpty) {
      return _reportEmpty('User Growth', 'No user records available.');
    }
    final now = DateTime.now();
    final monthly = List<int>.filled(6, 0);
    for (final user in users) {
      final createdAt = user.createdAt;
      if (createdAt == null) continue;
      final monthsAgo =
          (now.year - createdAt.year) * 12 + now.month - createdAt.month;
      if (monthsAgo >= 0 && monthsAgo < 6) {
        monthly[5 - monthsAgo]++;
      }
    }
    final maxValue = monthly.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    return _reportSection(
      'User Growth',
      Column(
        children: [
          Text(
            '${users.length} total users',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: BusGoTokens.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < monthly.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height:
                                90 * (monthly[index] / maxValue).clamp(0.04, 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7047D6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _reportMonthLabel(now, 5 - index),
                            style: const TextStyle(fontSize: 10),
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

  Widget _reportSection(String title, Widget child) => BusGoSurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _reportEmpty(String title, String message) => _reportSection(
    title,
    BusGoEmptyState(
      icon: Icons.insights_outlined,
      title: 'No data available',
      message: message,
    ),
  );

  Widget _reportListRow(String title, String value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: BusGoTokens.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: BusGoTokens.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  String _reportDayLabel(DateTime now, int daysAgo) => [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ][now.subtract(Duration(days: daysAgo)).weekday % 7];

  String _reportMonthLabel(DateTime now, int monthsAgo) {
    final month = DateTime(now.year, now.month - monthsAgo);
    return const [
      '',
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
    ][month.month];
  }

  Widget _profile() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (authProvider.isLoading) {
      return _morePage(
        title: 'Admin Profile',
        child: const BusGoLoadingState(label: 'Loading admin profile...'),
      );
    }

    if (user == null) {
      return _morePage(
        title: 'Admin Profile',
        child: BusGoErrorState(
          title: 'Profile unavailable',
          message:
              authProvider.errorMessage ??
              'We could not load the signed-in admin profile.',
          onRetry: _retryAdminData,
        ),
      );
    }

    debugPrint(
      '[BUSGO ADMIN PROFILE LOAD]\nuid=${user.uid}\ndocumentExists=true\nname=${user.name.trim().isEmpty ? 'Not provided' : user.name.trim()}\nrole=${user.role.name}\n[/BUSGO ADMIN PROFILE LOAD]',
    );

    final displayName = user.name.trim().isEmpty
        ? 'Not provided'
        : user.name.trim();
    final initials = displayName
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final email = user.email.trim().isEmpty
        ? 'Not provided'
        : user.email.trim();

    return _morePage(
      title: 'Admin Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _profileHero(user, displayName, email, initials),
          const SizedBox(height: 16),
          _profileSummary(user),
          const SizedBox(height: 22),
          _profileSectionTitle('Account & Preferences'),
          const SizedBox(height: 10),
          _profileMenu(
            title: 'Personal Information',
            subtitle: 'Update your name, phone number and profile photo',
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF246BFE),
            onTap: () => context.push('/edit-profile'),
          ),
          _profileMenu(
            title: 'Security',
            subtitle: 'Change your password and manage account safety',
            icon: Icons.lock_outline_rounded,
            iconColor: const Color(0xFF7B61FF),
            onTap: () => context.push('/change-password'),
          ),
          _profileMenu(
            title: 'Notifications',
            subtitle: 'View recent dashboard and booking activity',
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFFE38A1A),
            onTap: () => _openMoreSection('notifications'),
          ),
          _profileMenu(
            title: 'App Settings',
            subtitle: 'Manage your app preferences',
            icon: Icons.settings_outlined,
            iconColor: const Color(0xFF159A68),
            onTap: () => context.push('/settings'),
          ),
          _profileMenu(
            title: 'Help & Support',
            subtitle: 'Browse BUSGO help articles',
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFF159A9C),
            onTap: () => context.push('/help'),
          ),
          _profileMenu(
            title: 'About BUSGO',
            subtitle: 'View application information',
            icon: Icons.info_outline_rounded,
            onTap: () => context.push('/legal/agreement'),
          ),
          _profileMenu(
            title: 'Terms of Service',
            subtitle: 'Read BUSGO terms',
            icon: Icons.description_outlined,
            onTap: () => context.push('/legal/terms'),
          ),
          _profileMenu(
            title: 'Privacy Policy',
            subtitle: 'Review account data practices',
            icon: Icons.privacy_tip_outlined,
            onTap: () => context.push('/legal/privacy'),
          ),
          const SizedBox(height: 14),
          _logoutCard(authProvider),
        ],
      ),
    );
  }

  Widget _profileHero(
    AppUser user,
    String displayName,
    String email,
    String initials,
  ) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1769D2), Color(0xFF13B9C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x30176BD2),
          blurRadius: 20,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -8,
          bottom: -8,
          child: Icon(
            Icons.directions_bus_filled_rounded,
            size: 106,
            color: Color(0x24FFFFFF),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BusGoBrandMark(compact: true, light: true),
                const Spacer(),
                const Icon(Icons.verified_rounded, color: Colors.white70),
                const SizedBox(width: 5),
                Text(
                  'ADMIN ACCOUNT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BusGoProfileAvatar(
                      imageUrl: user.profileImageUrl,
                      size: 82,
                      label: initials.isEmpty ? 'A' : initials,
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => context.push('/edit-profile'),
                          tooltip: 'Edit profile photo',
                          icon: const Icon(Icons.camera_alt_rounded, size: 17),
                          color: BusGoTokens.blue,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          user.role == AppUserRole.admin
                              ? 'Administrator'
                              : user.role.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Managing today for a better tomorrow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _profileSummary(AppUser user) => BusGoSurface(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 18,
      children: [
        _profileSummaryItem(
          Icons.calendar_today_outlined,
          'Member since',
          user.createdAt == null
              ? 'Not provided'
              : _formatProfileDateShort(user.createdAt!),
        ),
        _profileSummaryItem(
          Icons.circle,
          'Account status',
          user.approvalStatus?.trim().isNotEmpty == true
              ? user.approvalStatus!.trim()
              : 'Not provided',
        ),
        _profileSummaryItem(Icons.badge_outlined, 'Role', user.role.label),
        _profileSummaryItem(
          Icons.phone_outlined,
          'Contact',
          user.phone?.trim().isNotEmpty == true
              ? user.phone!.trim()
              : 'Not provided',
        ),
      ],
    ),
  );

  Widget _profileSummaryItem(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) => SizedBox(
    width: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: valueColor ?? BusGoTokens.blue),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BusGoTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? BusGoTokens.navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _profileSectionTitle(String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      color: BusGoTokens.navy,
      fontWeight: FontWeight.w900,
    ),
  );

  Widget _profileMenu({
    required String title,
    required String subtitle,
    required IconData icon,
    Color iconColor = BusGoTokens.blue,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BusGoSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BusGoTokens.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );

  String _formatProfileDateShort(DateTime date) =>
      '${date.day} ${_profileMonth(date.month).substring(0, 3)} ${date.year}';

  String _profileMonth(int month) => const [
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
  ][month - 1];

  Widget _logoutCard(AuthProvider authProvider) => BusGoSurface(
    padding: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE7EC),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.logout_rounded, color: Color(0xFFB4234D)),
      ),
      title: const Text(
        'Logout',
        style: TextStyle(color: Color(0xFFB4234D), fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Sign out from your account'),
      onTap: authProvider.isBusy
          ? null
          : () async {
              await authProvider.signOut();
              if (mounted) context.go('/login');
            },
    ),
  );

  Widget _page({required String title, required Widget child}) =>
      CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(title),
            floating: true,
            automaticallyImplyLeading: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      );
}

class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({required this.notification, this.onTap});

  final NotificationModel notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForType(notification.type);
    return BusGoSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: notification.isRead
                  ? const Color(0xFFE8F7F7)
                  : const Color(0xFFE8F0FF),
              foregroundColor: notification.isRead
                  ? BusGoTokens.blue
                  : const Color(0xFF2367D1),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notification.message),
                  const SizedBox(height: 7),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: BusGoTokens.blue,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: BusGoTokens.blue),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final value = type.toLowerCase();
    if (value.contains('owner')) return Icons.people_alt_outlined;
    if (value.contains('bus')) return Icons.directions_bus_outlined;
    if (value.contains('payment')) return Icons.payments_outlined;
    if (value.contains('booking') || value.contains('trip')) {
      return Icons.route_outlined;
    }
    return Icons.info_outline_rounded;
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _AdminTripCard extends StatelessWidget {
  const _AdminTripCard({
    required this.request,
    required this.bus,
    required this.ownerName,
    required this.onDetails,
  });

  final BookingRequestModel request;
  final BusModel? bus;
  final String? ownerName;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final statusTone = request.status == BookingRequestStatus.cancelled
        ? BusGoStatusTone.negative
        : request.status == BookingRequestStatus.completed
        ? BusGoStatusTone.positive
        : BusGoStatusTone.info;
    return InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bus != null)
              BusGoBusImage(
                imageUrl: bus!.imageUrl,
                height: 112,
                borderRadius: 18,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${request.pickup} to ${request.destination}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: BusGoTokens.navy,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BusGoStatusChip(
                        label: request.status.label.toUpperCase(),
                        tone: statusTone,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: BusGoTokens.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_date(request.startDate)} | ${_time(request.startDate)}',
                  ),
                  Text(
                    'Bus: ${bus?.registrationNumber.trim().isNotEmpty == true ? bus!.registrationNumber : request.busName ?? 'Bus not available'}',
                  ),
                  Text(
                    'Owner: ${ownerName?.trim().isNotEmpty == true ? ownerName : request.ownerId}',
                  ),
                  const SizedBox(height: 10),
                  BusGoSecondaryButton(
                    label: 'Open Trip Details',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: onDetails,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AdminCustomerRequestCard extends StatelessWidget {
  const _AdminCustomerRequestCard({
    required this.request,
    required this.bus,
    required this.onDetails,
  });

  final BookingRequestModel request;
  final BusModel? bus;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final pending =
        request.status == BookingRequestStatus.pendingOwner ||
        request.status == BookingRequestStatus.ownerAccepted ||
        request.status == BookingRequestStatus.adminReview;
    final rejected =
        request.status == BookingRequestStatus.ownerRejected ||
        request.status == BookingRequestStatus.adminRejected ||
        request.status == BookingRequestStatus.cancelled;
    final subject = request.busName?.trim().isNotEmpty == true
        ? request.busName!
        : request.tripType;
    final message = request.specialRequirements.trim().isNotEmpty
        ? request.specialRequirements.trim()
        : '${request.pickup} to ${request.destination}';
    final customerName = request.customerName?.trim().isNotEmpty == true
        ? request.customerName!.trim()
        : request.customerId;
    final initials = customerName.isEmpty
        ? 'C'
        : customerName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return InkWell(
      onTap: onDetails,
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: const Color(0xFFE8F2FF),
                  foregroundColor: BusGoTokens.blue,
                  child: Text(initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: BusGoTokens.navy,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(customerName),
                    ],
                  ),
                ),
                BusGoStatusChip(
                  label: pending
                      ? 'PENDING'
                      : rejected
                      ? 'REJECTED'
                      : 'ACCEPTED',
                  tone: pending
                      ? BusGoStatusTone.warning
                      : rejected
                      ? BusGoStatusTone.negative
                      : BusGoStatusTone.positive,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: BusGoTokens.blue,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
            ),
            const SizedBox(height: 8),
            Text('Customer ID: ${request.customerId}'),
            Text('Submitted: ${_date(request.createdAt)}'),
            if (bus != null)
              Text(
                'Bus: ${bus!.registrationNumber.trim().isEmpty ? bus!.name : bus!.registrationNumber}',
              ),
            const SizedBox(height: 10),
            BusGoSecondaryButton(
              label: 'Open Request Details',
              icon: Icons.arrow_forward_rounded,
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

class _AdminRequestCard extends StatefulWidget {
  const _AdminRequestCard({
    required this.request,
    required this.bus,
    required this.onDetails,
  });

  final BookingRequestModel request;
  final BusModel? bus;
  final VoidCallback? onDetails;

  @override
  State<_AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends State<_AdminRequestCard> {
  bool _checking = false;
  bool? _available;

  Future<void> _checkAvailability() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final available = await context
          .read<BookingRequestRepository>()
          .isBusAvailable(
            busId: widget.request.busId,
            startDate: widget.request.startDate,
            endDate: widget.request.endDate,
            excludingRequestId: widget.request.id,
          );
      if (mounted) setState(() => _available = available);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability could not be checked.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _confirm() async {
    if (_checking) return;
    final repository = context.read<BookingRequestRepository>();
    try {
      await repository.confirmAfterAvailabilityCheck(request: widget.request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip confirmed. Payment is now required.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The trip could not be confirmed.')),
        );
      }
    }
  }

  Future<void> _reject() async {
    if (_checking) return;
    final repository = context.read<BookingRequestRepository>();
    final reasonController = TextEditingController(
      text: 'Bus is already booked for the selected dates.',
    );
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject trip?'),
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
    if (shouldReject != true || reason.isEmpty) return;
    try {
      await repository.rejectAfterAvailabilityCheck(
        request: widget.request,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip rejected successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The trip could not be rejected.')),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await context.read<BookingRequestRepository>().markPaymentPaid(
        request: widget.request,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as verified.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment could not be verified.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final ownerAccepted =
        request.status == BookingRequestStatus.ownerAccepted ||
        request.status == BookingRequestStatus.adminReview;
    final paymentSubmitted =
        (request.status == BookingRequestStatus.paymentRequired ||
            request.status == BookingRequestStatus.confirmed) &&
        request.paymentStatus == PaymentStatus.submitted;
    return BusGoSurface(
      padding: widget.bus == null ? null : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.bus != null)
            BusGoBusImage(
              imageUrl: widget.bus!.imageUrl,
              height: 112,
              borderRadius: 18,
            ),
          if (widget.bus != null) const SizedBox(height: 2),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F7F7),
                foregroundColor: BusGoTokens.blue,
                child: const Icon(Icons.route_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: widget.bus == null
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.busName ?? 'Whole-bus request',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${request.pickup} to ${request.destination}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              BusGoStatusChip(
                label: request.status.label.toUpperCase(),
                tone: _requestStatusTone(request.status),
              ),
            ],
          ),
          Padding(
            padding: widget.bus == null
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Customer: ${request.customerName ?? 'Customer'}'),
                Text(
                  '${request.tripType} | ${request.passengerCount} passengers',
                ),
                Text('Amount: ₹${request.estimatedAmount.toStringAsFixed(0)}'),
                Text(
                  '${request.startDate.day}/${request.startDate.month}/${request.startDate.year} - ${request.endDate.day}/${request.endDate.month}/${request.endDate.year}',
                ),
              ],
            ),
          ),
          if (paymentSubmitted) ...[
            const SizedBox(height: 14),
            BusGoSurface(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment submitted',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Reference: ${request.paymentReference ?? 'not provided'}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Verify payment',
                    onPressed: _checking ? null : _verifyPayment,
                    icon: const Icon(Icons.verified_rounded),
                  ),
                ],
              ),
            ),
          ],
          if (ownerAccepted) ...[
            const SizedBox(height: 14),
            if (_available == null)
              FilledButton.icon(
                onPressed: _checking ? null : _checkAvailability,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  _checking
                      ? 'Checking availability...'
                      : 'Check bus availability',
                ),
              ),
            if (_available == false)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus unavailable for the selected dates.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject with reason'),
                    ),
                  ],
                ),
              ),
            if (_available == true)
              FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Confirm trip & request payment'),
              ),
            if (_available == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject trip'),
                ),
              ),
          ] else if (request.status == BookingRequestStatus.pendingOwner)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('OWNER PENDING'),
            ),
          if (widget.onDetails != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: widget.bus == null
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 14),
              child: BusGoSecondaryButton(
                label: 'Open Booking Details',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onDetails,
              ),
            ),
          ],
        ],
      ),
    );
  }

  BusGoStatusTone _requestStatusTone(BookingRequestStatus status) {
    if (status == BookingRequestStatus.completed ||
        status == BookingRequestStatus.confirmed ||
        status == BookingRequestStatus.paymentRequired) {
      return BusGoStatusTone.positive;
    }
    if (status == BookingRequestStatus.ownerRejected ||
        status == BookingRequestStatus.adminRejected ||
        status == BookingRequestStatus.cancelled) {
      return BusGoStatusTone.negative;
    }
    if (status == BookingRequestStatus.ownerAccepted ||
        status == BookingRequestStatus.adminReview) {
      return BusGoStatusTone.warning;
    }
    return BusGoStatusTone.info;
  }
}

class _AdminBusCard extends StatefulWidget {
  const _AdminBusCard({required this.bus, this.ownerName, this.onOpen});

  final BusModel bus;
  final String? ownerName;
  final VoidCallback? onOpen;

  @override
  State<_AdminBusCard> createState() => _AdminBusCardState();
}

class _AdminBusCardState extends State<_AdminBusCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final pending =
        widget.bus.status == 'pending_approval' || widget.bus.hasPendingUpdate;
    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BusGoBusImage(imageUrl: widget.bus.imageUrl, height: 118),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.bus.registrationNumber.trim().isEmpty
                              ? 'Registration not provided'
                              : widget.bus.registrationNumber,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      BusGoStatusChip(
                        label: widget.bus.hasPendingUpdate
                            ? 'BUS UPDATE'
                            : _statusLabel(widget.bus.status),
                        tone: pending
                            ? BusGoStatusTone.warning
                            : widget.bus.status == 'approved'
                            ? BusGoStatusTone.positive
                            : BusGoStatusTone.negative,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: BusGoTokens.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${widget.bus.name} | ${widget.bus.capacity} Seater'),
                  Text(
                    'Owner: ${widget.ownerName?.trim().isNotEmpty == true ? widget.ownerName : widget.bus.ownerId}',
                  ),
                  Text('Submitted: ${_date(widget.bus.createdAt)}'),
                  if (widget.bus.tripTypes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final type in widget.bus.tripTypes.take(3))
                          BusGoStatusChip(
                            label: type,
                            tone: BusGoStatusTone.info,
                          ),
                      ],
                    ),
                  ],
                  if (pending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _handleAction('approved'),
                            child: Text(
                              _isProcessing ? 'Approving...' : 'Approve',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _handleAction('rejected'),
                            child: Text(
                              _isProcessing ? 'Rejecting...' : 'Reject',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action) async {
    if (_isProcessing) return;
    final adminUid = context.read<AuthProvider>().currentUser?.uid ?? 'unknown';
    final busId = widget.bus.id;
    final ownerId = widget.bus.ownerId;
    final currentStatus = widget.bus.pendingUpdateStatus ?? widget.bus.status;
    debugPrint('[BUSGO ADMIN BUS ACTION]');
    debugPrint('source: ADMIN_BUS_LIST');
    debugPrint('action: ${action.toUpperCase()}');
    debugPrint('adminUid: $adminUid');
    debugPrint('busId: $busId');
    debugPrint('ownerId: $ownerId');
    debugPrint('currentStatus: $currentStatus');
    debugPrint('[/BUSGO ADMIN BUS ACTION]');

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      if (action == 'approved') {
        await context.read<BusRepository>().approveBusUpdate(busId);
      } else {
        await context.read<BusRepository>().rejectBusUpdate(busId);
      }
      if (!mounted) return;
      debugPrint('[BUSGO ADMIN BUS ACTION RESULT]');
      debugPrint('action: $action');
      debugPrint('busId: $busId');
      debugPrint('success: true');
      debugPrint(
        'newStatus: ${action == 'approved' ? 'approved' : 'rejected'}',
      );
      debugPrint('[/BUSGO ADMIN BUS ACTION RESULT]');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approved'
                ? 'Bus update approved successfully.'
                : 'Bus update rejected successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'Unable to update the bus. Please try again.';
      debugPrint('[BUSGO ADMIN BUS ACTION RESULT]');
      debugPrint('action: $action');
      debugPrint('busId: $busId');
      debugPrint('success: false');
      debugPrint('errorMessage: $message');
      debugPrint('[/BUSGO ADMIN BUS ACTION RESULT]');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _date(DateTime? date) {
    if (date == null) return 'Date not available';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _statusLabel(String status) => status == 'approved'
      ? 'ACTIVE'
      : status == 'rejected'
      ? 'INACTIVE'
      : status == 'pending_approval'
      ? 'PENDING'
      : status.replaceAll('_', ' ').toUpperCase();
}

class _OwnerApprovalCard extends StatefulWidget {
  const _OwnerApprovalCard({required this.owner, required this.busCount});

  final AppUser owner;
  final int busCount;

  @override
  State<_OwnerApprovalCard> createState() => _OwnerApprovalCardState();
}

class _OwnerApprovalCardState extends State<_OwnerApprovalCard> {
  bool _isUpdating = false;

  String get _status => widget.owner.approvalStatus ?? 'approved';

  Future<void> _setStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      await context.read<UserRepository>().updateOwnerApproval(
        uid: widget.owner.uid,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Owner approved successfully.'
                  : 'Owner application rejected.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner approval could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _status == 'pending';
    final approved = _status == 'approved';
    return InkWell(
      onTap: () => context.push('/admin/owner-details', extra: widget.owner),
      borderRadius: BorderRadius.circular(20),
      child: BusGoSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BusGoProfileAvatar(
                  imageUrl: widget.owner.profileImageUrl,
                  size: 48,
                  label: widget.owner.name.isEmpty
                      ? 'O'
                      : widget.owner.name[0].toUpperCase(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.owner.name.isEmpty
                            ? 'Unnamed owner'
                            : widget.owner.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.owner.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                BusGoStatusChip(
                  label: _status == 'approved'
                      ? 'ACTIVE'
                      : _status == 'rejected'
                      ? 'INACTIVE'
                      : 'PENDING',
                  tone: pending
                      ? BusGoStatusTone.warning
                      : approved
                      ? BusGoStatusTone.positive
                      : BusGoStatusTone.negative,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: BusGoTokens.blue,
                ),
              ],
            ),
            if (widget.owner.phone?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text('Phone: ${widget.owner.phone}'),
            ],
            const SizedBox(height: 9),
            Text(
              '${widget.busCount} ${widget.busCount == 1 ? 'bus' : 'buses'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: BusGoTokens.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Registered: ${widget.owner.createdAt == null ? 'Not provided' : _date(widget.owner.createdAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            BusGoSecondaryButton(
              label: 'View Details',
              icon: Icons.open_in_new_rounded,
              onPressed: () =>
                  context.push('/admin/owner-details', extra: widget.owner),
            ),
            if (pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BusGoPrimaryButton(
                      label: 'Approve Owner',
                      icon: Icons.verified_rounded,
                      loading: _isUpdating,
                      onPressed: () => _setStatus('approved'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BusGoSecondaryButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      onPressed: _isUpdating
                          ? null
                          : () => _setStatus('rejected'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
