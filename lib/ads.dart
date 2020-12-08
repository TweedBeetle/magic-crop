import 'dart:io';

import 'package:firebase_admob/firebase_admob.dart';

MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
  keywords: <String>['photo editing', 'instagram'],
  // contentUrl: 'https://flutter.io',
  childDirected: false,
  nonPersonalizedAds: false,
  // testDevices: <String>['RF8M91E28RZ'], // Android emulators are considered test devices
  testDevices: <String>[
    '4115B874247D9B6E43A655F56BCDD243',
    'fbc93fae-84d7-4a0d-a662-ce0288d78104',
    'RF8M91E28RZ',
  ], // Android emulators are considered test devices
);

class AdMobService {
  // static var ams;
  // final ams = AdMobService();

  static Future<bool> bannerLoading;
  static Future<bool> bannerShowing;

  static bool bannerLoaded;
  static bool bannerShown;

  static int lastBannerLoad = 0;


  static String getAdMobAppId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-3070348102899963~1788747323';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3070348102899963~8024667394';
    }
    return null;
  }

  static String _getCropScreenBannerAdId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-3070348102899963/3975410041';
      return 'ca-app-pub-3940256099942544/6300978111'; // test
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3070348102899963/6659614832';
      // return 'ca-app-pub-3940256099942544/6300978111'; // test
    }
    return null;
  }

  static String getRewardedVideoAdId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-3070348102899963/3594521690';
      // return 'ca-app-pub-3940256099942544/5224354917'; // test
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3070348102899963/9390801528';
      // return 'ca-app-pub-3940256099942544/5224354917'; // test
    }
    return null;
  }

  static String getNativeAdvancedAdId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-3070348102899963/6696875918';
      return 'ca-app-pub-3940256099942544/2247696110';  // test
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3070348102899963/9317831090';
      // return 'ca-app-pub-3940256099942544/2247696110';  // test
      // return ' 	ca-app-pub-3940256099942544/1044960115'; // video
    }
    return null;
  }

  static BannerAd cropScreenBannerAd;

  static BannerAd _getCropScreenBannerAd() {
    var bannerAd = BannerAd(
      adUnitId: _getCropScreenBannerAdId(),
      size: AdSize.fullBanner,
      targetingInfo: targetingInfo,
    );

    // bannerLoaded = bannerAd

    return bannerAd;
    // adUnitId: _getCropScreenBannerAdId(), size: AdSize.smartBanner);
  }

  // static void loadAds() {
  // }

  static Future<void> loadCropScreenBannerAd() async {
    //
    // if (cropScreenBannerAd == null)
    //   cropScreenBannerAd = _getCropScreenBannerAd();
    //
    // await cropScreenBannerAd.load().then((value) => {print('banner ad loaded')});

    print('trying to show banner ad');

    if (cropScreenBannerAd == null)
      cropScreenBannerAd = _getCropScreenBannerAd();

      if ((DateTime.now().millisecondsSinceEpoch - lastBannerLoad).abs() < 60 * 1000) {
        return;
      }

      await cropScreenBannerAd.load().then((value) => {print('banner ad loaded')});
      lastBannerLoad = DateTime.now().millisecondsSinceEpoch;

  }

  static void showCropScreenBannerAd(double anchorOffset) async {

    // ..then((value) {
    //   bannerLoaded = true;
    // });

    // if ((DateTime.now().millisecondsSinceEpoch - lastBannerLoad).abs() < 60 * 1000) {
    //   return;
    // }

    if (cropScreenBannerAd == null) {
      return;
    }

    await cropScreenBannerAd.show(
      anchorType: AnchorType.top,
      anchorOffset: anchorOffset,
    ).then((value) => {print('banner ad shown')});

    // print('bannerShouldBeShowing: $bannerShouldBeShowing');

    // if (! bannerShouldBeShowing) {
    //   hideCropScreenAd();
    // }
    // });

    // bannerInitialising = false;

    // _cropScreenBannerAd
    //   ..load()
    //   ..show(
    //     anchorType: AnchorType.top,
    //     anchorOffset: anchorOffset,
    //   );
  }

  static void hideCropScreenAd() async {
    if (cropScreenBannerAd == null) return;

    // await bannerLoaded;

    await cropScreenBannerAd.dispose();
    cropScreenBannerAd = null;
    // bannerLoaded = Future<bool>.value(false);

    bannerLoading = null;
    bannerShowing = null;
  }
}
