import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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

void main() => runApp(new MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

//var sobelFilterListX = [1, 0, -1, 2, 0, -2, 1, 0, -1];
var sobelFilterListX = [0, 1, 0, 1, -4, 1, 0, 1, 0];
//var sobelFilterListY = [-1, -1, -1, -1, 8, -1, -1, -1, -1];
var sobelFilterListY = [1, 2, 1, 0, 0, 0, -1, -2, -1];

// @todo next step: compare existsing with photofilter convolutions

ConvolutionKernel sobelKernelX = new ConvolutionKernel(sobelFilterListX);

ImageFilter edgeDetectX = new ImageFilter(name: "X edge detect")
  ..subFilters.add(ConvolutionSubFilter.fromKernel(sobelKernelX));

ConvolutionKernel sobelKernelY = new ConvolutionKernel(sobelFilterListY);

ImageFilter edgeDetectY = new ImageFilter(name: "Y edge detect")
  ..subFilters.add(ConvolutionSubFilter.fromKernel(sobelKernelY));

List<Filter> filters = [edgeDetectX, edgeDetectY];

//edgeDetectLR.subFilters.add(ConvolutionSubFilter.fromKernel(coloredEdgeDetectionKernel))
//new ImageFilter(name: "Colored Edge Detection")
//..subFilters
//    .add(ConvolutionSubFilter.fromKernel(coloredEdgeDetectionKernel))

//Directory tempDir = await getTemporaryDirectory();
//String tempPath = tempDir.path;

final picker = ImagePicker();

class _MyAppState extends State<MyApp> {
  String fileName;
  File imageFile;
  var ci;
  List<int> edgesY;
  List<int> edgesX;

  Directory tempDir;

  Future pickImage(context) async {
    await Permission.storage.request();
    tempDir = await getTemporaryDirectory();
    PickedFile pickedImageFile = await picker.getImage(
      source: ImageSource.gallery,
      maxHeight: 1080,
      maxWidth: 1080,
    );

    imageFile = File(pickedImageFile.path);

    print(tempDir);

    setState(() {
      imageFile = imageFile;
    });

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
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Photo Filter Example'),
      ),
      body: Center(
        child:
//      new Container(
//          child: imageFile == null
//              ? Center(
//                  child: new Text('No image selected.'),
//                )
//              : convolveAndDisplay(imageFile),
            new Column(
          children: [
            new Container(
              child: imageFile == null
                  ? Center(
                      child: new Text('No image selected.'),
                    )
                  : convolveAndDisplay(imageFile),
//                  : new Text('done'),
            ),
            new Container(
              child: ci == null
                  ? Center(
                      child: new Text('No cv made.'),
                    )
//                  : Image.memory(imageLib.encodePng(ci)),
                  : new Text('cv made.'),
//                  : Image.file(ci),
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () => pickImage(context),
        tooltip: 'Pick Image',
        child: new Icon(Icons.add_photo_alternate),
      ),
    );
  }

  void rotationTesting() {
    Matrix2D<Uint8List> m = Matrix2D.fromData(3, 2, [1, 2, 3, 4, 5, 6]);
    print(m);
    print('----');
    m.pseudoRotateRight();
    print(m);
    print('----');
    m.pseudoRotateLeft();
    m.pseudoRotateLeft();
    print(m);
    print('===');
    m.pseudoRotateRight();

    Matrix2D<Uint8List> mr = m.rotated(1);

    print(mr);
    print('----');

    var carved = mr.carveSeam([
      [0, 1],
      [1, 0],
      [2, 1]
    ]);

    print(carved.toString());
    print('----');
    print(carved.rotated(-1));
  }

  convolveAndDisplay(File imageFile) {
    // print(1.0.ceil());

    imageLib.Image image = imageLib.decodeImage(imageFile.readAsBytesSync());

    ResizeableImage resizeableImage = ResizeableImage(image);

    String pathName = tempDir.path + '/cropped.png';
    // String pathName = tempDir.path + '/cropped.png';

    Stopwatch totalStopwatch = new Stopwatch()..start();

    resizeableImage.atSize(
      Size2D(image.height-100, image.width -200),
      pathName,
      speedup: 1,
    );

    // resizeableImage.atSize(
    //   Size2D(image.height, image.width - 210),
    //   pathName,
    // );
    //
    // resizeableImage.atSize(
    //   Size2D(image.height, image.width - 190),
    //   pathName,
    // );

    print('completed in ${totalStopwatch.elapsed}');
    print('Saved to $pathName');

    // Int32List l1 = Int32List.fromList([1,2,3,4,5,6,7]);
    // Int32List l2 = Int32List.fromList([1,2,3,4,5,6,7].reversed.toList());
    // print(l1);
    // l1.setRange(1, 3, l2, 1);
    // print(l1);

    // List<List<int>> randomSeam = [];
    // for (int y = 0; y < image.height; y++) {
    //   randomSeam.add([y, randInt(0, image.width)]);
    // }
    // Matrix2D imageMatrix2d = Matrix2D.fromImage(image);
    //
    // List<Future> carvingFutures = [];
    // Matrix2D im1 = imageMatrix2d.clone();
    // Matrix2D im2 = imageMatrix2d.clone();
    // Matrix2D im3 = imageMatrix2d.clone();
    // Matrix2D im4 = imageMatrix2d.clone();
    //
    //
    // carvingFutures.add(Isolate.spawn(carveSeam, im1, randomSeam));

    // List<List<int>> randomSeam = [];
    // for (int y = 0; y < image.height; y++) {
    //   randomSeam.add([y, randInt(0, image.width)]);
    // }
    // List<List<List<int>>> matrixImage = pixelMatrixFromImage(image);
    // Matrix2D imageMatrix2d = Matrix2D.fromImage(image);
    // for (int _ = 0; _ < 10; _++) {
    //   naiveMatrixBased(matrixImage, randomSeam);
    //   imageBased(image, randomSeam);
    //   matrix2DBased(imageMatrix2d, randomSeam);
    //   print(_);
    //   if (_ % 10 == 0) {
    //     print(_);
    //   }
    // }

    // matrixToGalleryImage(pixelMatrix, pixelARGBChannelsToARGBBytes, origName);

//    List<Future<List<int>>> convolutionFutures = [];
//     List<Future<imageLib.Image>> convolutionFutures = [];
//
//     List<String> convolutedFileNames = [];
//
//     for (var filter in filters) {
//       var fileName = filter.name + '.png';
//       convolutionFutures.add(compute(applyFilterAlt, <String, dynamic>{
//         "filter": filter,
//         "image": image,
//         "filename": fileName,
//       }));
//       convolutedFileNames.add(fileName);
//     }

    // return FutureBuilder(
    //   future: Future.wait(convolutionFutures),
    //   builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
    //     switch (snapshot.connectionState) {
    //       case ConnectionState.none:
    //       case ConnectionState.active:
    //       case ConnectionState.waiting:
    //         return Center(child: CircularProgressIndicator());
    //       case ConnectionState.done:
    //         if (snapshot.hasError)
    //           return Center(child: Text('Error: ${snapshot.error}'));
    //
    //         // ResizeableImage resizeableImage = ResizeableImage(image);
    //         //
    //         // String pathName = tempDir.path + '/cropped.png';
    //         //
    //         // Stopwatch totalStopwatch = new Stopwatch()..start();
    //         //
    //         // resizeableImage.atSize(
    //         //   Size2D(image.height, image.width - 200),
    //         //   pathName,
    //         // );
    //         //
    //         // resizeableImage.atSize(
    //         //   Size2D(image.height, image.width - 210),
    //         //   pathName,
    //         // );
    //         //
    //         // resizeableImage.atSize(
    //         //   Size2D(image.height, image.width - 190),
    //         //   pathName,
    //         // );
    //         //
    //         // print('completed in ${totalStopwatch.elapsed}');
    //
    //         // matrixToGalleryImage(
    //         //     pixelMatrix, pixelARGBChannelsToARGBBytes, origName);
    //
    //         // var dirImagePath = tempDir.path + '/dirs.png';
    //         // visualizeDirs(dirs, dirImagePath);
    //
    //         return Image.file(imageFile);
    //     }
    //     return null; // unreachable
    //   },
    // );
  }

// imageLib.Image imageBased(
//   imageLib.Image imageBytes,
//   List<List<int>> randomSeam,
// ) {
//   imageLib.Image imageBytesClone = imageBytes.clone();
//   imageLib.Image newim =
//       imageBytesClone.carveSeam(randomSeam, ordered: false);
//   return newim;
// }
//
// List<List<List<int>>> naiveMatrixBased(
//   List<List<List<int>>> matrixImage,
//   List<List<int>> randomSeam,
// ) {
//   List<List<List<int>>> matrixImageCopy = matrixCopy3D(matrixImage);
//   carveSeamFromMatrix3D_(matrixImageCopy, randomSeam);
//   return matrixImageCopy;
// }
//
// Matrix2D matrix2DBased(
//   Matrix2D matrixImage,
//   List<List<int>> randomSeam,
// ) {
//   Matrix2D matrixImageCopy = matrixImage.clone();
//   matrixImageCopy.carveSeam(randomSeam);
//   return matrixImageCopy;
// }
}
