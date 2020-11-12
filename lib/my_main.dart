import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

// import 'package:flutter/foundation.dart';
import 'package:bitmap/bitmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_new/matrix.dart';
import 'package:flutter_app_new/seam_carving.dart';
import 'package:flutter_app_new/utils.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photofilters/filters/image_filters.dart';
import 'package:photofilters/filters/subfilters.dart';
import 'package:photofilters/photofilters.dart';
import 'package:image/image.dart' as imageLib;
import 'package:image_picker/image_picker.dart';
import 'package:photofilters/utils/convolution_kernels.dart';
import 'package:vector_math/vector_math.dart';
import 'package:binary/binary.dart';
import 'package:tflite/tflite.dart';

ResizeableImage resizeableImage;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(new MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

final picker = ImagePicker();

class _MyAppState extends State<MyApp> {
  String fileName;
  File originalImageFile;
  File progressImageFile;

  // ui.Image progressImage;
  Image progressImage;

  File resizedImageFile;
  var ci;
  List<int> edgesY;
  List<int> edgesX;

  Future<String> resizeImageFuture;
  Bitmap progressImageBitmap;

  // ResizeableImage resizeableImage;

  bool initialised = false;

  Directory tempDir;

  double _progress;

  // get

  Future init() async {
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
    // @todo: handle failure ^
  }

  Future pickImage(context) async {
    await Permission.storage.request();

    progressImageFile = null;
    originalImageFile = null;
    resizeImageFuture = null;
    progressImage = null;
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
      maxHeight: 1280,
      maxWidth: 1280,
      // maxHeight: 1080,
      // maxWidth: 1080,
      // maxHeight: 720,
      // maxWidth: 720,
    );

    // pickedImageFile.readAsBytes()
    // imageLib.Image a = imageLib.decodeImage(await pickedImageFile.readAsBytes());

    // originalImageFile = File(pickedImageFile.path);

    await fixExifRotation(pickedImageFile.path);

    setState(() {
      originalImageFile = File(pickedImageFile.path);
    });


    resizeableImage = ResizeableImage(
      originalImageFile,
      beingProtection: false,
      // beingProtection: true,
      debug: false,
      // debug: true,
      speedup: 1,
      video: false,
      // video: true,
    );
    // var storagePermission = await Permission.storage.status;
    // print(storagePermission);
//
//    final PermissionHandler _permissionHandler = PermissionHandler();
//    var result = await _permissionHandler.requestPermissions([PermissionGroup.contacts]);

//    if (!(await Permission.storage.request().isGranted)) {
//       @todo
//    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Filter Example'),
      ),
      body: Center(
        child: Column(
          children: [
            Container(
              child: resizeImageFuture == null
                  ? Center(child: Text('No image selected.'))
                  // ? Center(child: CircularProgressIndicator())
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
                            resizedImageFile = File(snapshot.data);
                            return Image.file(
                              resizedImageFile,
                              gaplessPlayback: true,
                            );
                        }
                        return null;
                      },
                    ),

              // : Text('done'),
            ),
            // resizeImageFuture == null
            //     ? null
            //     : LinearProgressIndicator(value: _progress, minHeight: 20),
            Offstage(
              offstage: resizeImageFuture == null || _progress == 1,
              child: LinearProgressIndicator(value: _progress, minHeight: 20),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async => {
          imageCache.clear(),
          // resizeableImage = null,
          await pickImage(context),
          resizeImageFuture = resizeImage()
          // convolveAndDisplay(imageFile),
        },
        tooltip: 'Pick Image',
        child: Icon(Icons.add_photo_alternate),
      ),
    );
  }

  Future<String> resizeImage() async {
    ReceivePort progressPort = ReceivePort();
    ReceivePort pathPort = ReceivePort();
    // Stopwatch totalStopwatch = new Stopwatch()..start();

    resizeableImage.progressSendPort = progressPort.sendPort;

    Map params = {
      'resizeableImage': resizeableImage,
      'scale': 1.0,
      'squeezeToStretchRatio': 0.5,
      'pathSendPort': pathPort.sendPort,
      'tempDir': tempDir,
    };

    Isolate isolate = await Isolate.spawn(resizeImageIsolate, params);
    // await resizeImageIsolate(params);

    String path;

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
    isolate.kill();
    return path;
  }
}

Future resizeImageIsolate(Map params) async {
  await params['resizeableImage'].init(params['tempDir']);

  String path = await params['resizeableImage'].atRatio(
    params['scale'],
    params['squeezeToStretchRatio'],
    // 0,
    // 0.5,
  );

  params['pathSendPort'].send(path);
  return;
}
