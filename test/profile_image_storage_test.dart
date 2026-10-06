import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_12/core/utils/profile_image_storage.dart';

void main() {
  group('profile image storage helpers', () {
    test(
      'buildProfileImageStoragePath uses the user UID and correct extension',
      () {
        expect(
          buildProfileImageStoragePath(
            uid: 'customer-123',
            originalFileName: 'avatar.png',
          ),
          'profile_images/customer-123/profile.png',
        );

        expect(
          buildProfileImageStoragePath(
            uid: 'owner-456',
            originalFileName: 'PHOTO.WEBP',
          ),
          'profile_images/owner-456/profile.webp',
        );

        expect(
          buildProfileImageStoragePath(
            uid: 'admin-789',
            originalFileName: 'photo.jpg',
          ),
          'profile_images/admin-789/profile.jpg',
        );
      },
    );

    test('profileImageExtension detects supported extensions', () {
      expect(profileImageExtension('avatar.png'), 'png');
      expect(profileImageExtension('PHOTO.PNG'), 'png');
      expect(profileImageExtension('photo.webp'), 'webp');
      expect(profileImageExtension('PHOTO.WEBP'), 'webp');
      expect(profileImageExtension('portrait.jpg'), 'jpg');
      expect(profileImageExtension('portrait.jpeg'), 'jpg');
      expect(profileImageExtension('unknown-file'), 'jpg');
      expect(profileImageExtension(null), 'jpg');
    });

    test('profileImageContentType matches the image extension', () {
      expect(profileImageContentType('avatar.png'), 'image/png');
      expect(profileImageContentType('PHOTO.PNG'), 'image/png');

      expect(profileImageContentType('photo.webp'), 'image/webp');
      expect(profileImageContentType('PHOTO.WEBP'), 'image/webp');

      expect(profileImageContentType('portrait.jpg'), 'image/jpeg');
      expect(profileImageContentType('portrait.jpeg'), 'image/jpeg');

      expect(profileImageContentType('unknown-file'), 'image/jpeg');
      expect(profileImageContentType(null), 'image/jpeg');
    });

    test('isValidRemoteImageUrl accepts valid HTTP and HTTPS URLs', () {
      expect(
        isValidRemoteImageUrl(
          'https://firebasestorage.googleapis.com/v0/b/test/o/profile.jpg',
        ),
        isTrue,
      );

      expect(
        isValidRemoteImageUrl(
          'http://example.com/profile.jpg',
        ),
        isTrue,
      );
    });

    test('isValidRemoteImageUrl rejects invalid values', () {
      expect(
        isValidRemoteImageUrl(
          'profile_images/customer-123/profile.png',
        ),
        isFalse,
      );

      expect(
        isValidRemoteImageUrl(
          '/profile_images/customer-123/profile.png',
        ),
        isFalse,
      );

      expect(isValidRemoteImageUrl(''), isFalse);
      expect(isValidRemoteImageUrl('   '), isFalse);
      expect(isValidRemoteImageUrl(null), isFalse);
    });

    test('sanitizeProfileImageUrl keeps valid remote URLs', () {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/test/o/profile.jpg';

      expect(
        sanitizeProfileImageUrl(url),
        url,
      );

      expect(
        sanitizeProfileImageUrl('  $url  '),
        url,
      );
    });

    test('sanitizeProfileImageUrl rejects storage paths', () {
      expect(
        sanitizeProfileImageUrl(
          'profile_images/customer-123/profile.jpg',
        ),
        isNull,
      );

      expect(
        sanitizeProfileImageUrl(
          'users/customer-123/profile.jpg',
        ),
        isNull,
      );
    });

    test('sanitizeProfileImageUrl rejects empty and null values', () {
      expect(
        sanitizeProfileImageUrl(''),
        isNull,
      );

      expect(
        sanitizeProfileImageUrl('   '),
        isNull,
      );

      expect(
        sanitizeProfileImageUrl(null),
        isNull,
      );
    });
  });
}