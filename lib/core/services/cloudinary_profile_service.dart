import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/profile_image_storage.dart';

class CloudinaryProfileUploadResult {
  const CloudinaryProfileUploadResult({required this.secureUrl});

  final String secureUrl;
}

class CloudinaryProfileService {
  CloudinaryProfileService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const _cloudName = 'dh8dquljc';
  static const _uploadPreset = 'busgo_profile_images_unsigned';

  final http.Client Function() _clientFactory;

  Future<CloudinaryProfileUploadResult> uploadProfileImage({
    required Uint8List imageBytes,
    required String? fileName,
  }) async {
    final normalizedFileName = (fileName != null && fileName.trim().isNotEmpty)
        ? fileName.trim()
        : 'profile.jpg';

    final request =
        http.MultipartRequest(
            'POST',
            Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/image/upload'),
          )
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              imageBytes,
              filename: normalizedFileName,
              contentType: _contentTypeFor(normalizedFileName),
            ),
          );

    final client = _clientFactory();
    late final http.StreamedResponse streamedResponse;
    late final String responseBody;
    try {
      streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      responseBody = await streamedResponse.stream.bytesToString().timeout(
        const Duration(seconds: 60),
      );
    } on TimeoutException {
      throw const CloudinaryProfileUploadException(
        'Cloudinary upload timed out. Check your connection and retry.',
      );
    } on http.ClientException catch (error) {
      throw CloudinaryProfileUploadException(
        'Could not connect to Cloudinary: ${error.message}',
      );
    } catch (error) {
      throw CloudinaryProfileUploadException(
        'Cloudinary upload failed: $error',
      );
    } finally {
      client.close();
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw CloudinaryProfileUploadException(
        _uploadErrorMessage(streamedResponse.statusCode, responseBody),
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Cloudinary upload returned an unexpected response.',
      );
    }

    final secureUrl = decoded['secure_url']?.toString();
    if (!isValidCloudinarySecureUrl(secureUrl)) {
      throw const FormatException(
        'Cloudinary upload succeeded but no valid secure_url was returned.',
      );
    }

    return CloudinaryProfileUploadResult(secureUrl: secureUrl!);
  }

  static bool isValidCloudinarySecureUrl(String? value) {
    final uri = Uri.tryParse((value ?? '').trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com') {
      return false;
    }

    final segments = uri.pathSegments;
    return segments.length >= 4 &&
        segments[0] == _cloudName &&
        segments[1] == 'image' &&
        segments[2] == 'upload';
  }

  static String _uploadErrorMessage(int statusCode, String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        final message = (decoded['error'] as Map)['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return 'Cloudinary upload failed ($statusCode): ${message.trim()}';
        }
      }
    } on FormatException {
      // Use the status when Cloudinary does not return a JSON error body.
    }

    return 'Cloudinary upload failed with status $statusCode.';
  }

  static dynamic _contentTypeFor(String fileName) {
    final contentType = profileImageContentType(fileName);
    return http.MediaType.parse(contentType);
  }
}

class CloudinaryProfileUploadException implements Exception {
  const CloudinaryProfileUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
