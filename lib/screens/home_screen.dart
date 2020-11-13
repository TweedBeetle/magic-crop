import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_new/main_bottom_sheet.dart';
import 'package:flutter_app_new/screens/cropping_screen.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite/tflite.dart';

import '../config.dart';
import '../utils.dart';

final picker = ImagePicker();

class HomePage extends StatelessWidget {
  bool initialised = false;
  Directory tempDir;

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

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return SafeArea(child:Scaffold(
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
                      child: Text('ad placeholder'), // @todo add ad
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            left: 0,
            child: buildFooter(width, context),
          )
        ],
      ),
    ));
  }

  Container buildFooter(double width, BuildContext context) {
    return Container(
      // height: 100,
      padding: const EdgeInsets.all(10),
      child: IntrinsicWidth(
          child: Row(
        // crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
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
                        builder: (context) => CropScreen(imageFile)));
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            "Choose Image From Gallery",
                            style: TextStyle(color: Colors.white),
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
