import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvqGZFlCQ3-wDGWFPy92mCllaFjvADnFs',
    appId: '1:160249285398:web:758d46d5ba9079e085de37',
    messagingSenderId: '160249285398',
    projectId: 'zenfinance-7cfc7',
    authDomain: 'zenfinance-7cfc7.firebaseapp.com',
    storageBucket: 'zenfinance-7cfc7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvqGZFlCQ3-wDGWFPy92mCllaFjvADnFs',
    appId: '1:160249285398:android:758d46d5ba9079e085de37',
    messagingSenderId: '160249285398',
    projectId: 'zenfinance-7cfc7',
    storageBucket: 'zenfinance-7cfc7.firebasestorage.app',
  );
} 