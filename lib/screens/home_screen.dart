import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_new/ads.dart';
import 'file:///C:/Users/chris/AndroidStudioProjects/flutter_app_new/lib/dialogs/settings_menu.dart';
import 'package:flutter_app_new/screens/cropping_screen.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_native_admob/flutter_native_admob.dart';
import 'package:flutter_native_admob/native_admob_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:tflite/tflite.dart';
import 'package:firebase_admob/firebase_admob.dart';

import '../config.dart';
import '../remote_config.dart';
import '../utils.dart';

final ams = AdMobService();

final picker = ImagePicker();

class HomePage extends StatefulWidget {

  // NativeAdmobController nativeAdController;
  NativeAdmob nativeAd;

  // HomePage(this.nativeAdController);
  HomePage(this.nativeAd);

  @override
  _HomePageState createState() =>
      // _HomePageState(nativeAdController);
      _HomePageState(nativeAd);
}

class _HomePageState extends State<HomePage> {
  bool initialised = false;

  Directory tempDir;

  // NativeAdmobController nativeAdController;
  NativeAdmob nativeAd;

  final _nativeAdController = NativeAdmobController();


  // _HomePageState(this.nativeAdController);
  _HomePageState(this.nativeAd);



  @override
  Widget build(BuildContext context) {
    // print('building home');
    // print(AdMobService.bannerInitialising);
    // print(AdMobService.bannerLoaded);
    // print(AdMobService.bannerShown);

    // print(AdMobService.cropScreenBannerAd.isLoaded());
    // print(await AdMobService.bannerShowing);

    print('building HomePage');

    double width = MediaQuery
        .of(context)
        .size
        .width;
    var safeArea = SafeArea(
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 80,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 30, bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("Advertisement"),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(border: Border.all()),
                          child: nativeAd,
                          // child: NativeAdmob(
                          //   // Your ad unit id
                          //   adUnitID: AdMobService.getNativeAdvancedAdId(),
                          //   loading: Center(
                          //       child: CircularProgressIndicator(
                          //         valueColor: AlwaysStoppedAnimation(
                          //             primaryColor),
                          //       )),
                          //   numberAds: 1,
                          //   controller: _nativeAdController,
                          //   type: NativeAdmobType.full,
                          // ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                left: 5,
                child: buildFooter(width, context),
              ),
              // buildFooter(width, context)
            ],
          ),
        ));

    AdMobService.hideCropScreenAd();

    return RateMyAppBuilder(
      builder: (context) => safeArea,
      rateMyApp: RateMyApp(
        preferencesPrefix: 'rateMyApp_',
        minDays: 3,
        minLaunches: 5,
        remindDays: 3,
        remindLaunches: 3,
        googlePlayIdentifier: 'tech.nine_five_nine_two.magic_crop',
        appStoreIdentifier: '', // TODO
      ),
      onInitialized: (context, rateMyApp) {
        // Called when Rate my app has been initialized.

        rateMyApp.conditions.forEach((condition) {
          if (condition is DebuggableCondition) {
            print(condition.valuesAsString +
                ' ${condition
                    .isMet}'); // We iterate through our list of conditions and we print all debuggable ones.
          } else {
            print(condition);
          }
        });

        print('Are all conditions met ? ' +
            (rateMyApp.shouldOpenDialog ? 'Yes' : 'No'));

        if (rateMyApp.shouldOpenDialog) {
          // if (true) {
          rateMyApp.showRateDialog(
            context,
            title: 'Rate this app',
            // The dialog title.
            message: 'Hey there, would you consider giving this app a review?',
            // The dialog message.
            rateButton: 'RATE',
            // The dialog "rate" button text.
            noButton: 'NO THANKS',
            // The dialog "no" button text.
            laterButton: 'MAYBE LATER',
            // The dialog "later" button text.
            listener: (button) {
              // The button click listener (useful if you want to cancel the click event).
              switch (button) {
                case RateMyAppDialogButton.rate:
                  print('Clicked on "Rate".');
                  break;
                case RateMyAppDialogButton.later:
                  print('Clicked on "Later".');
                  break;
                case RateMyAppDialogButton.no:
                  print('Clicked on "No".');
                  break;
              }

              return true; // Return false if you want to cancel the click event.
            },
            ignoreNativeDialog: true,
            // Set to false if you want to show the Apple's native app rating dialog on iOS or Google's native app rating dialog (depends on the current Platform).
            dialogStyle: DialogStyle(),
            // Custom dialog styles.
            onDismissed: () =>
                rateMyApp.callEvent(RateMyAppEventType
                    .laterButtonPressed), // Called when the user dismissed the dialog (either by taping outside or by pressing the "back" button).
            // contentBuilder: (context, defaultContent) => content, // This one allows you to change the default dialog content.
            // actionsBuilder: (context) => [], // This one allows you to use your own buttons.
          );
        }
      },
    );
  }

  Future init() async {
    // await initRemoteConfig();
    // await remoteConfig.fetch(expiration: const Duration(hours: 5));
    // await remoteConfig.activateFetched();
    // print('welcome message: ' + remoteConfig.getString('welcome'));

    String res = await Tflite.loadModel(
        model: "assets/models/lite-model_deeplabv3_1_metadata_2.tflite",
        numThreads: 4,
        // defaults to 1
        isAsset: true,
        // defaults to true, set to false to load resources outside assets
        useGpuDelegate:
        false // defaults to false, set to true to use GPU delegate
    );

    tempDir = await getTemporaryDirectory();

    assert(res == 'success');
    FirebaseAdMob.instance.initialize(appId: AdMobService.getAdMobAppId());

    // @todo: handle failure ^
  }

  Future<File> pickImage(context) async {
    await Permission.storage.request();

    // progressImageFile = null;
    // originalImageFile = null;
    // resizeImageFuture = null;
    // progressImage = null;

    // if (tempDir == null) {
    //   tempDir = await getTemporaryDirectory();
    // }

    if (!initialised) {
      init();
    }

    PickedFile pickedImageFile = await picker.getImage(
      source: ImageSource.gallery,
      // maxHeight: 1920,
      // maxWidth: 1920,
      // maxHeight: 1280,
      // maxWidth: 1280,
      // maxHeight: 1080,
      // maxWidth: 1080,
      maxHeight: 720,
      maxWidth: 720,
    );

    // pickedImageFile.readAsBytes()
    // imageLib.Image a = imageLib.decodeImage(await pickedImageFile.readAsBytes());

    // originalImageFile = File(pickedImageFile.path);

    // return File(pickedImageFile.path);

    // await FlutterExifRotation.rotateImage(path: image.path);

    return await FlutterExifRotation.rotateImage(path: pickedImageFile.path);

    // setState(() {
    //   originalImageFile = File(pickedImageFile.path);
    // });
    //
    //
    // resizeableImage = ResizeableImage(
    //   originalImageFile,
    //   beingProtection: false,
    //   // beingProtection: true,
    //   debug: false,
    //   // debug: true,
    //   speedup: 1,
    //   video: false,
    //   // video: true,
    // );

    // var storagePermission = await Permission.storage.status;
    // print(storagePermission);
//
//    final PermissionHandler _permissionHandler = PermissionHandler();
//    var result = await _permissionHandler.requestPermissions([PermissionGroup.contacts]);

//    if (!(await Permission.storage.request().isGranted)) {
//       @todo
//    }
  }

  Container buildFooter(double width, BuildContext context) {
    return Container(
      // height: 100,
      padding: const EdgeInsets.all(10),
      child: IntrinsicWidth(
          child: Row(
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () {
                  FirebaseAnalytics()
                      .logEvent(name: 'open_settings', parameters: null);

                  showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (builder) {
                        return SettingsMenu();
                      });
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                  shadowColor: primaryColor,
                  color: primaryColor,
                  child: IntrinsicHeight(
                      child: Container(
                          padding: const EdgeInsets.all(10),
                          height: 55,
                          width: 55,
                          child: Image.asset(
                            "assets/images/menu-align-left.png",
                            color: Colors.white,
                          ))),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: InkWell(
                    onTap: () async {
                      File imageFile = await pickImage(context);

                      if (imageFile != null) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => CropScreen(context, imageFile),
                          settings: RouteSettings(name: 'CropScreen'),
                        ));
                      }
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 5,
                      shadowColor: primaryColor,
                      color: primaryColor,
                      child: Container(
                          height: 55,
                          padding: const EdgeInsets.all(15),
                          child: IntrinsicHeight(
                              child: Container(
                                // decoration: BoxDecoration(
                                //     border: Border.all(color: Colors.black)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    // crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        color: Colors.white,
                                      ),
                                      // SizedBox(
                                      //   width: 5,
                                      // ),
                                      Container(
                                        // decoration: BoxDecoration(
                                        //     border:
                                        //         Border.all(color: Colors.black)),
                                        // mar
                                        // padding: const EdgeInsets.all(0),
                                          child: Text(
                                            //@todo: make text larger
                                            "Choose Image",
                                            style: TextStyle(
                                                color: Colors.white),
                                          )),
                                      // SizedBox(
                                      //   width: 5,
                                      // ),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                      )
                                    ],
                                  )))),
                    ),
                  ),
                ),
              )
            ],
          )),
    );
  }
}
