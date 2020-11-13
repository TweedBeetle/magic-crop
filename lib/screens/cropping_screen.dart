import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/services.dart';
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

import '../config.dart';
import '../custom_icons_icons.dart';
import '../matrix.dart';
import '../seam_carving.dart';

List<List> aspectRatios = [
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

  CropScreen(this.originalImageFile);

  @override
  _CropScreenState createState() => _CropScreenState(originalImageFile);
}

Future resizeImageIsolate(Map params) async {
  await params['resizeableImage'].init(params['tempDir'], params['segmentationResult']);

  // params['resizeableImage'].segmentationResult = params['segmentationResult'];

  String path = await params['resizeableImage'].atRatio(
    params['scale'],
    params['squeezeToStretchRatio'],
    // 0,
    // 0.5,
  );

  params['pathSendPort'].send(path);
  return;
}

class _CropScreenState extends State<CropScreen> {
  final File originalImageFile;

  ResizeableImage resizeableImage;
  Future<String> resizeImageFuture;

  Image progressImage;

  File resizedImageFile;

  double _progress;
  Bitmap progressImageBitmap;

  Directory tempDir;

  double selectedAspectRatio = 1;

  _CropScreenState(this.originalImageFile) {
    resizeableImage = ResizeableImage(
      originalImageFile,
      // beingProtection: false,
      beingProtection: true,
      debug: false,
      // debug: true,
      speedup: 1,
      video: false,
      // video: true,
    );

    // resizeImageFuture = resizeImage();
  }

  void reset() {
    // progressImageFile = null;
    // originalImageFile = null;
    imageCache.clear();
    setState(() {
      _progress = null;
      resizeImageFuture = null;
      resizedImageFile = null;
      progressImage = null;
    });
  }

  Future<String> resizeImage() async {
    ReceivePort progressPort = ReceivePort();
    ReceivePort pathPort = ReceivePort();

    ReceivePort segmentationParamPort = ReceivePort();
    ReceivePort segmentationResultPort = ReceivePort();

    tempDir = await getTemporaryDirectory();
    // Stopwatch totalStopwatch = new Stopwatch()..start();

    // @todo: move into init()
    resizeableImage.progressSendPort = progressPort.sendPort;
    resizeableImage.segmentationParamSendPort = segmentationParamPort.sendPort;
    // resizeableImage.segmentationResultPort = segmentationResultPort;

    Uint8List segmentationResult;

    if (resizeableImage.beingProtection) {
      segmentationResult = await Tflite.runSegmentationOnImage(
        path: resizeableImage.imagePath,
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

    path = await pathPort.first;

    progressPort.close();
    pathPort.close();
    segmentationParamPort.close();
    segmentationResultPort.close();

    if (isolate != null) {
      isolate.kill();
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.width;

    return Stack(children: [
      SafeArea(
          child: Scaffold(
        backgroundColor: backgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Container(child: TipDialogContainer(duration: const Duration(seconds: 1))),
            // TipDialogContainer(duration: const Duration(seconds: 1)),
            Container(
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.black)),
              // @todo add ad
              height: height * 0.14,
              margin: EdgeInsets.only(top: 35),
              child: Text('ad placeholder'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 70,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20, top: 20),
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Color.fromRGBO(238, 238, 255, 1),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: primaryColor,
                        )),
                  ),
                ),
                Container(
                  height: 70,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20, top: 20),
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    onTap: () {
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
                          color: Colors.orangeAccent,
                        )),
                  ),
                )
              ],
            ),
            SizedBox(
              height: 10,
            ),
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
                              // print("done apparently");
                              // print(snapshot.data);
                              // assert(snapshot.hasData);
                              if (snapshot.hasError)
                                return Center(
                                    child: Text('Error: ${snapshot.error}'));

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
                : LinearProgressIndicator(
                    value: _progress,
                    minHeight: 20,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
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
                            double aspectRatio =
                                aspectRatios[index][0] / aspectRatios[index][1];

                            return InkWell(
                              customBorder: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5)),
                              onTap: () {
                                setState(() {
                                  selectedAspectRatio = aspectRatio;
                                });
                              },
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                      side: new BorderSide(
                                          color:
                                              aspectRatio == selectedAspectRatio
                                                  ? primaryColor
                                                  : Colors.white,
                                          width: 2.0),
                                      borderRadius: BorderRadius.circular(5.0)),
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
                                        child: Text(
                                            '${aspectRatios[index][0]} : ${aspectRatios[index][1]}'),
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
                            onTap: () {
                              // setState(() {
                              //   selectedAspectRatio = 1;
                              // });
                            },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                    side: new BorderSide(
                                        color: 0 == selectedAspectRatio
                                            ? primaryColor
                                            : Colors.white,
                                        width: 2.0),
                                    borderRadius: BorderRadius.circular(4.0)),
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
                                      child: Text('Custom'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        ]
                    // [
                    //   // drawRect(),
                    //   AspectRatio(
                    //     aspectRatio: 1,
                    //     child: Card(
                    //       shape: RoundedRectangleBorder(
                    //           side: new BorderSide(color: false ? primaryColor : Colors.white, width: 2.0),
                    //           borderRadius: BorderRadius.circular(4.0)),
                    //       elevation: 2,
                    //       child: Container(
                    //         padding: const EdgeInsets.all(10),
                    //         child: Container(
                    //           // margin: const EdgeInsets.all(15.0),
                    //           // padding: const EdgeInsets.all(3.0),
                    //           // decoration: BoxDecoration(
                    //           //     border:
                    //           //         Border.all(color: primaryColor, width: 2)),
                    //           child: Center(
                    //             child: Text('1 : 2'),
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    //   // Card(
                    //   //   shape: RoundedRectangleBorder(
                    //   //       borderRadius: BorderRadius.circular(10)),
                    //   //   elevation: 5,
                    //   //   shadowColor: Color(0xff0062FF),
                    //   //   // color: primaryColor,
                    //   //   child: Container(
                    //   //       // height: 60,
                    //   //       padding: const EdgeInsets.all(10),
                    //   //       child: Container(
                    //   //         // margin: const EdgeInsets.all(15.0),
                    //   //         // padding: const EdgeInsets.all(3.0),
                    //   //         decoration: BoxDecoration(
                    //   //             border:
                    //   //                 Border.all(color: primaryColor, width: 2)),
                    //   //         child: Center(child: Text('1:2')),
                    //   //       )),
                    //   // ),
                    // ],
                    // child: Container(
                    //   width: 500,
                    //   alignment: Alignment.centerLeft,
                    //   child: Image.asset(
                    //     "assets/images/aspect_ratio.png",
                    //     fit: BoxFit.fitWidth,
                    //   ),
                    // ),
                    ),
              ),
            ),
            buildFooter(context)
          ],
        ),
      )),
      TipDialogContainer(duration: const Duration(milliseconds: 1350)),
    ]);
  }

  double _squeezeToStretchRatio = 750;

  Container buildSlider(context, height) {
    return Container(
      height: height * 0.15,
      child: Row(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20, top: 10),
            child: Tooltip(
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
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.blue,
                trackShape: RectangularSliderTrackShape(),
                trackHeight: 4.0,
                thumbColor: Colors.blueAccent,
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
            padding: const EdgeInsets.only(right: 20, top: 10),
            child: Tooltip(
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

    return Container(
      height: height * 0.15,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          InkWell(
              onTap: _progress != 1
                  ? () {}
                  : () async {
                      // await GallerySaver.saveImage(resizedImageFile.path);
                      // final ByteData bytes =
                      //     await rootBundle.load(resizedImageFile.path);
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
                      // Icons.share,
                      // Icons.share,
                      MdiIcons.shareVariant,
                      color: _progress != 1 ? Colors.grey : primaryColor,
                    )),
              )),
          Expanded(
            child: FittedBox(
              child: Container(
                padding: const EdgeInsets.all(10),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    reset();
                    setState(() {
                      // _squeezeToStretchRatio = value;
                      resizeImageFuture = resizeImage();
                    });
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                    shadowColor: Color(0xff0062FF),
                    color: primaryColor,
                    child: Container(
                      // height: 60,
                      width: 200,
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        MdiIcons.crop,
                        color: Colors.white,
                      ),
                      // child: Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     Icon(
                      //       MdiIcons.imagePlus,
                      //       color: Colors.white,
                      //     ),
                      //     SizedBox(
                      //       width: 5,
                      //     ),
                      //     Text(
                      //       "Choose new Image From Gallery",
                      //       style: TextStyle(color: Colors.white),
                      //     ),
                      //   ],
                      // ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          InkWell(
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: _progress != 1
                  ? () {}
                  : () async {
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
                    color: _progress != 1 ? Colors.grey : primaryColor,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
