import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_new/screens/home_screen.dart';
import 'package:flutter_native_admob/flutter_native_admob.dart';
import 'package:flutter_native_admob/native_admob_controller.dart';
import 'package:splashscreen/splashscreen.dart';

import '../ads.dart';
import '../config.dart';

class SplashScreenPage extends StatefulWidget {
  @override
  _SplashScreenPageState createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  final _nativeAdController = NativeAdmobController();

  Future homePageFuture;

  final Completer c = Completer();

  NativeAdmob nativeAd;

  StreamSubscription _subscription;

  Stopwatch nativeAdStopwatch = Stopwatch();

  @override
  void initState() {
    _subscription = _nativeAdController.stateChanged.listen(_onStateChanged);

    // nativeAd = NativeAdmob(
    //   // Your ad unit id
    //   adUnitID: AdMobService.getNativeAdvancedAdId(),
    //   loading: Center(
    //       child: CircularProgressIndicator(
    //     valueColor: AlwaysStoppedAnimation(primaryColor),
    //   )),
    //   numberAds: 1,
    //   controller: _nativeAdController,
    //   type: NativeAdmobType.full,
    // );
    //
    // nativeAd.createElement();
    // nativeAd.createState();

    super.initState();
  }

  void _onStateChanged(AdLoadState state) {
    switch (state) {
      case AdLoadState.loading: //todo, stop loading if time limit exceed
        print('loading');
        nativeAdStopwatch.start();
        break;

      case AdLoadState.loadCompleted: // Todo: add event and timer
        print('loadCompleted');

        FirebaseAnalytics().logEvent(
          name: 'native_ad_loading_success',
          parameters: {'time_elapsed': nativeAdStopwatch.elapsed},
        );

        c.complete(nativeAd);
        break;

      case AdLoadState.loadError:

        FirebaseAnalytics().logEvent(
          name: 'native_ad_loading_error',
          parameters: {'time_elapsed': nativeAdStopwatch.elapsed},
        );

        print('loadError');
        c.complete(nativeAd);
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    nativeAd = NativeAdmob(
      // Your ad unit id
      adUnitID: AdMobService.getNativeAdvancedAdId(),
      loading: Center(
          child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(primaryColor),
      )),
      numberAds: 1,
      controller: _nativeAdController,
      type: NativeAdmobType.full,
    );

    nativeAd.createElement();
    nativeAd.createState();

    var homePage = HomePage(nativeAd);

    return SplashScreen(
        seconds: 5,
        // navigateAfterSeconds: new HomePage(_nativeAdController),
        navigateAfterSeconds: homePage,
        // navigateAfterFuture:
        // c.future.then((value) => HomePage(_nativeAdController)),
        // c.future,
        title: new Text(
          'Welcome In SplashScreen',
          style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
        ),
        image: new Image.network('https://i.imgur.com/TyCSG9A.png'),
        backgroundColor: Colors.white,
        styleTextUnderTheLoader: new TextStyle(),
        photoSize: 100.0,
        onClick: () => print("Flutter Egypt"),
        loaderColor: Colors.red);
  }
}
