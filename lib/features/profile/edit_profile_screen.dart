import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/busgo_ui.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController.text = user?.name ?? '';
    _phoneController.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to change your profile image.'),
        ),
      );
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null) {
        return;
      }

      final imageBytes = await picked.readAsBytes();
      final extension = picked.name.toLowerCase().contains('.png')
          ? 'png'
          : picked.name.toLowerCase().contains('.webp')
          ? 'webp'
          : 'jpg';

      setState(() {
        _selectedImageBytes = imageBytes;
        _uploading = true;
      });

      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_images/${user.uid}/profile.$extension',
      );
      final uploadTask = await storageRef.putData(imageBytes);
      final imageUrl = await uploadTask.ref.getDownloadURL();
      await authProvider.uploadProfileImage(imageUrl: imageUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? 'Image upload permission denied. Please check Firebase Storage rules.'
                : error.message ??
                      'Unable to upload image. Check your internet connection.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('Exception: ', '')
                .replaceFirst('PlatformException', 'Image upload failed'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile. Retry.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: BusGoTokens.canvas,
        body: SafeArea(
          child: authProvider.isLoading
              ? const BusGoLoadingState(label: 'Loading your profile...')
              : BusGoErrorState(
                  title: 'Unable to load profile',
                  message: 'Please sign in again and retry.',
                  onRetry: () => Navigator.of(context).maybePop(),
                ),
        ),
      );
    }

    final initial = user.name.trim().isEmpty
        ? 'O'
        : user.name.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: BusGoTokens.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: BusGoBrandMark(compact: true)),
                    BusGoProfileAvatar(
                      imageUrl: user.profileImageUrl,
                      size: 42,
                      label: initial,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Travel Together, Go Further',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BusGoTokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Back to profile',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: BusGoTokens.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your personal information',
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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      if (_selectedImageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.memory(
                            _selectedImageBytes!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        BusGoProfileAvatar(
                          imageUrl: user.profileImageUrl,
                          size: 88,
                          label: user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'B',
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _uploading ? null : _pickAndUploadImage,
                        icon: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          _uploading ? 'Uploading...' : 'Change profile photo',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                BusGoSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: BusGoTokens.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_saving,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email is managed securely by Firebase and cannot be changed here.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BusGoTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isEmpty) return null;
                          final digits = phone.replaceAll(RegExp(r'\D'), '');
                          return digits.length < 7 || digits.length > 15
                              ? 'Enter a valid phone number'
                              : null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
