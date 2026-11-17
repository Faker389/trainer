import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.android => android,
        _ => throw UnsupportedError(
            'Firebase jest skonfigurowany tylko dla Androida. Dla iOS uruchom: flutterfire configure'),
      };

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAeNiL8LhnCA6HviUAHzS8DnceoXeGCmfM',
    appId: '1:543462613461:android:37a1c0cf1d1fffa3b29d5c',
    messagingSenderId: '543462613461',
    projectId: 'trainer-fb00e',
    storageBucket: 'trainer-fb00e.firebasestorage.app',
  );
}
