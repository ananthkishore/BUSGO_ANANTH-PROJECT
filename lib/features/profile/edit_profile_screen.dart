import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors/auth_failure.dart';
import '../../core/services/cloudinary_profile_service.dart';
import '../../core/utils/profile_image_storage.dart';
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
  bool _pickingImage = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

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

  Future<void> _pickProfileImage() async {
    if (_saving || _pickingImage) return;

    setState(() => _pickingImage = true);

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
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = imageBytes;
        _selectedImageName = picked.name;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst('Exception: ', '')
                .replaceFirst('PlatformException', 'Image selection failed'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    var imageUploaded = false;
    var imageUrlResolved = false;

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      final authenticatedUid = authProvider.authenticatedUid;
      if (user == null ||
          authenticatedUid == null ||
          authenticatedUid != user.uid) {
        throw StateError('Your profile is not available right now.');
      }

      String? imageUrl;
      if (_selectedImageBytes != null) {
        final fileName = _selectedImageName;
        debugPrint(
          '[PROFILE IMAGE] uid=$authenticatedUid file=${fileName ?? 'unknown'} bytes=${_selectedImageBytes!.length} Cloudinary upload started',
        );

        final uploadResult = await CloudinaryProfileService()
            .uploadProfileImage(
              imageBytes: _selectedImageBytes!,
              fileName: fileName,
            );
        imageUploaded = true;
        imageUrl = uploadResult.secureUrl;
        if (!isValidRemoteImageUrl(imageUrl)) {
          throw const FormatException(
            'The uploaded profile image URL is invalid.',
          );
        }
        imageUrlResolved = true;
        debugPrint(
          '[PROFILE IMAGE] uid=$authenticatedUid Cloudinary secure_url resolved; saving users/$authenticatedUid.profileImageUrl',
        );

        final previousImageUrl = user.profileImageUrl;
        if (previousImageUrl != null && previousImageUrl == imageUrl) {
          await NetworkImage(previousImageUrl).evict();
        }
      }

      await authProvider.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        profileImageUrl: imageUrl,
      );
      debugPrint(
        '[PROFILE IMAGE] Firestore profile saved; provider image URL updated',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint(
        '[PROFILE IMAGE] Save failed: code=${error.code} message=${error.message}',
      );
      if (!mounted) return;
      final message = imageUploaded && imageUrlResolved
          ? 'Photo uploaded, but Firestore could not save your profile: ${error.message ?? error.code}'
          : error.code == 'permission-denied'
          ? 'Permission denied while saving your profile: ${error.message ?? error.code}'
          : error.message ??
                'Unable to upload your profile photo. Please retry.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on AuthFailure catch (error) {
      if (!mounted) return;
      final message = imageUploaded && imageUrlResolved
          ? 'Photo uploaded, but the profile could not be saved: ${error.message}'
          : error.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('[PROFILE IMAGE] Profile update failed: $error');
      if (!mounted) return;
      final details = error.toString().replaceFirst('Bad state: ', '').trim();
      final fallback = imageUploaded && imageUrlResolved
          ? 'Photo uploaded, but the profile could not be saved. Please retry.'
          : _selectedImageBytes == null
          ? 'Unable to update profile. Retry.'
          : 'Unable to upload your profile photo. Please retry.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(details.isEmpty ? fallback : details)),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    Expanded(
                      child: BusGoBrandMark(compact: true, light: isDark),
                    ),
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
                    color: isDark
                        ? colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colorScheme.onSurface,
                      ),
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
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your personal information',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDark
                                      ? colorScheme.onSurfaceVariant
                                      : Theme.of(
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
                        onPressed: _saving || _pickingImage
                            ? null
                            : _pickProfileImage,
                        icon: _pickingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          _pickingImage
                              ? 'Selecting...'
                              : 'Change profile photo',
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
                          color: colorScheme.onSurface,
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
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: user.email,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Email is managed securely by Firebase and cannot be changed here.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(
                            Icons.phone_android_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
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
