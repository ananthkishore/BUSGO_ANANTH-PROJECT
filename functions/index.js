const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { defineSecret } = require('firebase-functions/params');
const cloudinary = require('cloudinary').v2;

admin.initializeApp();

const cloudinaryCloudName = defineSecret('CLOUDINARY_CLOUD_NAME');
const cloudinaryApiKey = defineSecret('CLOUDINARY_API_KEY');
const cloudinaryApiSecret = defineSecret('CLOUDINARY_API_SECRET');

exports.getCloudinaryProfileUploadSignature = functions
  .region('us-central1')
  .runWith({
    secrets: [cloudinaryCloudName, cloudinaryApiKey, cloudinaryApiSecret],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in to upload a profile image.',
      );
    }

    const cloudName = cloudinaryCloudName.value();
    const apiKey = cloudinaryApiKey.value();
    const apiSecret = cloudinaryApiSecret.value();
    if (!cloudName || !apiKey || !apiSecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cloudinary credentials are not configured on the Firebase backend.',
      );
    }

    cloudinary.config({
      cloud_name: cloudName,
      api_key: apiKey,
      api_secret: apiSecret,
    });

    const uid = context.auth.uid;
    const fileName =
      data && typeof data.fileName === 'string' ? data.fileName : 'profile.jpg';
    const folder = `busgo/profile_images/${uid}`;
    const publicId = `profile_${Date.now()}`;
    const timestamp = Math.round(Date.now() / 1000);

    const signature = cloudinary.utils.api_sign_request(
      {
        public_id: publicId,
        folder,
        timestamp,
        overwrite: true,
        resource_type: 'image',
      },
      apiSecret,
    );

    return {
      uploadUrl: `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
      apiKey,
      timestamp,
      signature,
      publicId,
      folder,
      fileName,
      uid,
    };
  });
