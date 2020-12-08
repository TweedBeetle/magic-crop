import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_new/dialogs/aspectDialog.dart';
import 'package:flutter_app_new/dialogs/getPremiumAccount.dart';
import 'package:flutter_app_new/dialogs/oneLastThing.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite/tflite.dart';
import 'package:tip_dialog/tip_dialog.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:bitmap/bitmap.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';

import '../ads.dart';
import '../config.dart';
import '../custom_icons_icons.dart';
import '../matrix.dart';
import '../premium.dart';
import '../remote_config.dart';
import '../seam_carving.dart';

final List<List> aspectRatios = [
  [1, 1],
  [16, 9],
  // [9, 16],
  [4, 3],
  // [3, 4],
  // [2, 1],
  // [1, 2]
];

class CropScreen extends StatefulWidget {
  File originalImageFile;
  BuildContext context;

  CropScreen(this.context, this.originalImageFile);

  @override
  _CropScreenState createState() =>
      _CropScreenState(this.context, originalImageFile);
}

Future resizeImageIsolate(Map params) async {
  // await initRemoteConfig();
  // await remoteConfig.fetch(expiration: const Duration(hours: 5));
  // await remoteConfig.activateFetched();
  // print('welcome message: ' + remoteConfig.getString('welcome'));

  // ReceivePort cancelPort = ReceivePort().asBroadcastStream();
  ReceivePort cancelPort = ReceivePort();
  params['resizeableImage'].progressSendPort.send(cancelPort.sendPort);
  params['resizeableImage'].cancelPort = cancelPort;

  await params['resizeableImage']
      .init(params['tempDir'], params['segmentationResult']);

  // params['resizeableImage'].segmentationResult = params['segmentationResult'];

  String path = await params['resizeableImage'].atRatio(
    params['scale'],
    params['squeezeToStretchRatio'],
    // 0,
    // 0.5,
  );

  cancelPort.close();

  params['pathSendPort'].send(path);
  return;
}

class _CropScreenState extends State<CropScreen> {
  final File originalImageFile;

  ResizeableImage resizeableImage;
  Future<String> resizeImageFuture;

  Image progressImage;

  File resizedImageFile;

  double _progress = 1;
  Bitmap progressImageBitmap;

  Directory tempDir;

  // double originalAspectRatio = 1;
  double selectedAspectRatio = 1;

  bool customRatioActive = false;

  double statusBarHeight;

  bool cancel = false;

  SendPort cancelSendPort;

  bool _rewardedAdReady = false;

  bool everResized = false;

  bool oneLastThing = false;

  Stopwatch cropStopwatch;

  double bannerHeight;

  _CropScreenState(BuildContext context, this.originalImageFile) {
    if (statusBarHeight == null) {
      statusBarHeight = MediaQuery.of(context).padding.top;
    }

    bannerHeight = Premium.premium ? 40 : 70;

    if (!Premium.premium) {
      AdMobService.loadCropScreenBannerAd().then((_) {
        AdMobService.showCropScreenBannerAd(statusBarHeight);
      });
      // AdMobService.showCropScreenBannerAd(statusBarHeight);
    }

    // print(RewardedVideoAd)

    if (RewardedVideoAd.instance.listener == null) {
      RewardedVideoAd.instance.listener = _onRewardedAdEvent;
    } else {
      _rewardedAdReady = true;
    }
    _loadRewardedAd();

    resizeableImage = ResizeableImage(
      originalImageFile,
      // beingProtection: false,
      beingProtection: true,
      debug: false,
      // debug: true,
      speedup: 1,
      // video: true,
      video: false,
    );
  }

  void _loadRewardedAd() {
    print('loading rewarded ad');
    RewardedVideoAd.instance
        .load(
          adUnitId: AdMobService.getRewardedVideoAdId(),
          targetingInfo: targetingInfo,
        )
        .then((value) => print('rewarded ad loaded'));
  }

  void _onRewardedAdEvent(RewardedVideoAdEvent event,
      {String rewardType, int rewardAmount}) {
    print('reward event $event');
    switch (event) {
      case RewardedVideoAdEvent.loaded:
        setState(() {
          _rewardedAdReady = true;
        });
        break;
      case RewardedVideoAdEvent.closed: // TODO: add firebase event
        _loadRewardedAd();
        FirebaseAnalytics().logEvent(name: 'close_rewarded_ad');
        setState(() {
          _rewardedAdReady = false;
        });
        break;
      case RewardedVideoAdEvent.failedToLoad:
        FirebaseAnalytics().logEvent(name: 'rewarded_ad_load_failure');
        setState(() {
          _rewardedAdReady = false;
        });
        break;
      case RewardedVideoAdEvent.rewarded:
        FirebaseAnalytics().logEvent(name: 'rewarded_ad_reward_granted');
        _loadRewardedAd();
        // TODO

        Premium.premium = true;
        int premiumTimeout =
            DateTime.now().millisecondsSinceEpoch + 60 * 60 * 1000;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('premiumTimeout', premiumTimeout);
        }).then((_) {
          print('premiumTimeout: $premiumTimeout');
        });

        break;
      default:
      // do nothing
    }
  }

  void reset() {
    // progressImageFile = null;
    // originalImageFile = null;
    imageCache.clear();
    setState(() {
      _progress = 1;
      resizeImageFuture = null;
      // resizedImageFile = null;
      progressImage = null;
    });
  }

  Future<String> resizeImage() async {
    // testRemoteConfig();

    // Completer completer = new Completer<SendPort>();

    ReceivePort progressPort = ReceivePort();
    ReceivePort pathPort = ReceivePort();

    tempDir = await getTemporaryDirectory();

    // Stopwatch totalStopwatch = new Stopwatch()..start();

    resizeableImage.progressSendPort = progressPort.sendPort;
    // resizeableImage.cancelPort = cancelPort;

    // cancelSendPort = cancelPort.sendPort;

    // resizeableImage.progressSendPort = progressPort.sendPort;
    // resizeableImage.segmentationResultPort = segmentationResultPort;

    Uint8List segmentationResult;

    if (resizeableImage.beingProtection) {
      segmentationResult = await Tflite.runSegmentationOnImage(
        path: resizeableImage.originalImagePath,
        // labelColors: [...], // defaults to https://github.com/shaqian/flutter_tflite/blob/master/lib/tflite.dart#L219
        outputType: "bytes",
      );
    }

    Map params = {
      'resizeableImage': resizeableImage,
      'scale': selectedAspectRatio,
      'squeezeToStretchRatio': _squeezeToStretchRatio / 1000,
      'pathSendPort': pathPort.sendPort,
      'tempDir': tempDir,
      'segmentationResult': segmentationResult,
      // 'cancelSendPort': cancelPort.sendPort,
      // 'segmentationParamSendPort': segmentationParamPort.sendPort,
      // 'segmentationResultPort': segmentationResultPort,
    };

    Isolate isolate;

    isolate = await Isolate.spawn(resizeImageIsolate, params);
    // await resizeImageIsolate(params);

    String path;

    // String imagePath = await segmentationParamPort.first;
    //
    // if (imagePath != null) {
    //   segmentationResultPort.sendPort.send(await Tflite.runSegmentationOnImage(
    //     path: imagePath,
    //     // labelColors: [...], // defaults to https://github.com/shaqian/flutter_tflite/blob/master/lib/tflite.dart#L219
    //     outputType: "bytes",
    //   ));
    // }

    await for (var update in progressPort) {
      if (update is SendPort) {
        setState(() {
          cancelSendPort = update;
        });
        continue;
      }

      if (update is bool) {
        // numSeamsToBeAltered = 0;
        setState(() {
          cancel = true;
        });
      }

      if (cancel) {
        if (isolate != null) {
          print('killing isolate');
          isolate.kill(priority: 0);
        }
        break;
      }

      setState(() {
        _progress = update['progress'];

        if (update['updatedProgressImage']) {
          Matrix2D<Uint32List> imageMatrix =
              update['currentProgressImageMatrix'];

          progressImageBitmap = Bitmap.fromHeadless(
            imageMatrix.width,
            imageMatrix.height,
            imageMatrix.data.buffer.asUint8List(0, imageMatrix.data.length * 4),
          );

          progressImage = Image.memory(
            progressImageBitmap.buildHeaded(),
            gaplessPlayback: true,
          );
        }
      });

      if (update['done']) {
        break;
      }
    }

    if (cancel) {
      path = null;
      reset();
    } else {
      path = await pathPort.first;
    }

    progressPort.close();
    pathPort.close();

    if (!cancel) {
      if (isolate != null) {
        isolate.kill();
      }
      setState(() {
        everResized = true;
      });
    }

    FirebaseAnalytics().logEvent(name: 'crop_completion', parameters: {
      'scale': selectedAspectRatio,
      'squeezeToStretchRatio': _squeezeToStretchRatio / 1000,
      'time_elapsed': cropStopwatch.elapsed.inSeconds,
    });

    cancel = false;
    return path;
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.width;

    double statusBarHeight = MediaQuery.of(context).padding.top;

    double topRowInset;

    if (Premium.premium) {
      topRowInset = 30;
    } else {
      topRowInset = statusBarHeight + 20;
    }

    EdgeInsets edgeInsets =
        EdgeInsets.only(left: 20, right: 20, top: topRowInset, bottom: 0);
    return WillPopScope(
        onWillPop: () {
          bool pop;
          if (_progress != 1) {
            setState(() {
              cancel = true;
            });
            pop = false;
          } else {
            AdMobService.hideCropScreenAd();
            pop = true;
          }
          return Future<bool>.value(pop);
        },
        child: Stack(children: [
          SafeArea(
              child: Scaffold(
            resizeToAvoidBottomPadding: false,
            backgroundColor: backgroundColor,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                    padding: edgeInsets,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: bannerHeight,
                          alignment: Alignment.centerLeft,
                          // padding: const EdgeInsets.only(left: 20, top: 20),
                          child: InkWell(
                            customBorder: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                            onTap: _progress != 1
                                ? () {}
                                : () {
                                    FirebaseAnalytics().logEvent(
                                        name: 'back_arrow_press',
                                        parameters: null);

                                    AdMobService.hideCropScreenAd();
                                    // AdMobService.hideCropScreenAd();
                                    Navigator.of(context).pop();
                                    // Navigator.of(context).pop();
                                  },
                            child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Color.fromRGBO(238, 238, 255, 1),
                                ),
                                child: Icon(
                                  Icons.arrow_back,
                                  color: _progress != 1
                                      ? Colors.grey
                                      : primaryColor,
                                )),
                          ),
                        ),
                        Visibility(
                            visible: !Premium.premium,
                            child: Container(
                              height: bannerHeight,
                              alignment: Alignment.centerRight,
                              // padding: const EdgeInsets.only(right: 20, top: 20),
                              child: InkWell(
                                customBorder: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5)),
                                onTap: () {
                                  FirebaseAnalytics().logEvent(
                                      name: 'premium_button_press',
                                      parameters: {
                                        'rewarded_ad_ready': _rewardedAdReady
                                      });

                                  showDialog(
                                      context: context,
                                      builder: (context) =>
                                          PremiumDialogue(_rewardedAdReady));
                                  // Navigator.of(context).pop();
                                },
                                child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: Color.fromRGBO(238, 238, 255, 1),
                                    ),
                                    child: Icon(
                                      MdiIcons.crown,
                                      color: specialColor,
                                    )),
                              ),
                            ))
                      ],
                    )),
                // SizedBox(
                //   height: 10,
                // ),
                Expanded(
                  child: Container(
                    child: originalImageFile == null
                        // ? Center(child: Text('No image selected.'))
                        ? Center(
                            child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(primaryColor),
                          ))
                        // : Text('done'),
                        : FutureBuilder(
                            future: resizeImageFuture,
                            // future: compute(convolveAndDisplay, imageFile),
                            // future: compute( sleep, const Duration(seconds:5)),
                            builder: (context, snapshot) {
                              switch (snapshot.connectionState) {
                                case ConnectionState.none:
                                case ConnectionState.active:
                                case ConnectionState.waiting:
                                  if (progressImage == null) {
                                    return Image.file(
                                      originalImageFile,
                                      gaplessPlayback: true,
                                    );
                                  }

                                  // return Image.file(
                                  //   progressImageFile,
                                  //   gaplessPlayback: true,
                                  // );

                                  // return progressImage = Image.memory(
                                  //   progressImageBitmap.buildHeaded(),
                                  //   gaplessPlayback: true,
                                  // );

                                  return progressImage;

                                // return Image.memory(bytes)

                                case ConnectionState.done:
                                  if (snapshot.hasError)
                                    return Center(
                                        child:
                                            Text('Error: ${snapshot.error}'));

                                  // setState(() {

                                  // });

                                  resizedImageFile = File(snapshot.data);
                                  // resizedImageFile.sa
                                  return Image.file(
                                    resizedImageFile,
                                    gaplessPlayback: true,
                                  );
                              }
                              return null;
                            },
                          ),
                  ),
                ),
                resizeImageFuture == null || _progress == 1
                    ? buildSlider(context, height)
                    : Container(
                        margin: const EdgeInsets.only(bottom: 20, top: 20),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 20,
                          valueColor: AlwaysStoppedAnimation(primaryColor),
                        ),
                      ),
                Container(
                  height: height * 0.2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    child: Row(

                        // scrollDirection: Axis.horizontal,
                        // padding: const EdgeInsets.all(10.0),
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                              aspectRatios.length,
                              (index) {
                                double aspectRatio = aspectRatios[index][0] /
                                    aspectRatios[index][1];

                                return InkWell(
                                  customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                  onTap: _progress != 1
                                      ? () {}
                                      : () {
                                          FirebaseAnalytics().logEvent(
                                              name: 'aspect_ratio_select',
                                              parameters: {
                                                'ratio': aspectRatio
                                              });

                                          if (!Premium.premium) {
                                            showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    PremiumDialogue(
                                                        _rewardedAdReady));
                                            return;
                                          }

                                          setState(() {
                                            customRatioActive = false;
                                            selectedAspectRatio = aspectRatio;
                                          });
                                        },
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                          side: new BorderSide(
                                              color: aspectRatio ==
                                                      selectedAspectRatio
                                                  ? (_progress != 1
                                                      ? Colors.grey
                                                      : primaryColor)
                                                  : Colors.white,
                                              width: 2.0),
                                          borderRadius:
                                              BorderRadius.circular(5.0)),
                                      elevation: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        child: Container(
                                          // margin: const EdgeInsets.all(15.0),
                                          // padding: const EdgeInsets.all(3.0),
                                          // decoration: BoxDecoration(
                                          //     border:
                                          //         Border.all(color: primaryColor, width: 2)),
                                          child: Center(
                                            child: AutoSizeText(
                                              '${aspectRatios[index][0]} ‎: ‎${aspectRatios[index][1]}',
                                              minFontSize: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ) +
                            [
                              InkWell(
                                onTap: _progress != 1
                                    ? () {}
                                    : () {
                                        FirebaseAnalytics().logEvent(
                                            name: 'custom_ratio_press',
                                            parameters: null);

                                        // if (Premium.premium) {}

                                        showDialog(
                                            context: context,
                                            builder: (context) => !Premium
                                                    .premium
                                                ? PremiumDialogue(
                                                    _rewardedAdReady)
                                                : AspectDialog(
                                                    aspectRatioHandler:
                                                        (width, height) {
                                                      setState(() {
                                                        customRatioActive =
                                                            true;
                                                        selectedAspectRatio =
                                                            int.parse(width) /
                                                                int.parse(
                                                                    height);

                                                        FirebaseAnalytics()
                                                            .logEvent(
                                                                name:
                                                                    'custom_ratio_enter',
                                                                parameters: {
                                                              'ratio':
                                                                  selectedAspectRatio
                                                            });
                                                      });

                                                      // print(selectedAspectRatio);
                                                      // print(height);
                                                    },
                                                  ));
                                      },
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                        side: new BorderSide(
                                            color: customRatioActive
                                                ? primaryColor
                                                : Colors.white,
                                            width: 2.0),
                                        borderRadius:
                                            BorderRadius.circular(4.0)),
                                    elevation: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      child: Container(
                                        // margin: const EdgeInsets.all(15.0),
                                        // padding: const EdgeInsets.all(3.0),
                                        // decoration: BoxDecoration(
                                        //     border:
                                        //         Border.all(color: primaryColor, width: 2)),
                                        child: Center(
                                          child: AutoSizeText(
                                            // '? ‎: ?',
                                            'custom',
                                            minFontSize: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ]
                        // [
                        ),
                  ),
                ),
                buildFooter(context)
              ],
            ),
          )),
          TipDialogContainer(duration: const Duration(milliseconds: 1350)),
        ]));
  }

  double _squeezeToStretchRatio = 750;

  Container buildSlider(context, height) {
    return Container(
      height: height * 0.15,
      child: Row(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Tooltip(
                preferBelow: false,
                showDuration: Duration(seconds: 4),
                child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: secondaryColor,
                    ),
                    child: Icon(
                      CustomIcons.expand,
                      color: primaryColor,
                    )),
                message:
                    "Moving the slider to this side will make your image stretch along it's shorter side rather than shrink along it's longer side"),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: primaryColor,
                inactiveTrackColor: primaryColor,
                trackShape: RectangularSliderTrackShape(),
                trackHeight: 4.0,
                thumbColor: primaryColor,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
                overlayColor: Colors.red.withAlpha(32),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 28.0),
              ),
              child: Container(
                child: Slider(
                  min: 0,
                  max: 1000,
                  // divisions: 40,
                  value: _squeezeToStretchRatio,
                  onChanged: (value) {
                    setState(() {
                      _squeezeToStretchRatio = value;
                    });
                  },
                  // onChangeStart: (_) {},
                  onChangeEnd: (value) {
                    // reset();

                    FirebaseAnalytics().logEvent(
                        name: 'slider_changed', parameters: {'value': value});

                    setState(() {
                      _squeezeToStretchRatio = value;
                      // resizeImageFuture = resizeImage();
                    });
                  },
                ),
              ),
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(right: 20),
            child: Tooltip(
              preferBelow: false,
              showDuration: Duration(seconds: 4),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: secondaryColor,
                ),
                // child: Icon(
                //   Icons.reduce_capacity,
                //   color: primaryColor,
                // )),
                child: Icon(
                  CustomIcons.shrink,
                  color: primaryColor,
                ),
              ),
              message:
                  "Moving the slider to this side will make your image shrink along it's longer side rather than stretch along it's shorter side",
            ),
          )
        ],
      ),
    );
  }

  Container buildFooter(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    var cropButton = InkWell(
      customBorder:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: _progress != 1
          ? () {}
          : () {
              cropStopwatch = Stopwatch()..start();

              FirebaseAnalytics().logEvent(name: 'crop_start', parameters: {
                'scale': selectedAspectRatio,
                'squeezeToStretchRatio': _squeezeToStretchRatio / 1000,
              });

              reset();
              setState(() {
                _progress = null;
                resizeImageFuture = resizeImage();
              });
            },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        color: _progress != 1 ? Colors.grey : primaryColor,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          child: Icon(
            MdiIcons.crop,
            color: Colors.white,
          ),
        ),
      ),
    );

    var cancelButton = InkWell(
      customBorder:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        FirebaseAnalytics().logEvent(name: 'crop_cancel', parameters: {
          'scale': selectedAspectRatio,
          'squeezeToStretchRatio': _squeezeToStretchRatio / 1000,
          'progress': _progress,
          'time_elapsed': cropStopwatch.elapsed,
        });

        setState(() {
          cancel = true;
        });
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        color: Colors.red,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.cancel,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Container(
      height: height * 0.12,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          InkWell(
              onTap: _progress != 1 || !everResized
                  ? () {}
                  : () async {
                      FirebaseAnalytics().logEvent(
                          name: 'share_button_press', parameters: null);

                      if (oneLastThing) {
                        await showDialog(
                            context: context,
                            builder: (context) =>
                                OneLastThingDialogue((res) => {}));
                      }

                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setInt('lastShareOrSave',
                            DateTime.now().millisecondsSinceEpoch);
                      });

                      var bytes = await resizedImageFile.readAsBytes();
                      print('loaded');

                      await Share.file(
                        'image resized using magic crop',
                        'magic_crop_image.png',
                        bytes.buffer.asUint8List(),
                        'image/png',
                        // text: 'My optional text.',
                      );
                    },
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 5,
                shadowColor: secondaryColor,
                color: secondaryColor,
                child: Container(
                    padding: const EdgeInsets.all(10),
                    height: 50,
                    width: 50,
                    child: Icon(
                      MdiIcons.shareVariant,
                      color: _progress != 1 || !everResized
                          ? Colors.grey
                          : primaryColor,
                    )),
              )),
          Expanded(
            child: FittedBox(
              child: Container(
                padding: const EdgeInsets.all(10),
                child: _progress != 1 ? cancelButton : cropButton,
              ),
            ),
          ),
          InkWell(
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: _progress != 1 || !everResized
                  ? () {}
                  : () async {
                      FirebaseAnalytics().logEvent(
                          name: 'save_button_press', parameters: null);

                      if (oneLastThing) {
                        await showDialog(
                            context: context,
                            builder: (context) =>
                                OneLastThingDialogue((res) => {}));
                      }

                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setInt('lastShareOrSave',
                            DateTime.now().millisecondsSinceEpoch);
                      });

                      await GallerySaver.saveImage(resizedImageFile.path);

                      // TipDialogHelper.success("Image saved");

                      TipDialogHelper.show(
                          tipDialog: new TipDialog.customIcon(
                        icon: new Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 30.0,
                          textDirection: TextDirection.ltr,
                        ),
                        tip: "Image saved",
                      ));
                      // showDialog(
                      //   context: context,
                      //   builder: (_) => AlertDialog(
                      //     title: Center(child: Text('Image Saved')),
                      //   ),
                      // );
                    },
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 5,
                shadowColor: secondaryColor,
                color: secondaryColor,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  height: 50,
                  width: 50,
                  child: Icon(
                    MdiIcons.contentSave,
                    color: _progress != 1 || !everResized
                        ? Colors.grey
                        : primaryColor,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
