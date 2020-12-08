import 'package:device_preview/device_preview.dart';
import 'package:firebase_admob/firebase_admob.dart';
// import 'package:firebase/firebase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_new/screens/splash_screen.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:tip_dialog/tip_dialog.dart';

import 'package:flutter/services.dart' as services;

import 'ads.dart';
import 'screens/home_screen.dart';
import 'screens/cropping_screen.dart';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

// FirebaseAnalytics analytics = FirebaseAnalytics();

void main() {

  runApp(
    DevicePreview(
      // enabled: !kReleaseMode,
      enabled: false,
      // enabled: true,
      builder: (context) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  // final ams = AdMobService();

  static FirebaseAnalytics analytics = FirebaseAnalytics();
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  Widget build(BuildContext context) {

    SystemChrome.setPreferredOrientations([
      services.DeviceOrientation.portraitUp,
    ]);

    return MaterialApp(
      locale: DevicePreview.of(context).locale,
      // <--- /!\ Add the locale
      builder: DevicePreview.appBuilder,
      title: 'Magic Crop',
      theme: new ThemeData(
        primarySwatch: Colors.teal,
        canvasColor: Colors.transparent,
      ),
      home: SplashScreenPage(),
      // home: HomePage(null),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
    );


  }
}
