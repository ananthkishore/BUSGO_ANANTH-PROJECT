import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/bus_model.dart';
import '../../widgets/busgo_ui.dart';

class BusDetailsScreen extends StatelessWidget {
  const BusDetailsScreen({super.key, required this.bus});

  final BusModel bus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            debugPrint('[BUSGO BACK NAVIGATION]');
            debugPrint('currentScreen: Bus details');
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _hero(context),
            const SizedBox(height: 18),
            Text(bus.name, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified_rounded, size: 18),
                const SizedBox(width: 6),
                Text('BUSGO approved', style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 18),
            _infoGrid(context),
            if (bus.tripTypes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle(context, 'Suitable for'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in bus.tripTypes)
                    BusGoPill(label: type, icon: Icons.route_outlined),
                ],
              ),
            ],
            if (bus.amenities.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle(context, 'Amenities'),
              const SizedBox(height: 10),
              Text(bus.amenities.join('  •  ')),
            ],
            const SizedBox(height: 20),
            _sectionTitle(context, 'Service locations'),
            const SizedBox(height: 10),
            Text(
              bus.serviceLocations.isEmpty
                  ? bus.serviceLocation
                  : bus.serviceLocations.join('  •  '),
            ),
            if (bus.description.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle(context, 'About this bus'),
              const SizedBox(height: 10),
              Text(bus.description),
            ],
          ],
        ),
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/customer/request', extra: bus),
              icon: const Icon(Icons.request_page_rounded),
              label: const Text('Request this whole bus'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return BusGoBusImage(imageUrl: bus.imageUrl, height: 210, borderRadius: 24);
  }

  Widget _infoGrid(BuildContext context) {
    return BusGoSurface(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        runSpacing: 18,
        children: [
          _info(
            context,
            'Bus number',
            bus.registrationNumber.isEmpty
                ? 'Not specified'
                : bus.registrationNumber,
          ),
          _info(context, 'Bus type', bus.busType),
          _info(context, 'Capacity', '${bus.capacity} passengers'),
          _info(context, 'Comfort', bus.isAc ? 'Air-conditioned' : 'Non-AC'),
          if (bus.estimatedPricePerDay != null)
            _info(
              context,
              'Estimated price',
              '₹${bus.estimatedPricePerDay!.toStringAsFixed(0)} / day',
            ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);
}
