import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/bus_model.dart';
import '../../models/bus_search_query.dart';
import '../../repositories/bus_repository.dart';
import '../../widgets/busgo_ui.dart';

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key, this.query});

  final BusSearchQuery? query;

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> {
  final _locationController = TextEditingController();
  final _destinationController = TextEditingController();
  final _passengersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final query = widget.query;
    if (query != null) {
      _locationController.text = query.pickup;
      _destinationController.text = query.destination;
      _passengersController.text = query.passengerCount.toString();
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _destinationController.dispose();
    _passengersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minimumCapacity = int.tryParse(_passengersController.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Available buses')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: BusGoSurface(
                child: Column(
                  children: [
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Service location',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      onSubmitted: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      onSubmitted: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passengersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Approximate passengers',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      onSubmitted: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search buses'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.query != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.query!.pickup}  →  ${widget.query!.destination}\n'
                    '${_date(widget.query!.travelDate)}  •  ${widget.query!.passengerCount} passengers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<BusModel>>(
                future: context.read<BusRepository>().findAvailableBuses(
                  serviceLocation: _locationController.text,
                  destination: _destinationController.text,
                  minimumCapacity: minimumCapacity,
                  startDate: widget.query?.travelDate ?? DateTime.now(),
                  endDate:
                      widget.query?.returnDate ??
                      (widget.query?.travelDate.add(const Duration(days: 1)) ??
                          DateTime.now().add(const Duration(days: 1))),
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: BusGoEmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Unable to load buses',
                          message:
                              'Check your connection and try searching again.',
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const BusGoLoadingState(
                      label: 'Finding whole buses...',
                    );
                  }
                  final buses = snapshot.data!;
                  if (buses.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: BusGoEmptyState(
                          icon: Icons.directions_bus_outlined,
                          title: 'No buses match yet',
                          message:
                              'Try a wider service location or a different group size.',
                        ),
                      ),
                    );
                  }
                  final approvedBuses = buses
                      .where((bus) => bus.status.toLowerCase() == 'approved')
                      .toList();
                  if (approvedBuses.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: BusGoEmptyState(
                          icon: Icons.directions_bus_outlined,
                          title: 'No approved buses available',
                          message:
                              'Only buses approved by BUSGO admin can be requested.',
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: approvedBuses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _BusResultCard(bus: approvedBuses[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.day} ${_month(date.month)} ${date.year}';

  String _month(int month) => const [
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
  ][month];
}

class _BusResultCard extends StatelessWidget {
  const _BusResultCard({required this.bus});

  final BusModel bus;

  @override
  Widget build(BuildContext context) {
    return BusGoSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BusGoBusImage(imageUrl: bus.imageUrl, height: 132, borderRadius: 20),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bus.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  '${bus.busType}  |  ${bus.capacity} passenger capacity • whole bus',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Owner: ${bus.ownerId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    BusGoPill(
                      label: bus.isAc ? 'AC' : 'Non-AC',
                      icon: Icons.ac_unit_rounded,
                    ),
                    BusGoPill(
                      label: bus.serviceLocation,
                      icon: Icons.location_on_outlined,
                    ),
                    if (bus.estimatedPricePerDay != null)
                      BusGoPill(
                        label: '${bus.estimatedPricePerDay}/day',
                        icon: Icons.payments_outlined,
                      ),
                    if (bus.rating != null)
                      BusGoPill(
                        label: '${bus.rating}/5',
                        icon: Icons.star_rounded,
                      ),
                  ],
                ),
                if (bus.amenities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Amenities: ${bus.amenities.join(', ')}'),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/customer/bus-details', extra: bus),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View details'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/customer/request', extra: bus),
                        icon: const Icon(Icons.request_page_rounded),
                        label: const Text('Request whole bus'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
