import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import '../../core/constants/app_roles.dart';
import '../../core/errors/auth_failure.dart';
import '../../app/theme.dart';
import '../../models/bus_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/bus_repository.dart';
import '../../widgets/busgo_ui.dart';

class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _amenitiesController = TextEditingController();
  final _descriptionController = TextEditingController();
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
  static const _amenityOptions = [
    'AC',
    'WiFi',
    'Charging Port',
    'TV',
    'Toilet',
    'Blanket',
  ];
  bool _isAc = true;
  String _busType = 'Coach';
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  Uint8List? _imageBytes;
  String? _imageUrl;
  final Set<String> _selectedTripTypes = <String>{};
  final Set<String> _selectedAmenities = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    _amenitiesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _isSubmitting ||
        _isUploadingImage) {
      return;
    }
    if (_selectedTripTypes.isEmpty) {
      _showError('Select at least one suitable trip type.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null || user.role != AppUserRole.owner) {
      _showError('Please login as a bus owner.');
      return;
    }

    final pickup = _pickupController.text.trim();
    final destination = _destinationController.text.trim();
    final locations = [pickup, destination];
    final amenities = <String>{
      ..._selectedAmenities,
      ..._splitValues(_amenitiesController.text),
    }.toList();
    setState(() => _isSubmitting = true);
    try {
      await context.read<BusRepository>().createBus(
        BusModel(
          id: '',
          ownerId: user.uid,
          name: _nameController.text.trim(),
          registrationNumber: _registrationController.text.trim().toUpperCase(),
          busType: _busType,
          capacity: int.parse(_capacityController.text.trim()),
          isAc: _isAc,
          serviceLocation: locations.first,
          pickupLocation: pickup,
          destination: destination,
          serviceLocations: locations,
          amenities: amenities,
          tripTypes: _selectedTripTypes.toList(),
          description: _descriptionController.text.trim(),
          estimatedPricePerDay: double.parse(_priceController.text.trim()),
          imageUrl: _imageUrl,
          status: 'pending_approval',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus submitted for admin approval.')),
      );
      context.pop();
    } on AuthFailure catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Unable to add bus. Please try again.');
      debugPrint('Add bus failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickBusImage() async {
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
      final extension = picked.name.toLowerCase().contains('.png')
          ? 'png'
          : 'jpg';
      setState(() {
        _imageBytes = bytes;
        _isUploadingImage = true;
      });
      final storageRef = FirebaseStorage.instance.ref().child(
        'bus_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      final uploadTask = await storageRef.putData(bytes);
      final imageUrl = await uploadTask.ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _imageUrl = imageUrl);
    } on FirebaseException catch (error) {
      _showError(error.message ?? 'Unable to upload the bus image.');
    } catch (error) {
      _showError('Unable to select this image. Please try again.');
      debugPrint('Bus image upload failed: $error');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  List<String> _splitValues(String value) => value
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
    final ownerName = user?.name.trim().split(RegExp(r'\s+')).first;
    final avatarLabel = ownerName == null || ownerName.isEmpty
        ? 'O'
        : ownerName[0].toUpperCase();

    return Scaffold(
      backgroundColor: BusGoTokens.canvas,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BusGoBrandMark(compact: true),
                            const SizedBox(height: 5),
                            Text(
                              'Travel Together, Go Further',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: BusGoTokens.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      BusGoProfileAvatar(
                        imageUrl: user?.profileImageUrl,
                        size: 42,
                        label: avatarLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back to my buses',
                        onPressed: _isSubmitting ? null : () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Bus',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: BusGoTokens.navy,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter your bus details to submit for approval',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: BusGoTokens.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  BusGoSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.description_outlined,
                          title: 'Basic Information',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _registrationController,
                          label: 'Bus Number / Registration Number *',
                          hint: 'e.g. TN 37 AB 1234',
                          icon: Icons.confirmation_number_outlined,
                        ),
                        _field(
                          controller: _nameController,
                          label: 'Bus Name / Model *',
                          hint: 'e.g. Volvo B11R',
                          icon: Icons.directions_bus_outlined,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _busType,
                          decoration: const InputDecoration(
                            labelText: 'Bus Type *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Coach',
                              child: Text('Coach'),
                            ),
                            DropdownMenuItem(
                              value: 'Sleeper',
                              child: Text('Sleeper'),
                            ),
                            DropdownMenuItem(
                              value: 'Mini Bus',
                              child: Text('Mini Bus'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _busType = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _capacityController,
                          label: 'Seating Capacity *',
                          hint: 'e.g. 42',
                          icon: Icons.groups_outlined,
                          keyboardType: TextInputType.number,
                          validator: _positiveInteger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BusGoSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.settings_outlined,
                          title: 'Specifications',
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Air conditioning'),
                          subtitle: Text(_isAc ? 'AC bus' : 'Non-AC bus'),
                          value: _isAc,
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(() => _isAc = value),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Amenities',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: BusGoTokens.navy),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final amenity in _amenityOptions)
                              FilterChip(
                                label: Text(amenity),
                                selected: _selectedAmenities.contains(amenity),
                                onSelected: _isSubmitting
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected) {
                                          _selectedAmenities.add(amenity);
                                        } else {
                                          _selectedAmenities.remove(amenity);
                                        }
                                      }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _priceController,
                          label: 'Price per day *',
                          hint: 'e.g. 12000',
                          icon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _positiveNumber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BusGoSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.location_on_outlined,
                          title: 'Operating Details',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _pickupController,
                          label: 'Preferred Routes / Service Locations *',
                          hint: 'e.g. Chennai - Trichy, Chennai - Madurai',
                          icon: Icons.route_outlined,
                        ),
                        _field(
                          controller: _destinationController,
                          label: 'Destination *',
                          hint: 'e.g. Chennai',
                          icon: Icons.flag_outlined,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Destination is required';
                            }
                            if (value.trim().toLowerCase() ==
                                _pickupController.text.trim().toLowerCase()) {
                              return 'Pickup and destination must be different';
                            }
                            return null;
                          },
                        ),
                        _field(
                          controller: _descriptionController,
                          label: 'Home Location / Garage Address',
                          hint: 'e.g. Chennai, Tamil Nadu',
                          icon: Icons.home_work_outlined,
                          maxLines: 2,
                          requiredField: false,
                        ),
                        _field(
                          controller: _amenitiesController,
                          label: 'Additional amenities',
                          hint: 'Separate extra amenities with commas',
                          icon: Icons.notes_outlined,
                          maxLines: 2,
                          requiredField: false,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose at least one suitable trip type',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: BusGoTokens.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in _tripTypes)
                              FilterChip(
                                label: Text(type),
                                selected: _selectedTripTypes.contains(type),
                                onSelected: _isSubmitting
                                    ? null
                                    : (selected) => setState(() {
                                        if (selected) {
                                          _selectedTripTypes.add(type);
                                        } else {
                                          _selectedTripTypes.remove(type);
                                        }
                                      }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BusGoSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.image_outlined,
                          title: 'Bus Images',
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _isSubmitting || _isUploadingImage
                              ? null
                              : _pickBusImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F8FC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: BusGoTokens.blue.withValues(alpha: 0.25),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: _imageBytes == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        color: BusGoTokens.blue,
                                        size: 38,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Tap to upload a bus image'),
                                      SizedBox(height: 4),
                                      Text('JPG or PNG, one image'),
                                    ],
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.memory(
                                          _imageBytes!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (_isUploadingImage)
                                        const ColoredBox(
                                          color: Color(0x66071A33),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        if (_imageBytes != null && !_isUploadingImage)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _pickBusImage,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Replace'),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _imageBytes = null;
                                  _imageUrl = null;
                                }),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Remove'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit for Approval',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool requiredField = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_isSubmitting,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator:
            validator ??
            (requiredField
                ? (value) => value == null || value.trim().isEmpty
                      ? '$label is required'
                      : null
                : null),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  String? _positiveInteger(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0
        ? 'Enter a whole number greater than 0'
        : null;
  }

  String? _positiveNumber(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0
        ? 'Enter a number greater than 0'
        : null;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
