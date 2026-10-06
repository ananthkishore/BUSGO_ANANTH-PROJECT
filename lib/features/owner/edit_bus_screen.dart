import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/constants/app_roles.dart';
import '../../core/errors/auth_failure.dart';
import '../../models/bus_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/bus_repository.dart';
import '../../widgets/busgo_ui.dart';

class OwnerEditBusScreen extends StatefulWidget {
  const OwnerEditBusScreen({super.key, required this.busId});

  final String busId;

  @override
  State<OwnerEditBusScreen> createState() => _OwnerEditBusScreenState();
}

class _OwnerEditBusScreenState extends State<OwnerEditBusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _registration = TextEditingController();
  final _capacity = TextEditingController();
  final _price = TextEditingController();
  final _pickup = TextEditingController();
  final _destination = TextEditingController();
  final _amenities = TextEditingController();
  final _description = TextEditingController();
  static const _amenityOptions = [
    'AC',
    'WiFi',
    'Charging Port',
    'TV',
    'Toilet',
    'Blanket',
  ];
  static const _tripTypes = [
    'School Trip',
    'College Trip',
    'Festival Trip',
    'Corporate Trip',
    'Wedding',
    'Family Trip',
    'Tourist Trip',
    'Pilgrimage Trip',
    'Airport Transfer',
    'Outstation Trip',
    'Local Trip',
    'Sports Team Trip',
    'Event / Function',
    'Group Tour',
    'Other',
  ];
  String _busType = 'Coach';
  bool _isAc = true;
  bool _isUpdating = false;
  bool _isUploading = false;
  String? _loadedId;
  String? _imageUrl;
  Uint8List? _imageBytes;
  final _selectedAmenities = <String>{};
  final _selectedTripTypes = <String>{};

  @override
  void dispose() {
    for (final controller in [
      _name,
      _registration,
      _capacity,
      _price,
      _pickup,
      _destination,
      _amenities,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(BusModel bus) {
    if (_loadedId == bus.id) return;
    _loadedId = bus.id;
    _name.text = bus.name;
    _registration.text = bus.registrationNumber;
    _capacity.text = '${bus.capacity}';
    _price.text = bus.estimatedPricePerDay?.toString() ?? '';
    _pickup.text = bus.pickupLocation ?? bus.serviceLocation;
    _destination.text = bus.destination ?? '';
    _description.text = bus.description;
    _imageUrl = bus.imageUrl;
    _isAc = bus.isAc;
    _busType = bus.busType.isEmpty ? 'Coach' : bus.busType;
    _selectedAmenities
      ..clear()
      ..addAll(bus.amenities.where(_amenityOptions.contains));
    _amenities.text = bus.amenities
        .where((amenity) => !_amenityOptions.contains(amenity))
        .join(', ');
    _selectedTripTypes
      ..clear()
      ..addAll(bus.tripTypes);
  }

  Future<void> _update(BusModel original) async {
    if (_isUpdating || _isUploading || !_formKey.currentState!.validate()) {
      return;
    }
    final user = context.read<AuthProvider>().currentUser;
    if (user == null ||
        user.role != AppUserRole.owner ||
        user.uid != original.ownerId) {
      _showError('You can only update your own bus.');
      return;
    }
    if (_selectedTripTypes.isEmpty) {
      _showError('Select at least one suitable trip type.');
      return;
    }
    final amenities = <String>{
      ..._selectedAmenities,
      ..._split(_amenities.text),
    }.toList();
    final pickup = _pickup.text.trim();
    final destination = _destination.text.trim();
    setState(() => _isUpdating = true);
    try {
      await context.read<BusRepository>().submitOwnerBusUpdate(
        BusModel(
          id: original.id,
          ownerId: original.ownerId,
          name: _name.text.trim(),
          registrationNumber: _registration.text.trim().toUpperCase(),
          busType: _busType,
          capacity: int.parse(_capacity.text.trim()),
          isAc: _isAc,
          serviceLocation: pickup,
          pickupLocation: pickup,
          destination: destination,
          serviceLocations: [pickup, destination],
          amenities: amenities,
          tripTypes: _selectedTripTypes.toList(),
          description: _description.text.trim(),
          status: original.status,
          createdAt: original.createdAt,
          imageUrl: _imageUrl,
          rating: original.rating,
          estimatedPricePerDay: double.parse(_price.text.trim()),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus update submitted for Admin approval.'),
        ),
      );
      context.pop();
    } on AuthFailure catch (error) {
      _showError(error.message);
    } catch (error) {
      debugPrint('Bus update failed: $error');
      _showError('Unable to update this bus. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _pickImage() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
        maxHeight: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _isUploading = true;
      });
      final extension = picked.name.toLowerCase().contains('.png')
          ? 'png'
          : 'jpg';
      final reference = FirebaseStorage.instance.ref().child(
        'bus_images/${user.uid}/${widget.busId}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      final task = await reference.putData(bytes);
      final url = await task.ref.getDownloadURL();
      if (mounted) setState(() => _imageUrl = url);
    } on FirebaseException catch (error) {
      _showError(error.message ?? 'Unable to upload the bus image.');
    } catch (error) {
      debugPrint('Bus image update failed: $error');
      _showError('Unable to upload the bus image.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: BusGoLoadingState());
    return StreamBuilder<BusModel>(
      stream: context.read<BusRepository>().watchOwnerBus(
        busId: widget.busId,
        ownerId: user.uid,
      ),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: snapshot.hasError
                ? BusGoErrorState(
                    title: 'Unable to load bus for editing',
                    message: 'Please check your connection and try again.',
                    onRetry: () => context.pushReplacement(
                      '/owner/edit-bus',
                      extra: widget.busId,
                    ),
                  )
                : snapshot.data == null
                ? const BusGoLoadingState(label: 'Loading bus details...')
                : _form(context, snapshot.data!),
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context, BusModel bus) {
    _populate(bus);
    final user = context.read<AuthProvider>().currentUser;
    final firstName = user?.name.trim().split(RegExp(r'\s+')).first ?? '';
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: BusGoBrandMark(compact: true)),
                BusGoProfileAvatar(
                  imageUrl: user?.profileImageUrl,
                  size: 42,
                  label: firstName.isEmpty ? 'O' : firstName[0].toUpperCase(),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text('Travel Together, Go Further'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to bus details',
                  onPressed: _isUpdating ? null : () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Bus',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      'Update your bus details',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _card(
              context,
              icon: Icons.description_outlined,
              title: 'Basic Information',
              children: [
                _field(
                  _registration,
                  'Bus Number / Registration Number *',
                  Icons.confirmation_number_outlined,
                ),
                _field(
                  _name,
                  'Bus Name / Model *',
                  Icons.directions_bus_outlined,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _busType,
                  decoration: const InputDecoration(
                    labelText: 'Bus Type *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final type in [
                      'Coach',
                      'Sleeper',
                      'Mini Bus',
                      'Other',
                    ])
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: _isUpdating
                      ? null
                      : (value) => setState(() => _busType = value ?? _busType),
                ),
                const SizedBox(height: 12),
                _field(
                  _capacity,
                  'Seating Capacity *',
                  Icons.groups_outlined,
                  keyboardType: TextInputType.number,
                  validator: _positiveInt,
                ),
                _field(
                  _price,
                  'Price per day *',
                  Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _positiveNumber,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              context,
              icon: Icons.settings_outlined,
              title: 'Specifications',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Air conditioning'),
                  value: _isAc,
                  onChanged: _isUpdating
                      ? null
                      : (value) => setState(() => _isAc = value),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amenity in _amenityOptions)
                      FilterChip(
                        label: Text(amenity),
                        selected: _selectedAmenities.contains(amenity),
                        onSelected: _isUpdating
                            ? null
                            : (selected) => setState(
                                () => selected
                                    ? _selectedAmenities.add(amenity)
                                    : _selectedAmenities.remove(amenity),
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  _amenities,
                  'Additional amenities',
                  Icons.star_border_rounded,
                  requiredField: false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              context,
              icon: Icons.location_on_outlined,
              title: 'Operating Details',
              children: [
                _field(
                  _pickup,
                  'Preferred Routes / Service Locations *',
                  Icons.route_outlined,
                ),
                _field(_destination, 'Destination *', Icons.flag_outlined),
                _field(
                  _description,
                  'Home Location / Garage Address',
                  Icons.home_work_outlined,
                  requiredField: false,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  'Suitable for',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _tripTypes)
                      FilterChip(
                        label: Text(type),
                        selected: _selectedTripTypes.contains(type),
                        onSelected: _isUpdating
                            ? null
                            : (selected) => setState(
                                () => selected
                                    ? _selectedTripTypes.add(type)
                                    : _selectedTripTypes.remove(type),
                              ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              context,
              icon: Icons.image_outlined,
              title: 'Bus Images',
              children: [
                GestureDetector(
                  onTap: _isUpdating || _isUploading ? null : _pickImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 170,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : BusGoBusImage(
                              imageUrl: _imageUrl,
                              height: 170,
                              borderRadius: 16,
                            ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isUpdating || _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Replace image'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isUpdating || bus.hasPendingUpdate
                  ? null
                  : () => _update(bus),
              icon: _isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isUpdating
                    ? 'Submitting...'
                    : bus.hasPendingUpdate
                    ? 'Update Pending Admin Approval'
                    : 'Submit Update',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return BusGoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BusGoTokens.blue),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_isUpdating,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator:
            validator ??
            (requiredField
                ? (value) => value == null || value.trim().isEmpty
                      ? '$label is required'
                      : null
                : null),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  String? _positiveInt(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0
        ? 'Enter a valid seating capacity'
        : null;
  }

  String? _positiveNumber(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a valid price' : null;
  }
}
