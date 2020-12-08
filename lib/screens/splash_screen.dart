import 'dart:async';

import 'package:firebase_admob/firebase_admob.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_new/premium.dart';
import 'package:flutter_app_new/screens/home_screen.dart';
import 'package:flutter_native_admob/flutter_native_admob.dart';
import 'package:flutter_native_admob/native_admob_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    super.initState();
  }

  void _onStateChanged(AdLoadState state) {
    switch (state) {
      case AdLoadState.loading: //todo, stop loading if time limit exceed
        print('native_ad_loading');
        nativeAdStopwatch.start();
        break;

      case AdLoadState.loadCompleted: // Todo: add event and timer
        print('native_ad_loaded');

        FirebaseAnalytics().logEvent(
          name: 'native_ad_loading_success',
          parameters: {'time_elapsed': nativeAdStopwatch.elapsed.inSeconds},
        );

        // c.complete(nativeAd);
        break;

      case AdLoadState.loadError:
        FirebaseAnalytics().logEvent(
          name: 'native_ad_loading_error',
          parameters: {'time_elapsed': nativeAdStopwatch.elapsed.inSeconds},
        );

        print('native_ad_loading_error');
        // c.complete(nativeAd);
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {

    SharedPreferences.getInstance().then((prefs) {

      if (prefs.getInt('premiumTimeout') ?? 0 > DateTime.now().millisecondsSinceEpoch) {
        Premium.premium = true;
      } else {
        Premium.premium = false;
      }
    });

    FirebaseAdMob.instance.initialize(appId: AdMobService.getAdMobAppId());

    AdMobService.loadCropScreenBannerAd();

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

    // nativeAd.createElement();
    // nativeAd.createState();

    var homePage = HomePage(nativeAd);

    return Stack(children: [
      Container(
          // visible: false,
          child: Container(
        child: nativeAd,
      )),
      SplashScreen(
        seconds: 2,
        // navigateAfterSeconds: new HomePage(_nativeAdController),
        navigateAfterSeconds: homePage,
        // navigateAfterFuture:
        // c.future.then((value) => HomePage(_nativeAdController)),
        // c.future,
        // title: new Text(
        //   'Welcome In SplashScreen',
        //   style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
        // ),
        image: Image.asset('assets/splash/splash.png'),
        backgroundColor: Colors.white,
        // styleTextUnderTheLoader: new TextStyle(),
        photoSize: 165.0,
        // onClick: () => print("Flutter Egypt"),
        loaderColor: primaryColor,
      ),
    ]);
  }
}
