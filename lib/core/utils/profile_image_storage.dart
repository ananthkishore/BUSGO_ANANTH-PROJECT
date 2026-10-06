String buildProfileImageStoragePath({
  required String uid,
  String? originalFileName,
}) {
  final extension = profileImageExtension(originalFileName);

  // Keep one consistent profile-image location per authenticated user.
  return 'profile_images/$uid/profile.$extension';
}

String profileImageExtension(String? originalFileName) {
  final name = (originalFileName ?? '').trim().toLowerCase();

  if (name.endsWith('.png')) {
    return 'png';
  }

  if (name.endsWith('.webp')) {
    return 'webp';
  }

  // Default to jpg for camera/photos without a usable extension.
  return 'jpg';
}

String profileImageContentType(String? originalFileName) {
  switch (profileImageExtension(originalFileName)) {
    case 'png':
      return 'image/png';

    case 'webp':
      return 'image/webp';

    case 'jpg':
    default:
      return 'image/jpeg';
  }
}

bool isValidRemoteImageUrl(String? value) {
  final trimmed = (value ?? '').trim();

  if (trimmed.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(trimmed);

  if (uri == null || !uri.isAbsolute) {
    return false;
  }

  return uri.scheme == 'https' || uri.scheme == 'http';
}

String? sanitizeProfileImageUrl(String? value) {
  final trimmed = (value ?? '').trim();

  if (trimmed.isEmpty) {
    return null;
  }

  // Profile UI should ultimately receive a real downloadable URL.
  if (isValidRemoteImageUrl(trimmed)) {
    return trimmed;
  }

  // Do not treat a Firebase Storage path as a displayable image URL.
  // Convert it to a download URL before saving/displaying it.
  return null;
}