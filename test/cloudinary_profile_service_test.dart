import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_12/core/services/cloudinary_profile_service.dart';

void main() {
  group('CloudinaryProfileService', () {
    test(
      'uploads with the unsigned preset and returns Cloudinary secure_url',
      () async {
        late http.Request capturedRequest;
        final service = CloudinaryProfileService(
          clientFactory: () => MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'secure_url':
                    'https://res.cloudinary.com/dh8dquljc/image/upload/v123/profile.jpg',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final result = await service.uploadProfileImage(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'new-profile.png',
        );

        expect(
          capturedRequest.url.toString(),
          'https://api.cloudinary.com/v1_1/dh8dquljc/image/upload',
        );
        expect(capturedRequest.body, contains('upload_preset'));
        expect(capturedRequest.body, contains('busgo_profile_images_unsigned'));
        expect(capturedRequest.body, contains('new-profile.png'));
        expect(capturedRequest.body, isNot(contains('api_secret')));
        expect(capturedRequest.body, isNot(contains('signature')));
        expect(
          result.secureUrl,
          'https://res.cloudinary.com/dh8dquljc/image/upload/v123/profile.jpg',
        );
      },
    );

    test('rejects missing, insecure, and non-Cloudinary secure URLs', () {
      expect(
        CloudinaryProfileService.isValidCloudinarySecureUrl(null),
        isFalse,
      );
      expect(
        CloudinaryProfileService.isValidCloudinarySecureUrl(
          'http://res.cloudinary.com/dh8dquljc/image/upload/photo.jpg',
        ),
        isFalse,
      );
      expect(
        CloudinaryProfileService.isValidCloudinarySecureUrl(
          'https://example.com/dh8dquljc/image/upload/photo.jpg',
        ),
        isFalse,
      );
    });

    test('reports Cloudinary error messages when upload is rejected', () async {
      final service = CloudinaryProfileService(
        clientFactory: () => MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Upload preset is invalid'},
            }),
            400,
          );
        }),
      );

      await expectLater(
        service.uploadProfileImage(
          imageBytes: Uint8List.fromList([1]),
          fileName: 'photo.jpg',
        ),
        throwsA(
          isA<CloudinaryProfileUploadException>().having(
            (error) => error.message,
            'message',
            contains('Upload preset is invalid'),
          ),
        ),
      );
    });

    test('rejects a successful response without secure_url', () async {
      final service = CloudinaryProfileService(
        clientFactory: () => MockClient((_) async {
          return http.Response(jsonEncode({'public_id': 'profile'}), 200);
        }),
      );

      await expectLater(
        service.uploadProfileImage(
          imageBytes: Uint8List.fromList([1]),
          fileName: 'photo.jpg',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
