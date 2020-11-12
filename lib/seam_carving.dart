import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import "dart:async";
import "dart:isolate";

// import 'package:flutter/cupertino.dart';
import 'package:flutter_app_new/video_creation.dart';
import "package:isolate/isolate.dart";
import 'package:binary/binary.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_new/matrix.dart';
import 'package:flutter_app_new/utils.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as imageLib;
import 'package:path_provider/path_provider.dart';
import 'package:quiver/iterables.dart' show cycle, count, enumerate;
import 'package:tflite/tflite.dart';
import 'package:uuid/uuid.dart';

var uuid = Uuid();

extension SeamCarving on imageLib.Image {
  imageLib.Image carveSeam(
    List<List<int>> seam, {
    ordered: false,
  }) {
    List<int> indices =
        seam.map((coordYX) => this.index(coordYX[1], coordYX[0])).toList();

    if (!ordered) {
      indices.sort();
    }

    Uint32List newData = Uint32List(data.length - indices.length);

    int di = 0;

    for (int i = 0; i < newData.length; i++) {
      if (indices[di] == i) {
        di++;
      }

      newData[i] = this.data[i + di];
    }

    var newImage = imageLib.Image.fromBytes(width - 1, height, newData);
    return newImage;
  }

  Size2D size() {
    return Size2D(height, width);
  }

  void saveInGallery(String path) {
    save(path);
    GallerySaver.saveImage(path);
  }

  void save(String path) {
    File(path).writeAsBytesSync(imageLib.encodePng(this, level: 0));
  }

// imageLib.Image fromMatrix(Matrix2D matrix) {
//   return matrix.to w
// }
}

enum deltaAxis { x, y }

class ResizeableImage {
  // imageLib.Image imageBytes;
  int height;
  int width;
  Size2D originalSize;
  MatrixCache imageMatrixCache;
  MatrixCache energyMatrixCache;
  MatrixCache minEnergyMatrixCache;
  MatrixCache directionMatrixCache;
  int speedup;

  bool initialized = false;
  bool beingProtection = false;

  String imagePath;

  imageLib.Image image;
  Directory tempDir;

  bool debug;
  bool video;

  int numSeamsAltered;
  int numSeamsToBeAltered;
  int progressInd;
  int numRecordedSteps;

  bool updatedProgressImage;

  Function setProgress;

  String currentProgressImagePath;

  SendPort progressSendPort;

  ResizeableImage(
    File imageFile, {
    this.beingProtection: true,
    this.speedup: 1,
    this.debug: false,
    this.video: false,
    this.numRecordedSteps: 75,
  }) {
    imagePath = imageFile.path;
    image = imageLib.decodeImage(imageFile.readAsBytesSync());
    width = image.width;
    height = image.height;
    originalSize = image.size();
  }

  Future<void> init(Directory tempDir) async {
    if (initialized) {
      return;
    }

    initialized = true;

    this.tempDir = tempDir;

    Stopwatch stopwatch = new Stopwatch()..start();

    Matrix2D<Uint32List> imageMatrix = Matrix2D.fromImage(image);
    assert(imageMatrix.length == width * height);

    if (debug) {
      saveImageMatrix(
        imageMatrix,
        tempDir.path + '/original.png',
        saveToGallery: true,
      );
      // saveImageMatrix(imageMatrix, tempDir.path + '/original.png')
    }
    imageMatrixCache = MatrixCache(matrix: imageMatrix);

    Matrix2D<Uint8List> energyMatrix = forwardEnergy(image);

    if (beingProtection) {
      await updateEnergyMatrixWithBeingDetection_(energyMatrix);
    }

    var vals = minEnergy(energyMatrix);
    var minEnergyMatrix = vals[0];
    var directionMatrix = vals[1];

    energyMatrixCache = MatrixCache(matrix: energyMatrix);
    minEnergyMatrixCache = MatrixCache(matrix: minEnergyMatrix);
    directionMatrixCache = MatrixCache(matrix: directionMatrix);

    debugPrint('initialized in ${stopwatch.elapsed}');
  }

  // ignore: non_constant_identifier_names
  Future updateEnergyMatrixWithBeingDetection_(
    Matrix2D<Uint8List> energyMatrix,
  ) async {
    assert(imagePath != null);

    var result = await Tflite.runSegmentationOnImage(
      path: imagePath,
      // labelColors: [...], // defaults to https://github.com/shaqian/flutter_tflite/blob/master/lib/tflite.dart#L219
      outputType: "bytes",
    );

    String segmentationPath = tempDir.path + '/segmentation.png';

    // saveImageFromData(
    //   257,
    //   257,
    //   Uint8List.fromList(result).buffer.asUint32List(),
    //   segmentationPath,
    //   saveToGallery: true,
    // );

    // await Tflite.close();

    // File segmentationFile = File(segmentationPath);

    // imageLib.Image segmentationImage =
    //     imageLib.decodeImage(await segmentationFile.readAsBytes());

    imageLib.Image segmentationImage = imageLib.Image.fromBytes(
      257,
      257,
      Uint8List.fromList(result).buffer.asUint32List(),
    );

    if (debug) {
      segmentationImage.saveInGallery(segmentationPath);
    }

    imageLib.Image resizedSegmentationImage = imageLib.copyResize(
      segmentationImage,
      width: width,
      height: height,
      interpolation: imageLib.Interpolation.nearest,
    );

    Matrix2D<Uint32List> segmentationMatrix =
        Matrix2D.fromImage(resizedSegmentationImage);

    Set<int> beingValues = {
      // for some reason the result is in abgr
      // Color.fromARGB(255, 192, 128, 128).value, // person
      // Color.fromARGB(255, 64, 0, 128).value, // dog
      // Color.fromARGB(255, 64, 0, 0).value, // cat
      Color.fromARGB(255, 128, 128, 192).value, // person
      Color.fromARGB(255, 128, 0, 64).value, // dog
      Color.fromARGB(255, 0, 0, 64).value, // cat
    };

    // int c = 0;

    int maxEnergy = energyMatrix.max();
    // print(maxEnergy);

    for (int y = 0; y < segmentationMatrix.height; y++) {
      for (int x = 0; x < segmentationMatrix.width; x++) {
        if (beingValues.contains(segmentationMatrix.getCell(x, y))) {
          energyMatrix.setCell(x, y, maxEnergy);
          // c++;
        }
      }
    }

    // String updatedEnergyPath = tempDir.path + '/updated_energy.png';
    // saveEnergyMatrixImageToGallery(energyMatrix, updatedEnergyPath);

    // return energyMatrix;
  }

  Future<String> atRatio(
      double widthToHeightRatio, double squeezeToStretchRatio) async {
    // double targetWPH = width / height;

    // assert(widthToHeightRatio >= 0 && widthToHeightRatio <= 1);
    assert(widthToHeightRatio >= 0);

    double currentWTH = this.width / this.height;

    if (widthToHeightRatio > currentWTH) {
      print('flipping carvingDegree');
      squeezeToStretchRatio = 1 - squeezeToStretchRatio;
    }

    https: //www.wolframalpha.com/input/?i=x+%3D+%28e+%2F+j%29+*+%28h+%2B+x%2Fs%29+-+w+solve+for+x
    // int widthDelta = ((height * carvingDegree * this.width -
    //             width * carvingDegree * this.height) /
    //         (width - height * carvingDegree))
    //     .round();
    //https://www.wolframalpha.com/input/?i=x+%3D+((w+%2B+x)+%2F+(h+%2B+(x+%2F+s)))+*+(h+%2B+x%2Fs)+-+w+solve+for+x

    // https://www.wolframalpha.com/input/?i=x+%3D+((w+%2B+x)+%2F+(h+%2B+(x+%2F+s)))+*+(h+%2B+x%2Fs)+-+w+solve+for+x

    double delta = (height * widthToHeightRatio - width) /
        (-widthToHeightRatio * squeezeToStretchRatio +
            widthToHeightRatio +
            squeezeToStretchRatio);

    // https://www.wolframalpha.com/input/?i=x+%3D+((w+%2B+x)+%2F+(h+%2B+(x+%2F+s)))+*+(h+%2B+x%2Fs)+-+w+solve+for+x
    // double delta = (height * widthToHeightRatio - width) /
    //     (widthToHeightRatio * (carvingDegree - 1) + carvingDegree);

    int widthDelta = (squeezeToStretchRatio * delta).round();
    int heightDelta = -1 * ((1 - squeezeToStretchRatio) * delta).round();

    // int widthDelta = ().round();

    // int heightDelta = (widthDelta / carvingDegree).round();

    Size2D sizeDelta = Size2D(heightDelta, widthDelta);

    Size2D newSize = sizeDelta + Size2D(this.height, this.width);
    // print(sizeDelta);
    // print(newSize);

    return atSize(newSize);
  }

  Future<String> atSize(Size2D size, {int speedup: 1}) async {
    // if (!initialized) {
    //   await init();
    // }

    Stopwatch stopwatch = new Stopwatch()..start();

    Size2D deltaSize = size - originalSize;

    numSeamsToBeAltered = deltaSize.total();
    numSeamsAltered = 0;
    progressInd = 0;
    currentProgressImagePath = null;

    print("total seams to be altered: $numSeamsToBeAltered");

    Size2D smallerSize = Size2D(
      originalSize.height + min(deltaSize.height, 0),
      width + min(deltaSize.width, 0),
    );

    int totalDeltaToBeShrunk = originalSize.totalDelta(smallerSize);

    Size2D biggerSize = Size2D(
      originalSize.height + deltaSize.height,
      width + deltaSize.width,
    );

    int totalDeltaToBeGrown = smallerSize.totalDelta(biggerSize);

    // print(totalDeltaToBeShrunk);
    // print(deltaSize);
    // print(smallerSize);
    // print(biggerSize);
    // print(totalDeltaToBeGrown);

    var vars = await _atSmallerSize(smallerSize);
    Matrix2D<Uint32List> imageMatrix = vars[0];
    Matrix2D<Uint8List> energyMatrix = vars[1];

    // Matrix2D<Uint32List> imageMatrix = await _atSmallerSize(smallerSize);

    if (biggerSize != smallerSize) {
      imageMatrix = await _atBiggerSize(imageMatrix, energyMatrix, biggerSize);
    }

    var resizedImagePath = tempDir.path + '/${uuid.v1()}.png';
    saveImageMatrix(
      imageMatrix,
      resizedImagePath,
      saveToGallery: false,
    );

    debugPrint('Size change completed in ${stopwatch.elapsed}');

    if (video) {
      await createVideo();
    }

    // File(tempDir.path + '/progress$progressInd.png').deleteSync();

    return resizedImagePath;
  }

  Future<Matrix2D<Uint32List>> _atBiggerSize(
    Matrix2D<Uint32List> imageMatrix,
    Matrix2D<Uint8List> energyMatrix,
    Size2D biggerSize,
  ) async {
    // Matrix2D<Uint8List> energyMatrix = Matrix2D<Uint8List>.fromData(
    //   _energyMatrix.width,
    //   _energyMatrix.height,
    //   _energyMatrix.data,
    // );

    // for (var val in _energyMatrix.data) {
    //   assert (val <= 255);
    // }

    Size2D sizeDelta = biggerSize - imageMatrix.size();

    Stopwatch stopwatch = new Stopwatch()..start();

    // Matrix2D<Uint8List> imageBrightnessMatrix;

    // Matrix2D<Uint8List> energyMatrix;

    for (var axis in [deltaAxis.x, deltaAxis.y]) {
      int delta;

      if (axis == deltaAxis.x) {
        delta = sizeDelta.width;
        if (delta == 0) {
          print('skipping x axis');
          continue;
        }
      } else {
        // deltaAxis.y
        delta = sizeDelta.height;
        if (delta == 0) {
          print('skipping y axis');
          continue;
        }

        imageMatrix = imageMatrix.rotated(1);
        energyMatrix = energyMatrix.rotated(1);
        // energyMatrix = imageMatrix.getForwardEnergy();
      }

      // energyMatrix = imageMatrix.getForwardEnergy();

      debugPrint('growing $delta seams in axis $axis');

      // var vars = minEnergy(energyMatrix);
      Matrix2D<Uint32List> minEnergyMatrix;
      // minEnergyMatrix = vars[0];
      Matrix2D<Int8List> directionMatrix;
      // directionMatrix = vars[1];

      // imageBrightnessMatrix = pixelBrightnessMatrixFromImageMatrix(imageMatrix);

      // saveEnergyMatrixImageToGallery(
      //     imageBrightnessMatrix, tempDir.path + '/brightness.png');

      List<List<List<int>>> lastSeams;

      for (int i = 0; i < (delta / speedup).ceil(); i++) {
        int numSeams = min(speedup, delta - i * speedup);

        if (i == 0) {
          // if (true) {
          var vals = minEnergy(energyMatrix);
          minEnergyMatrix = vals[0];
          directionMatrix = vals[1];
        } else {
          recalculateMinEnergy_(
            energyMatrix,
            minEnergyMatrix,
            directionMatrix,
            lastSeams,
          );
        }

        lastSeams = [];

        for (int _ = 0; _ < numSeams; _++) {
          List<List<int>> seam = getMinEnergyVerticalSeam(
            directionMatrix,
            minEnergyMatrix,
            correctEdges: speedup != 1,
          );

          var seams = [seam];

          // int penalty = energyMatrix.seamsMax(seams);
          // int penalty = energyMatrix.seamsMin(seams);
          // int penalty = energyMatrix.seamsMean(seams);
          // int penalty =
          //     (energyMatrix.seamsMean(seams) + energyMatrix.seamsMax(seams)) ~/
          //         2;
          // int penalty = 255;
          int penalty = 10;
          // print(penalty);

          penalty = max(penalty, 1);

          var vars = imageMatrix.withExpandedSeams(seams);
          imageMatrix = vars[0];
          List<int> indicesToFill = vars[1];
          fillImageMatrixIndicesByInterpolation(imageMatrix, indicesToFill);

          updateProgress(imageMatrix, axis);

          energyMatrix = energyMatrix.withExpandedAndInterpolatedSeams(seams);

          energyMatrix.increaseIndicesByValue(
            energyMatrix.indicesCenterLeftAndPerhapsRightOfIndices(
                indicesToFill,
                right: false),
            penalty,
            255,
          );

          minEnergyMatrix = minEnergyMatrix.withExpandedSeams(seams)[0];
          directionMatrix = directionMatrix.withExpandedSeams(seams)[0];
          lastSeams.addAll(seams);
        }

        if (i % 10 == 0) {
          // saveEnergyMatrixImageToGallery(
          //     energyMatrix, tempDir.path + '/energy $i.png');
          print(i);
        }
      }

      if (axis == deltaAxis.y) {
        imageMatrix = imageMatrix.rotated(-1);
        energyMatrix = energyMatrix.rotated(-1);
      }
    }

    if (debug) {
      // saveEnergyMatrixImageToGallery(
      //     imageBrightnessMatrix, tempDir.path + '/brightness post.png');

      saveEnergyMatrixImageToGallery(
          energyMatrix, tempDir.path + '/energy post.png');
    }

    debugPrint('Seam expansion completed in ${stopwatch.elapsed}');

    return imageMatrix;
  }

  Future<List> _atSmallerSize(Size2D smallerSize) async {
    assert(smallerSize.height <= originalSize.height &&
        smallerSize.width <= originalSize.width);

    Size2D closestSize = imageMatrixCache.closestBiggerEqualSize(smallerSize);
    debugPrint('closest size to $smallerSize was $closestSize');

    Matrix2D<Uint32List> imageMatrix =
        this.imageMatrixCache[closestSize].clone();
    Matrix2D<Uint8List> energyMatrix =
        this.energyMatrixCache[closestSize].clone();
    Matrix2D<Uint32List> minEnergyMatrix =
        this.minEnergyMatrixCache[closestSize].clone();
    Matrix2D<Int8List> directionMatrix =
        this.directionMatrixCache[closestSize].clone();

    if (debug) {
      saveEnergyMatrixImageToGallery(
          energyMatrix, tempDir.path + '/energy pre shrink.png');
    }

    var vals;
    List<List<int>> seam;
    List<List<List<int>>> lastSeams;

    Size2D sizeDelta = closestSize - smallerSize;

    Stopwatch loopStopwatch = new Stopwatch()..start();

    for (var axis in [deltaAxis.x, deltaAxis.y]) {
      int numCarved = 0;

      int delta;

      if (axis == deltaAxis.x) {
        delta = sizeDelta.width;
        if (delta == 0) {
          print('skipping x axis');
          continue;
        }
      } else {
        // deltaAxis.y
        delta = sizeDelta.height;
        if (delta == 0) {
          print('skipping y axis');
          continue;
        }

        imageMatrix = imageMatrix.rotated(1);
        energyMatrix = energyMatrix.rotated(1);
        minEnergyMatrix = null; // ?
        directionMatrix = null;
      }
      // Matrix2D<Uint8List> energyMatrix = imageMatrix.getForwardEnergy();

      debugPrint('carving $delta seams in axis $axis');

      for (int i = 0; i < (delta / speedup).ceil(); i++) {
        int numCarvings = min(speedup, delta - i * speedup);

        assert(numCarvings > 0);
        // print(numCarvings);

        if (i == 0) {
          vals = minEnergy(energyMatrix);
          minEnergyMatrix = vals[0];
          directionMatrix = vals[1];
        } else {
          recalculateMinEnergy_(
            energyMatrix,
            minEnergyMatrix,
            directionMatrix,
            lastSeams,
          );

          // recalculateMinEnergyQueue_(
          //   energyMatrix,
          //   minEnergyMatrix,
          //   directionMatrix,
          //   lastSeams,
          // );
        }

        lastSeams = [];

        for (int _ = 0; _ < numCarvings; _++) {
          // @todo: see if using seams (plural) increses speed
          seam = getMinEnergyVerticalSeam(
            directionMatrix,
            minEnergyMatrix,
            correctEdges: speedup != 1,
          );

          // var c1 = SingleResponseChannel();
          // var c1 = SendPort();
          // Isolate.spawn(carveIsolateHelper, [imageMatrix, seam]);
          // imageMatrix = await c1;

          imageMatrix = imageMatrix.withCarvedSeam(seam, ordered: true);
          energyMatrix = energyMatrix.withCarvedSeam(seam, ordered: true);
          minEnergyMatrix = minEnergyMatrix.withCarvedSeam(seam, ordered: true);
          directionMatrix = directionMatrix.withCarvedSeam(seam, ordered: true);

          updateProgress(imageMatrix, axis);

          lastSeams.add(seam);
          numCarved++;
        }

        Size2D newSize = energyMatrix.size();
        if (axis == deltaAxis.y) {
          newSize = newSize.inverted();
        }

        if (energyMatrixCache.sizeShouldBeAdded(newSize)) {
          debugPrint('$newSize is being added to cache');

          int rot = axis == deltaAxis.x ? 0 : -1;

          imageMatrixCache.add(imageMatrix.rotated(rot), check: false);
          energyMatrixCache.add(energyMatrix.rotated(rot), check: false);
          minEnergyMatrixCache.add(minEnergyMatrix.rotated(rot), check: false);
          directionMatrixCache.add(directionMatrix.rotated(rot), check: false);
        }

        // debugPrint(i.toString());
      }

      if (axis == deltaAxis.y) {
        imageMatrix = imageMatrix.rotated(-1);
        energyMatrix = energyMatrix.rotated(-1);
        // minEnergyMatrix = minEnergyMatrix.rotated(-1);
        // directionMatrix = directionMatrix.rotated(-1);
      }

      debugPrint('cropped $axis in ${loopStopwatch.elapsed}');
      debugPrint('resulting matrix dimensions are ${imageMatrix.size()}');
      debugPrint('');
    }

    return [imageMatrix, energyMatrix];
  }

  void saveProgress(Matrix2D<Uint32List> _imageMatrix, deltaAxis axis) {
    int delta = numSeamsToBeAltered ~/ numRecordedSteps;

    if (numSeamsAltered == 0 ||
        numSeamsAltered == numSeamsToBeAltered ||
        numSeamsAltered % delta == 0) {
      // Matrix2D<Uint32List> imageMatrix;
      // if (axis == deltaAxis.y) {
      //   imageMatrix = _imageMatrix.rotated(-1);
      // } else {
      //   imageMatrix = _imageMatrix;
      // }

      updatedProgressImage = true;

      // saveImageFromImageMatrix(imageMatrix, path)

      // if (!video && progressInd != 0) {
      //   File(tempDir.path + '/progress${progressInd - 1}.png').deleteSync();
      // }

      var path = tempDir.path + '/progress$progressInd.png';

      // var file = File(path);
      // if (file.existsSync()) {
      //   // print(path);
      //   file.deleteSync();
      // } else {
      //   print("$path doesn't exist");
      // }

      currentProgressImagePath = path;

      // print(currentProgressImagePath);

      // saveImageMatrix(
      //   imageMatrix,
      //   currentProgressImagePath,
      //   saveToGallery: false,
      // );

      progressInd++;

      // print('saved to ${tempDir.path + '/progress$progressInd.png'}');
      // print(Directory(tempDir.path).listSync(recursive: true));
    } else {
      updatedProgressImage = false;
    }
  }

  void updateProgress(imageMatrix, axis, {int n = 1}) {
    numSeamsAltered += n;
    saveProgress(imageMatrix, axis);

    if (progressSendPort != null) {
      // print('sending');
      double progress = numSeamsAltered / numSeamsToBeAltered;

      // decodeImageFromPixels(
      //     imageMatrix.data.buffer.asUint8List(0, imageMatrix.data.length * 4),
      //     imageMatrix.width,
      //     imageMatrix.height,
      //     PixelFormat.rgba8888,
      //     (Image image) => {
      //           progressSendPort.send({
      //             'progress': progress,
      //             'currentProgressImagePath': currentProgressImagePath,
      //             'currentProgressImage': image,
      //             'done': numSeamsAltered == numSeamsToBeAltered,
      //           })
      //         });

      progressSendPort.send({
        'progress': progress,
        'currentProgressImagePath': currentProgressImagePath,
        'currentProgressImageMatrix': updatedProgressImage
            ? axis == deltaAxis.y
                ? imageMatrix.rotated(-1)
                : imageMatrix
            : null,
        'updatedProgressImage': updatedProgressImage,
        // 'currentProgressImageData': {
        //   'data': imageMatrix.data.buffer
        //       .asUint8List(0, imageMatrix.data.length * 4),
        //   'width': imageMatrix.width,
        //   'height': imageMatrix.height,
        //
        // },
        'done': numSeamsAltered == numSeamsToBeAltered,
      });
    }
    // currentProgressImagePath
  }

  Future<void> createVideo({int duration: 2}) async {
    // var listSync = Directory(tempDir.path).listSync();
    // print(listSync);
    // return;

    Stopwatch stopwatch = new Stopwatch()..start();

    await videoFromImageFolder(
      tempDir.path,
      'progress',
      '.png',
      tempDir.path + '/progressVideo.mp4',
      fps: numRecordedSteps / duration,
    );

    debugPrint('video created in ${stopwatch.elapsed}');
  }
}

void saveImageMatrix(
  Matrix2D<Uint32List> imageMatrix,
  String path, {
  saveToGallery: false,
}) {
  Uint8List data =
      imageMatrix.data.buffer.asUint8List(0, imageMatrix.data.length * 4);

  imageLib.Image image =
      imageLib.Image.fromBytes(imageMatrix.width, imageMatrix.height, data);

  if (saveToGallery) {
    image.saveInGallery(path);
  } else {
    image.save(path);
  }
}

void fillImageMatrixIndicesByInterpolation(
    Matrix2D<Uint32List> imageMatrix, List<int> indicesToFill) {
  // imageLib.Image image;
  // image.getPixelLinear(fx, fy)

  // imageMatrix.xyFromIndex();

  int left;
  int right;
  int steps;

  List<int> curr = [];
  List<int> fillVals;

  for (int ii = 0; ii < indicesToFill.length; ii++) {
    int index = indicesToFill[ii];
    var vars = imageMatrix.xyFromIndex(index);
    int x = vars[0];
    // int y = vars[1];

    if ((curr.length == 0 || index == curr[curr.length - 1] + 1 && x != 0)) {
      curr.add(index);
    } else {
      left = curr[0];
      right = curr[curr.length - 1];
      steps = curr.length;

      if (imageMatrix.xyFromIndex(left)[0] == 0) {
        // not lefter pixels
        int fillVal = imageMatrix.data[right + 1];
        fillVals = cycle([fillVal]).take(steps).toList();
      } else if (imageMatrix.xyFromIndex(right)[0] == imageMatrix.width - 1) {
        // no pixels to right
        int fillVal = imageMatrix.data[left - 1];
        fillVals = cycle([fillVal]).take(steps).toList();
      } else {
        List<int> leftARGB = pixelDataToARGB(imageMatrix.data[left - 1]);
        List<int> rightARGB = pixelDataToARGB(imageMatrix.data[right + 1]);

        List<int> deltasARGB = count()
            .take(4)
            .map((i) => ((rightARGB[i] - leftARGB[i]) / (steps + 1)).round())
            .toList();

        List<List<int>> interpolates =
            List.generate(steps, (index) => List.generate(4, (index) => null));

        count().take(steps).forEach((step) {
          count().take(4).forEach((channelInd) {
            interpolates[step][channelInd] =
                leftARGB[channelInd] + (step + 1) * deltasARGB[channelInd];
          });
        });

        fillVals = interpolates.map(pixelARGBChannelsToARGBBytes).toList();
      }

      enumerate(curr).forEach((element) {
        imageMatrix.data[element.value] = fillVals[element.index];
        // imageMatrix.data[element.value] = 255;
      });

      curr = [index];
    }
  }
}

class BottomRightPriorityCoordinates extends Equatable implements Comparable {
  final int y;
  final int x;

  const BottomRightPriorityCoordinates(this.y, this.x);

  @override
  int compareTo(other) {
    if (this.y == other.y) {
      return this.x.compareTo(other.x); // smaller x (closer to left) preferable
    } else {
      return -1 *
          this.y.compareTo(other.y); // bigger y (closer to bottom) preferable
    }
  }

  @override
  List<Object> get props => [y, x];
}

int ARGBToBrightness(
  List<int> argb,
) {
  // assert (argb[0] == 255);
  return imageLib.getLuminanceRgb(argb[1], argb[2], argb[3]);
}

Matrix2D<Uint8List> pixelBrightnessMatrixFromImage(
  imageLib.Image image,
) {
  Uint8List data = Uint8List(image.length);

  var brightnesses = image
      .getBytes()
      .buffer
      .asInt32List()
      .map((v) => ARGBToBrightness(pixelDataToARGB(v)));

  data.setAll(0, brightnesses);

  // assert(data.length == brightnesses.toList().length);

  return Matrix2D<Uint8List>.fromData(image.width, image.height, data);
}

Matrix2D<Uint8List> pixelBrightnessMatrixFromImageMatrix(
  Matrix2D matrix,
) =>
    Matrix2D.fromData(
        matrix.width,
        matrix.height,
        matrix
            .getData()
            .map((v) => ARGBToBrightness(pixelDataToARGB(v)))
            .toList());

List<List<int>> getMinEnergyVerticalSeam(
  Matrix2D dirs,
  Matrix2D minEnergyMatrix, {
  bool correctEdges: false,
}) {
  List<List<int>> seam = new List(dirs.height);

  int x = argmin(minEnergyMatrix.getRow(0));

  for (int y = 0; y < dirs.height; y++) {
    seam[y] = [y, x];
    x += dirs.getCell(x, y);
    if (correctEdges) {
      x = x.clamp(0, dirs.width - 1);
    }

    try {
      assert(x >= 0);
    } catch (e) {
      print([x, dirs.width]);
      rethrow;
    }
    assert(x < dirs.width);
  }

  return seam;
}

List<List<List<int>>> getMinEnergyVerticalSeamsPercentile(
  Matrix2D dirs,
  Matrix2D minEnergyMatrix,
  double percentile, {
  bool correctEdges: false,
}) {
  int numSeams = (dirs.width * percentile).round();

  return getMinEnergyVerticalSeams(
    dirs,
    minEnergyMatrix,
    numSeams,
    correctEdges: correctEdges,
  );
}

List<List<List<int>>> getMinEnergyVerticalSeams(
  Matrix2D dirs,
  Matrix2D minEnergyMatrix,
  int numSeams, {
  bool correctEdges: false,
}) {
  assert(numSeams > 0);

  List<List<List<int>>> seams = List.generate(
      numSeams, (index) => List.generate(dirs.height, (index) => null));

  int i = 0;

  for (int x in argmins(minEnergyMatrix.getRow(0), numSeams)) {
    for (int y = 0; y < dirs.height; y++) {
      seams[i][y] = [y, x];
      x += dirs.getCell(x, y);
      if (correctEdges) {
        x = x.clamp(0, dirs.width - 1);
      }

      assert(x >= 0);
      assert(x < dirs.width);
    }
    i++;
  }
  return seams;
}

void paintSeam_(
  imageLib.Image image,
  List<List<int>> seam,
) {
  for (List<int> seamYX in seam) {
    image.setPixelRgba(seamYX[1], seamYX[0], 255, 0, 0);
  }
}

List minEnergy(
  Matrix2D energyMatrix,
) {
  int height = energyMatrix.height;
  int width = energyMatrix.width;

  Matrix2D<Uint32List> leastE = Matrix2D(width, height, 0);
  Matrix2D<Int8List> dirs = Matrix2D(width, height, 0);

  for (int i = 0; i < width; i++) {
    leastE.setCell(i, height - 1, energyMatrix.getCell(i, height - 1));
  }

  for (int y = height - 2; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      var j1 = max(0, x - 1);
      var j2 = min(width - 1, x + 1);

      // var options = leastE.getRow(y + 1).sublist(j1, j2 + 1);
      var options = leastE.rowSublist(y + 1, j1, j2 + 1);

      assert(options.length <= 3);

      var ind = argminLe3(options);
      var e = options[ind];
      leastE.setCell(x, y, energyMatrix.getCell(x, y) + e);
      dirs.setCell(x, y, [-1, 0, 1][ind + boolToInt(x == 0)]);
    }
  }
  return [leastE, dirs];
}

recalculateMinEnergyQueue_(
  Matrix2D energyMatrix,
  Matrix2D minEnergyMatrix,
  Matrix2D dirs,
  List<List<List<int>>> lastSeams,
) {
  int height = energyMatrix.height;
  int width = energyMatrix.width;

  HeapPriorityQueue<BottomRightPriorityCoordinates> toBeUpdated =
      new HeapPriorityQueue();

  SplayTreeSet<BottomRightPriorityCoordinates> updated = SplayTreeSet();

  int c = 0;

  for (var seam in lastSeams) {
    for (List<int> seamYX in seam.reversed.skip(1)) {
      var y = seamYX[0];
      var x = seamYX[1];

      for (int dx = -1; dx <= 1; dx++) {
        var xp = x + dx;
        if (xp >= 0 && xp < width) {
          toBeUpdated.add(new BottomRightPriorityCoordinates(y, xp));
        }
      }
    }
  }
//  for (int x = seamEndXCoord - 1; x <= seamEndXCoord + 1; x++) {
//    toBeUpdated.add(new YPriorityCoordinates(height -2, x));
//  }

  while (toBeUpdated.isNotEmpty) {
    BottomRightPriorityCoordinates coords = toBeUpdated.removeFirst();
    if (updated.contains(coords)) {
      continue;
    }

    int y = coords.y;
    int x = coords.x;

    updated.add(coords);

    var leftBound = max(0, x - 1);
    var rightBound = min(width - 1, x + 1);

    var unpackables = minEnergyMatrix.argminAndValminOfRowSublist(
        y + 1, leftBound, rightBound + 1);
    var ind = unpackables[0];
    var e = unpackables[1];

    int newDir = [-1, 0, 1][ind + boolToInt(x == 0)];

    var newMinEnergy = energyMatrix.getCell(x, y) + e;

    if (minEnergyMatrix.getCell(x, y) != newMinEnergy ||
        dirs.getCell(x, y) != newDir) {
      minEnergyMatrix.setCell(x, y, newMinEnergy);
      dirs.setCell(x, y, newDir);

      c++;

      if (y == 0) {
        continue;
      }

      for (int dx = -1; dx <= 1; dx++) {
        var newX = x + dx;
        var newY = y - 1;
        if (newX >= 0 && newX < width) {
          var newCoords = BottomRightPriorityCoordinates(newY, newX);
          toBeUpdated.add(newCoords);
        }
      }
    }
  }
  print(c);
}

// ignore: non_constant_identifier_names
void recalculateMinEnergy_(
  Matrix2D energyMatrix,
  Matrix2D minEnergyMatrix,
  Matrix2D dirs,
  List<List<List<int>>> removedSeams,
) {
  int height = minEnergyMatrix.height;
  int width = minEnergyMatrix.width;

  int leftMostSeamBottomX = width;
  int rightMostSeamBottomX = -1;

  Matrix2D<Uint8List> updateMatrix = Matrix2D(width, height);

  for (var seam in removedSeams) {
    bool isLastInd = true;
    for (List<int> seamYX in seam.reversed) {
      int y = seamYX[0];
      int x = seamYX[1];

      if (isLastInd) {
        isLastInd = false;
        leftMostSeamBottomX = min(leftMostSeamBottomX, x);
        rightMostSeamBottomX = max(rightMostSeamBottomX, x);
        continue;
      }

      for (int dx = -1; dx <= 1; dx++) {
        var xp = x + dx;
        if (xp >= 0 && xp < width) {
          updateMatrix.setCell(xp, y, 1);
        }
      }
    }
  }

  int i = 0;

  int lastLeftMostUpdatedCellX;
  int lastRightMostUpdatedCellX;

  for (int y = height - 2; y >= 0; y--) {
    i++;

    lastLeftMostUpdatedCellX = width;
    lastRightMostUpdatedCellX = -1;

    for (int x = leftMostSeamBottomX - i; x <= rightMostSeamBottomX + i; x++) {
      if (x < 0 || x >= width) {
        continue;
      }
      var cell = updateMatrix.getCell(x, y);
      if (cell == null || cell == 0) {
        continue;
      }

      var leftBound = max(0, x - 1);
      var rightBound = min(width - 1, x + 1);

      var unpackables = minEnergyMatrix.argminAndValminOfRowSublist(
        y + 1,
        leftBound,
        rightBound + 1,
      );
      var ind = unpackables[0];
      var e = unpackables[1];

      int newDir = [-1, 0, 1][ind + boolToInt(x == 0)];

      var newMinEnergy = energyMatrix.getCell(x, y) + e;

      if (minEnergyMatrix.getCell(x, y) != newMinEnergy ||
          dirs.getCell(x, y) != newDir) {
        minEnergyMatrix.setCell(x, y, newMinEnergy);
        dirs.setCell(x, y, newDir);

        lastLeftMostUpdatedCellX = min(lastLeftMostUpdatedCellX, x);
        lastRightMostUpdatedCellX = max(lastRightMostUpdatedCellX, x);

        if (y == 0) {
          continue;
        }

        for (int dx = -1; dx <= 1; dx++) {
          var newX = x + dx;
          var newY = y - 1;
          if (newX >= 0 && newX < width) {
            updateMatrix.setCell(newX, newY, 1);
          }
        }
      }
    }
  }
  // print(c);
}

// ignore: non_constant_identifier_names
void recalculateMinEnergy_Experimental(
  Matrix2D energyMatrix,
  Matrix2D minEnergyMatrix,
  Matrix2D dirs,
  List<List<List<int>>> removedSeams,
) {
  int height = minEnergyMatrix.height;
  int width = minEnergyMatrix.width;

  int leftMostSeamBottomX = width;
  int rightMostSeamBottomX = -1;

  Matrix2D<Uint8List> updateMatrix = Matrix2D(width, height);

  int c = 0;

  for (var seam in removedSeams) {
    bool isLastInd = true;
    for (List<int> seamYX in seam.reversed) {
      int y = seamYX[0];
      int x = seamYX[1];

      if (isLastInd) {
        isLastInd = false;
        leftMostSeamBottomX = min(leftMostSeamBottomX, x);
        rightMostSeamBottomX = max(rightMostSeamBottomX, x);
        continue;
      }

      for (int dx = -1; dx <= 1; dx++) {
        var xp = x + dx;
        if (xp >= 0 && xp < width) {
          updateMatrix.setCell(xp, y, 1);
        }
      }
    }
  }

  int i = 0;

  int leftMostUpdatedCellX;
  int rightMostUpdatedCellX;

  int lastLeftMostUpdatedCellX;
  int lastRightMostUpdatedCellX;

  for (int y = height - 2; y >= 0; y--) {
    i++;
    // print(i);

    if (y == height - 2) {
      leftMostUpdatedCellX = leftMostSeamBottomX;
      rightMostUpdatedCellX = rightMostSeamBottomX;
    } else {
      leftMostUpdatedCellX = lastLeftMostUpdatedCellX;
      rightMostUpdatedCellX = lastRightMostUpdatedCellX;
    }

    lastLeftMostUpdatedCellX = width;
    lastRightMostUpdatedCellX = -1;

    // for (int x = 0; x < width; x++) {
    for (int x = leftMostSeamBottomX - i; x <= rightMostSeamBottomX + i; x++) {
      // for (int x = leftMostUpdatedCellX - 1;
      //     x <= rightMostUpdatedCellX + 1;
      //     x++) {

      // print([leftMostUpdatedCellX, rightMostUpdatedCellX]);

      if (x < 0 || x >= width) {
        continue;
      }
      var cell = updateMatrix.getCell(x, y);
      if (cell == null || cell == 0) {
        continue;
      }

      var leftBound = max(0, x - 1);
      var rightBound = min(width - 1, x + 1);

      var unpackables = minEnergyMatrix.argminAndValminOfRowSublist(
        y + 1,
        leftBound,
        rightBound + 1,
      );
      var ind = unpackables[0];
      var e = unpackables[1];

      int newDir = [-1, 0, 1][ind + boolToInt(x == 0)];

      var newMinEnergy = energyMatrix.getCell(x, y) + e;

      if (minEnergyMatrix.getCell(x, y) != newMinEnergy ||
          dirs.getCell(x, y) != newDir) {
        c++;

        minEnergyMatrix.setCell(x, y, newMinEnergy);
        dirs.setCell(x, y, newDir);

        lastLeftMostUpdatedCellX = min(lastLeftMostUpdatedCellX, x);
        lastRightMostUpdatedCellX = max(lastRightMostUpdatedCellX, x);

        if (y == 0) {
          continue;
        }

        for (int dx = -1; dx <= 1; dx++) {
          var newX = x + dx;
          var newY = y - 1;
          if (newX >= 0 && newX < width) {
            updateMatrix.setCell(newX, newY, 1);
          }
        }
      }
    }
  }
  // print(c);
}

Matrix2D<Uint8List> forwardEnergy(
  imageLib.Image image, [
  saveDir,
]) {
  // https://nbviewer.jupyter.org/github/axu2/improved-seam-carving/blob/master/Improved%20Seam%20Carving.ipynb
  return pixelBrightnessMatrixFromImage(image).getForwardEnergy();
  // return pixelBrightnessMatrixFromImage(image).getForwardEnergyVertical();
  return pixelBrightnessMatrixFromImage(image)
      .rotated(1)
      .getForwardEnergyVertical()
      .rotated(-1);
}

int pixelBrightnessToARGBBytes(
  int brightness,
) {
  //todo: bitshifting
  String bitString = '';

  bitString += 255.toRadixString(2).padLeft(8, '0');
  bitString += brightness.toRadixString(2).padLeft(8, '0') * 3;

  return bitsToInt(bitString);
}

int bitsToInt(
  String bitString,
) => //todo: bitshifting
    int.parse(int.parse(bitString, radix: 2).toRadixString(10));

int pixelARGBChannelsToARGBBytes(
  List<int> channels,
) {
  // int argbBytes = 0;
  //
  // for (int i = 0; i < 4; i++) {
  //   argbBytes += channels[i] << (3 - i) * 8;
  // }

  int argbBytes = (((channels[0] & 0xff) << 24) |
          ((channels[1] & 0xff) << 16) |
          ((channels[2] & 0xff) << 8) |
          ((channels[3] & 0xff) << 0)) &
      0xFFFFFFFF;

  return argbBytes;
}

List<int> pixelDataToARGB(
  int pixelData,
) {
  int alpha = pixelData >> 24 & 255;
  int red = pixelData >> 16 & 255;
  int green = pixelData >> 8 & 255;
  int blue = pixelData >> 0 & 255;
  return [alpha, red, green, blue];
}

List<int> pixelDataToRGBA(
  int pixelData,
) {
  int alpha = pixelData >> 24 & 255;
  int red = pixelData >> 16 & 255;
  int green = pixelData >> 8 & 255;
  int blue = pixelData >> 0 & 255;
  return [red, green, blue, alpha];
}

void saveEnergyMatrixImageToGallery(
  Matrix2D energyMatrix,
  String path,
) {
  // imageLib.Image image =
  // energyMatrix.toImage((energy) => [255] + [energy, energy, energy]);
  // energyMatrix.toImage((energy) => [energy, energy, energy] + [255]);
  // imageLib.Image.fromBytes(energyMatrix.width, energyMatrix.height,
  //     energyMatrix.getData().map(pixelFunc).expand((x) => x).toList());

  Uint8List data = Uint8List(energyMatrix.length * 4);

  int i = 0;

  for (int energy in energyMatrix.data) {
    for (int ii = i; ii < i + 3; ii++) {
      data[ii] = energy;
    }
    data[i + 3] = 255;
    i += 4;
  }
  imageLib.Image image =
      imageLib.Image.fromBytes(energyMatrix.width, energyMatrix.height, data);

  image.saveInGallery(path);
}

// void saveImageFromImageMatrix(
//   Matrix2D<Uint32List> imageMatrix,
//   String path, {
//   saveToGallery: false,
// }) {
//   saveImageFromData(
//     imageMatrix.width,
//     imageMatrix.height,
//     imageMatrix.getData(),
//     path,
//     saveToGallery: saveToGallery,
//   );
// }

void saveImageFromData(
  int width,
  int height,
  Uint32List data,
  String path, {
  saveToGallery: false,
}) {
  Uint8List bytes = data.buffer.asUint8List();
  // assert (bytes.length == width * height);
  decodeImageFromPixels(
    bytes,
    width,
    height,
    // PixelFormat.rgba8888,
    PixelFormat.rgba8888,
    (Image im) async {
      ByteData byteData = await im.toByteData();
      imageLib.Image image;
      return {
        image = imageLib.Image.fromBytes(
            width, height, (byteData).buffer.asInt8List()),
        new File(path).writeAsBytesSync(imageLib.encodePng(image)),
        if (saveToGallery)
          {
            GallerySaver.saveImage(path),
          }
      };
    },
  );
}
