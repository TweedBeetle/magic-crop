import 'dart:io';

import 'package:firebase_admob/firebase_admob.dart';

MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
  keywords: <String>['photo editing', 'instagram'],
  // contentUrl: 'https://flutter.io',
  childDirected: false,
  nonPersonalizedAds: false,
  // testDevices: <String>['RF8M91E28RZ'], // Android emulators are considered test devices
  testDevices: <String>['4115B874247D9B6E43A655F56BCDD243'], // Android emulators are considered test devices
);

class AdMobService {
  // static var ams;
  // final ams = AdMobService();

  static Future<bool> bannerLoading;
  static Future<bool> bannerShowing;

  static bool bannerLoaded;
  static bool bannerShown;

  static bool bannerInitialising;

  static bool bannerShouldBeShowing;

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
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
      // return 'ca-app-pub-3070348102899963/6659614832';
    }
    return null;
  }

  static String getRewardedVideoAdId() {
    if (Platform.isIOS) {
      return 'ca-app-pub-3070348102899963/3594521690';
      // return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3070348102899963/9390801528';
      // return 'ca-app-pub-3940256099942544/5224354917';
    }
    return null;
  }

  static String getNativeAdvancedAdId() {
    if (Platform.isIOS) {
      return ''; // TODO
      return 'ca-app-pub-3940256099942544/2247696110';
    } else if (Platform.isAndroid) {
      // return 'ca-app-pub-3070348102899963/9317831090';
      return 'ca-app-pub-3940256099942544/2247696110';
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

  static void showCropScreenBannerAd(double anchorOffset) async {
    bannerShouldBeShowing = true;

    if (cropScreenBannerAd == null)
      cropScreenBannerAd = _getCropScreenBannerAd();

    bannerInitialising = true;

    await cropScreenBannerAd.load();
    // ..then((value) {
    //   bannerLoaded = true;
    // });

    await cropScreenBannerAd.show(
      anchorType: AnchorType.top,
      anchorOffset: anchorOffset,
    );

    // print('bannerShouldBeShowing: $bannerShouldBeShowing');

    // if (! bannerShouldBeShowing) {
    //   hideCropScreenAd();
    // }
    // });

    print('bannerShouldBeShowing: $bannerShouldBeShowing');

    if (!bannerShouldBeShowing) {
      await cropScreenBannerAd.dispose().then((value) {
        cropScreenBannerAd = null;
      });
      // cropScreenBannerAd = null;
    }

    // bannerInitialising = false;

    // _cropScreenBannerAd
    //   ..load()
    //   ..show(
    //     anchorType: AnchorType.top,
    //     anchorOffset: anchorOffset,
    //   );
  }

  static void hideCropScreenAd() async {
    bannerShouldBeShowing = false;
    if (cropScreenBannerAd == null) return;

    // await bannerLoaded;

    await cropScreenBannerAd.dispose();
    cropScreenBannerAd = null;
    // bannerLoaded = Future<bool>.value(false);

    bannerLoading = null;
    bannerShowing = null;
  }
}
