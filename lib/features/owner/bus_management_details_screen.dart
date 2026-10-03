import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/errors/auth_failure.dart';
import '../../models/bus_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/bus_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerBusManagementDetailsScreen extends StatelessWidget {
  const OwnerBusManagementDetailsScreen({super.key, required this.busId});

  final String busId;

  @override
  Widget build(BuildContext context) {
    final normalizedBusId = busId.trim();
    final currentOwnerUid =
        context.read<AuthProvider>().currentUser?.uid ?? 'null';

    debugPrint('[BUSGO OWNER NAV]');
    debugPrint('source: My Buses / owner notification');
    debugPrint('action: open bus details');
    debugPrint('currentOwnerUid: $currentOwnerUid');
    debugPrint('selectedBusId: $normalizedBusId');
    debugPrint('selectedBusDocumentId: $normalizedBusId');
    debugPrint('route: /owner/bus-details');
    debugPrint('destination: OwnerBusManagementDetailsScreen');
    debugPrint('[/BUSGO OWNER NAV]');

    if (normalizedBusId.isEmpty) {
      debugPrint('[BUSGO OWNER BUS ERROR]');
      debugPrint('busId: null');
      debugPrint('currentOwnerUid: $currentOwnerUid');
      debugPrint('collection: buses');
      debugPrint('operation: read_document');
      debugPrint('errorCode: missing_bus_id');
      debugPrint('errorMessage: Bus details not found.');
      debugPrint('[/BUSGO OWNER BUS ERROR]');

      return Scaffold(
        appBar: AppBar(
          title: const Text('Bus Details'),
          leading: IconButton(
            tooltip: 'Back to my buses',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: BusGoErrorState(
            title: 'Unable to load bus details',
            message:
                'The selected bus could not be found or is no longer available.',
            onRetry: () => context.pop(),
          ),
        ),
      );
    }

    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: SafeArea(
          child: BusGoLoadingState(label: 'Loading bus details...'),
        ),
      );
    }

    debugPrint('[BUSGO OWNER BUS LOAD]');
    debugPrint('busId: $normalizedBusId');
    debugPrint('collection: buses');
    debugPrint('ownerUid: ${user.uid}');
    debugPrint('documentId: $normalizedBusId');
    debugPrint('[/BUSGO OWNER BUS LOAD]');
    return StreamBuilder<BusModel>(
      stream: context.read<BusRepository>().watchOwnerBus(
        busId: normalizedBusId,
        ownerId: user.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final errorCode = error is FirebaseException
              ? error.code
              : error.runtimeType.toString();
          debugPrint('[BUSGO OWNER BUS ERROR]');
          debugPrint('busId: $normalizedBusId');
          debugPrint('operation: watch_document');
          debugPrint('errorCode: $errorCode');
          debugPrint('errorMessage: $error');
          debugPrint('[/BUSGO OWNER BUS ERROR]');
        } else if (snapshot.hasData) {
          final bus = snapshot.data!;
          debugPrint('[BUSGO OWNER BUS LOAD]');
          debugPrint('busId: $normalizedBusId');
          debugPrint('collection: buses');
          debugPrint('documentId: ${bus.id}');
          debugPrint('exists: true');
          debugPrint('ownerId: ${bus.ownerId}');
          debugPrint('status: ${bus.status}');
          debugPrint('[/BUSGO OWNER BUS LOAD]');
        }
        return Scaffold(
          backgroundColor: BusGoTokens.canvas,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ownerHeader(
                              context,
                              user.name,
                              user.profileImageUrl,
                            ),
                            const SizedBox(height: 18),
                            _title(context),
                            const SizedBox(height: 18),
                            if (snapshot.hasError)
                              BusGoErrorState(
                                title: 'Unable to load bus details',
                                message: _loadErrorMessage(snapshot.error),
                                onRetry: () => context.pushReplacement(
                                  '/owner/bus-details',
                                  extra: normalizedBusId,
                                ),
                              )
                            else if (!snapshot.hasData)
                              const BusGoLoadingState(
                                label: 'Loading bus details...',
                              )
                            else
                              _details(context, snapshot.data!),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _loadErrorMessage(Object? error) {
    if (error is AuthFailure) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Unable to load bus details.';
    }
    return 'Unable to load bus details. Check your connection and try again.';
  }

  Widget _ownerHeader(BuildContext context, String name, String? imageUrl) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final label = firstName.isEmpty ? 'O' : firstName[0].toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BusGoBrandMark(compact: true),
              const SizedBox(height: 5),
              Text(
                'Travel Together, Go Further',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BusGoTokens.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        BusGoProfileAvatar(imageUrl: imageUrl, size: 42, label: label),
      ],
    );
  }

  Widget _title(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: 'Back to my buses',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bus Details',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View and manage your bus information',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: BusGoTokens.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/owner/edit-bus', extra: busId),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit Bus'),
          ),
        ),
      ],
    );
  }

  Widget _details(BuildContext context, BusModel bus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusGoBusImage(imageUrl: bus.imageUrl, height: 220, borderRadius: 22),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.registrationNumber.isEmpty
                        ? 'Registration not provided'
                        : bus.registrationNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bus.name.isEmpty ? 'Bus model not provided' : bus.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: BusGoTokens.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bus.capacity} seats • ${bus.isAc ? 'AC' : 'Non-AC'}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: BusGoTokens.muted),
                  ),
                ],
              ),
            ),
            BusGoStatusChip(
              label: _statusLabel(
                bus.status,
                hasPendingUpdate: bus.hasPendingUpdate,
                hasRejectedUpdate: bus.hasRejectedUpdate,
              ),
              tone: _statusTone(
                bus.status,
                hasPendingUpdate: bus.hasPendingUpdate,
                hasRejectedUpdate: bus.hasRejectedUpdate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1024
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric(
                  context,
                  width,
                  Icons.event_seat_outlined,
                  '${bus.capacity}',
                  'Capacity',
                ),
                _metric(
                  context,
                  width,
                  Icons.directions_bus_outlined,
                  _value(bus.busType),
                  'Bus Type',
                ),
                _metric(
                  context,
                  width,
                  Icons.ac_unit_rounded,
                  bus.isAc ? 'AC' : 'Non-AC',
                  'Comfort',
                ),
                _metric(
                  context,
                  width,
                  Icons.payments_outlined,
                  bus.estimatedPricePerDay == null
                      ? 'Not provided'
                      : '₹${bus.estimatedPricePerDay!.toStringAsFixed(0)}',
                  'Price / day',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _operatingCard(context, bus),
        if (bus.amenities.isNotEmpty || bus.tripTypes.isNotEmpty) ...[
          const SizedBox(height: 14),
          _specificationsCard(context, bus),
        ],
        if (bus.createdAt != null || bus.updatedAt != null) ...[
          const SizedBox(height: 14),
          _timestampsCard(context, bus),
        ],
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    double width,
    IconData icon,
    String value,
    String label,
  ) {
    return SizedBox(
      width: width,
      child: BusGoSurface(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: BusGoTokens.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BusGoTokens.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operatingCard(BuildContext context, BusModel bus) {
    final locations = bus.serviceLocations.isNotEmpty
        ? bus.serviceLocations
        : [bus.serviceLocation];
    final route = locations
        .where((location) => location.trim().isNotEmpty)
        .join(' • ');
    return BusGoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.location_on_outlined,
            title: 'Operating Details',
          ),
          const SizedBox(height: 14),
          _detailLine(
            context,
            Icons.route_outlined,
            'Preferred Routes / Service Locations',
            _value(route),
          ),
          if (bus.pickupLocation != null &&
              bus.pickupLocation!.trim().isNotEmpty)
            _detailLine(
              context,
              Icons.trip_origin_rounded,
              'Pickup',
              bus.pickupLocation!,
            ),
          if (bus.destination != null && bus.destination!.trim().isNotEmpty)
            _detailLine(
              context,
              Icons.flag_outlined,
              'Destination',
              bus.destination!,
            ),
          if (bus.description.trim().isNotEmpty)
            _detailLine(
              context,
              Icons.home_work_outlined,
              'Home / Garage or notes',
              bus.description,
            ),
        ],
      ),
    );
  }

  Widget _specificationsCard(BuildContext context, BusModel bus) {
    return BusGoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.tune_rounded, title: 'Specifications'),
          const SizedBox(height: 14),
          _detailLine(
            context,
            Icons.ac_unit_rounded,
            'Comfort',
            bus.isAc ? 'Air-conditioned' : 'Non-AC',
          ),
          if (bus.amenities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Amenities', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amenity in bus.amenities)
                  BusGoStatusChip(label: amenity, tone: BusGoStatusTone.info),
              ],
            ),
          ],
          if (bus.tripTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Suitable for',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in bus.tripTypes)
                  BusGoStatusChip(label: type, tone: BusGoStatusTone.info),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timestampsCard(BuildContext context, BusModel bus) {
    return BusGoSurface(
      child: Row(
        children: [
          if (bus.createdAt != null)
            Expanded(
              child: _detailLine(
                context,
                Icons.calendar_today_outlined,
                'Added',
                _date(bus.createdAt!),
              ),
            ),
          if (bus.createdAt != null && bus.updatedAt != null)
            const SizedBox(width: 12),
          if (bus.updatedAt != null)
            Expanded(
              child: _detailLine(
                context,
                Icons.update_rounded,
                'Updated',
                _date(bus.updatedAt!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailLine(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BusGoTokens.blue, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: BusGoTokens.navy),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _value(String value) => value.trim().isEmpty ? 'Not provided' : value;

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _statusLabel(
    String status, {
    bool hasPendingUpdate = false,
    bool hasRejectedUpdate = false,
  }) {
    if (hasPendingUpdate) return 'Update Pending Approval';
    if (hasRejectedUpdate) return 'Update Rejected';
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      case 'pending_approval':
        return 'Pending Approval';
      default:
        return _value(status).replaceAll('_', ' ');
    }
  }

  BusGoStatusTone _statusTone(
    String status, {
    bool hasPendingUpdate = false,
    bool hasRejectedUpdate = false,
  }) {
    if (hasPendingUpdate) return BusGoStatusTone.warning;
    if (hasRejectedUpdate) return BusGoStatusTone.negative;
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'approved':
        return BusGoStatusTone.positive;
      case 'rejected':
        return BusGoStatusTone.negative;
      default:
        return BusGoStatusTone.warning;
    }
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BusGoTokens.blue),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
