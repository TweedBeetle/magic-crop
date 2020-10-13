import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import "dart:async";
import "dart:isolate";
import "package:isolate/isolate.dart";
import 'package:binary/binary.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_new/matrix.dart';
import 'package:flutter_app_new/utils.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as imageLib;

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
    new File(path).writeAsBytesSync(imageLib.encodePng(this));
    GallerySaver.saveImage(path);
  }
}

class ImageCache {
  Map<Size2D, imageLib.Image> cache;
  int minDelta;
  int maxValues;

  ImageCache({
    imageLib.Image image,
    List<imageLib.Image> images,
    int minDelta,
    int maxValues,
  }) {
    this.cache = Map();

    if (image != null) {
      this._add(image);
    }

    if (images != null) {
      this._addAll(images);
    }

    this.minDelta = (minDelta == null) ? 50 : minDelta;
    this.maxValues = (maxValues == null) ? 100 : maxValues;
  }

  imageLib.Image operator [](index) => this.cache[index];

  void _add(imageLib.Image image) {
    this.cache[image.size()] = image;
  }

  bool sizeShouldBeAdded(Size2D size) {
    if (this.cache.length == 0) {
      return true;
    }

    if (this.cache.length >= this.maxValues) {
      return false;
    }

    Size2D closestSize = this.closestBiggerSize(size);

    if (closestSize.totalDelta(size) < this.minDelta) {
      return false;
    }

    return true;
  }

  void add(imageLib.Image image) {
    var imageSize = image.size();
    if (sizeShouldBeAdded(imageSize)) {
      this._add(image);
    }
  }

  void _addAll(List<imageLib.Image> images) {
    for (var image in images) {
      this._add(image);
    }
  }

  void addAll(List<imageLib.Image> images) {
    for (var image in images) {
      this.add(image);
    }
  }

  Size2D closestBiggerSize(Size2D size) {
    List<Size2D> biggerSizes = this
        .cache
        .keys
        .where((element) => element.compareTo(size) == 1)
        .toList();

    Size2D key = biggerSizes.reduce((curr, element) =>
        curr.totalDelta(size) <= element.totalDelta(size) ? curr : element);

    return key;
  }

  imageLib.Image closestBiggerMatrix(Size2D size) {
    return this.cache[this.closestBiggerSize(size)];
  }
}

class MatrixCache {
  Map<Size2D, Matrix2D> cache;
  int minDelta;
  int maxValues;

  MatrixCache({
    Matrix2D matrix,
    List<Matrix2D> matrices,
    int minDelta,
    int maxValues,
  }) {
    this.cache = Map();

    if (matrix != null) {
      this._add(matrix);
    }

    if (matrices != null) {
      this._addAll(matrices);
    }

    this.minDelta = (minDelta == null) ? 20 : minDelta;
    this.maxValues = (maxValues == null) ? 500 : maxValues;
  }

  Matrix2D operator [](index) => this.cache[index];

  void _add(Matrix2D matrix) {
    this.cache[matrix.size()] = matrix;
  }

  bool sizeShouldBeAdded(Size2D size) {
    if (this.cache.length == 0) {
      return true;
    }

    if (this.cache.length >= this.maxValues) {
      return false;
    }

    Size2D closestSize = this.closestBiggerSize(size);

    if (closestSize.totalDelta(size) < this.minDelta) {
      return false;
    }

    return true;
  }

  void add(Matrix2D matrix) {
    var matrixSize = matrix.size();
    if (sizeShouldBeAdded(matrixSize)) {
      this._add(matrix);
    }
  }

  void _addAll(List<Matrix2D> matrices) {
    for (var matrix in matrices) {
      this._add(matrix);
    }
  }

  void addAll(List<Matrix2D> matrices) {
    for (var matrix in matrices) {
      this.add(matrix);
    }
  }

  Size2D closestBiggerSize(Size2D size) {
    List<Size2D> biggerSizes = this
        .cache
        .keys
        .where((element) => element.compareTo(size) == 1)
        .toList();

    Size2D key = biggerSizes.reduce((curr, element) =>
        curr.totalDelta(size) <= element.totalDelta(size) ? curr : element);

    return key;
  }

  Matrix2D closestBiggerMatrix(Size2D size) {
    return this.cache[this.closestBiggerSize(size)];
  }
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

  ResizeableImage(imageLib.Image image) {
    width = image.width;
    height = image.height;

    Matrix2D<Uint8List> energyMatrix = forwardEnergy(image);

    var vals = minEnergy(energyMatrix);
    var minEnergyMatrix = vals[0];
    var directionMatrix = vals[1];

    energyMatrixCache = MatrixCache(matrix: energyMatrix);
    minEnergyMatrixCache = MatrixCache(matrix: minEnergyMatrix);
    directionMatrixCache = MatrixCache(matrix: directionMatrix);

    Matrix2D<Uint32List> imageMatrix = Matrix2D.fromImage(image);

    assert(imageMatrix.length == width * height);

    imageMatrixCache = MatrixCache(matrix: imageMatrix);
  }

  void atSize(Size2D size, savePath, {int speedup: 4}) {
    Size2D closestSize = this.imageMatrixCache.closestBiggerSize(size);
    debugPrint('closest size to $size was $closestSize');

    Stopwatch stopwatch = new Stopwatch()..start();

    Matrix2D<Uint32List> imageMatrix =
        this.imageMatrixCache[closestSize].clone();
    Matrix2D<Uint8List> energyMatrix =
        this.energyMatrixCache[closestSize].clone();
    Matrix2D<Uint32List> minEnergyMatrix =
        this.minEnergyMatrixCache[closestSize].clone();
    Matrix2D<Int8List> directionMatrix =
        this.directionMatrixCache[closestSize].clone();

    debugPrint('set up in in ${stopwatch.elapsed}');

    var vals;
    List<List<int>> seam;
    List<List<List<int>>> lastSeams;

    Size2D sizeDelta = closestSize - size;

    List<List<List<int>>> allSeams = List(sizeDelta.total());

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
          seam = getMinEnergyVerticalSeam(
            directionMatrix,
            minEnergyMatrix,
            correctEdges: speedup != 1,
          );

          // var c1 = SingleResponseChannel();
          // var c1 = SendPort();
          // Isolate.spawn(carveIsolateHelper, [imageMatrix, seam]);
          // imageMatrix = await c1;

          imageMatrix = imageMatrix.carveSeam(seam, ordered: true);
          energyMatrix = energyMatrix.carveSeam(seam, ordered: true);
          minEnergyMatrix = minEnergyMatrix.carveSeam(seam, ordered: true);
          directionMatrix = directionMatrix.carveSeam(seam, ordered: true);
          lastSeams.add(seam);
          numCarved++;
        }

        Size2D newSize = energyMatrix.size();
        if (axis == deltaAxis.y) {
          newSize = newSize.inverted();
        }

        if (energyMatrixCache.sizeShouldBeAdded(newSize)) {
          debugPrint('$newSize is being added to cache');

          int rotation = axis == deltaAxis.x ? 0 : -1;

          this.imageMatrixCache._add(imageMatrix.rotated(rotation));
          this.energyMatrixCache._add(energyMatrix.rotated(rotation));
          this.minEnergyMatrixCache._add(minEnergyMatrix.rotated(rotation));
          this.directionMatrixCache._add(directionMatrix.rotated(rotation));
        }

        debugPrint(i.toString());
      }

      if (axis == deltaAxis.y) {
        imageMatrix = imageMatrix.rotated(-1);
        // energyMatrix = energyMatrix.rotated(-1);
        // minEnergyMatrix = minEnergyMatrix.rotated(-1);
        // directionMatrix = directionMatrix.rotated(-1);
      }

      debugPrint('cropped $axis in ${loopStopwatch.elapsed}');
      debugPrint('resulting matrix dimensions are ${imageMatrix.size()}');
      debugPrint('');
    }

    saveImageFromImageMatrix(imageMatrix, savePath);
  }
}

List<int> pixelDataToARGB(int pixelData) {
  int alpha = pixelData >> 24 & 255;
  int red = pixelData >> 16 & 255;
  int green = pixelData >> 8 & 255;
  int blue = pixelData >> 0 & 255;
  return [alpha, red, green, blue];
}

int ARGBToBrightness(List<int> argb) {
  return imageLib.getLuminanceRgb(argb[1], argb[2], argb[3]);
}

Matrix2D<Uint8List> pixelBrightnessMatrixFromImage(imageLib.Image image) =>
    Matrix2D.fromData(
        image.width,
        image.height,
        image
            .getBytes()
            .buffer
            .asInt32List()
            .map((v) => ARGBToBrightness(pixelDataToARGB(v)))
            .toList());

List<List<int>> getMinEnergyVerticalSeam(
  Matrix2D dirs,
  Matrix2D minimumEdgyness, {
  bool correctEdges: false,
}) {
  List<List<int>> seam = new List(dirs.height);

  int x = argmin(minimumEdgyness.getRow(0));

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

void paintSeam_(imageLib.Image image, List<List<int>> seam) {
  for (List<int> seamYX in seam) {
    image.setPixelRgba(seamYX[1], seamYX[0], 255, 0, 0);
  }
}

minEnergy(Matrix2D energyMatrix) {
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
recalculateMinEnergy_(
  Matrix2D energyMatrix,
  Matrix2D minEnergyMatrix,
  Matrix2D dirs,
  List<List<List<int>>> removedSeams,
) {
  int height = energyMatrix.height;
  int width = energyMatrix.width;

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

Matrix2D<Uint8List> forwardEnergy(imageLib.Image image, [saveDir]) {
  // https://nbviewer.jupyter.org/github/axu2/improved-seam-carving/blob/master/Improved%20Seam%20Carving.ipynb
  Matrix2D<Uint8List> brightnessMatrix = pixelBrightnessMatrixFromImage(image);

  int height = brightnessMatrix.height;
  int width = brightnessMatrix.width;

  Matrix2D<Uint8List> energy = Matrix2D(width, height, 0);
  Matrix2D<Uint32List> m = Matrix2D(width, height, 0);

  for (int i = 1; i < height; i++) {
    for (int j = 0; j < width; j++) {
      int up = (i - 1) % height;
      int down = (i + 1) % height;
      int left = (j - 1) % width;
      int right = (j + 1) % width;

      int mU = m.getCell(j, up);
      int mL = m.getCell(left, up);
      int mR = m.getCell(right, up);

      int cU = (brightnessMatrix.getCell(right, i) -
              brightnessMatrix.getCell(left, i))
          .abs();
      int cL =
          (brightnessMatrix.getCell(j, up) - brightnessMatrix.getCell(left, i))
                  .abs() +
              cU;
      int cR =
          (brightnessMatrix.getCell(j, up) - brightnessMatrix.getCell(right, i))
                  .abs() +
              cU;

      List<int> cULR = [cU, cL, cR];
      List<int> mULR = [mU, mL, mR] + cULR;

      int indMin = argmin(mULR);
      m.setCell(j, i, mULR[indMin]);
      energy.setCell(j, i, cULR[indMin]);
      assert(cULR[indMin] <= 255);
    }
  }

  // if (saveDir != null) {
  //   new File(saveDir).writeAsBytesSync(imageLib.encodePng(matrixToImage(energy, pixelBrightnessToARGBBytes)))
  //   GallerySaver.saveImage(saveDir);
//    new File(saveDir).writeAsBytesSync(imageLib.encodePng(energy));
//    GallerySaver.saveImage(saveDir);
//   }

  return energy;
}

int pixelBrightnessToARGBBytes(int brightness) {
  //todo: bitshifting
  String bitString = '';

  bitString += 255.toRadixString(2).padLeft(8, '0');
  bitString += brightness.toRadixString(2).padLeft(8, '0') * 3;

  return bitsToInt(bitString);
}

int bitsToInt(String bitString) => //todo: bitshifting
    int.parse(int.parse(bitString, radix: 2).toRadixString(10));

int pixelARGBChannelsToARGBBytes(List<int> channels) {
  int argbBytes = 0;

  for (int i = 0; i < 4; i++) {
    argbBytes += channels[i] << (3 - i) * 8;
  }
  return argbBytes;
}

imageLib.Image matrixToImage(
        Matrix2D matrix, List<int> Function(int) pixelFunc) =>
    imageLib.Image.fromBytes(
        matrix.width,
        matrix.height,
        matrix
            .getData()
            .map(pixelFunc)
            .map(pixelARGBChannelsToARGBBytes)
            .toList(growable: false));

void saveImageFromImageMatrix(Matrix2D<Uint32List> imageMatrix, String path) {
  saveImageFromData(
      imageMatrix.width, imageMatrix.height, imageMatrix.getData(), path);
}

void saveImageFromData(int width, int height, Uint32List data, String path) {
  Uint8List bytes = data.buffer.asUint8List();
  // assert (bytes.length == width * height);
  decodeImageFromPixels(
    bytes,
    width,
    height,
    PixelFormat.rgba8888,
    (Image im) async {
      ByteData byteData = await im.toByteData();
      imageLib.Image image;
      return {
        image = imageLib.Image.fromBytes(
            width, height, (byteData).buffer.asInt8List()),
        new File(path).writeAsBytesSync(imageLib.encodePng(image)),
        GallerySaver.saveImage(path),
      };
    },
  );
}

void carveIsolateHelper(vars) {
  vars[2].send(vars[0].carveSeam(vars[1], ordered: true));
}
