import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:binary/binary.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_new/utils.dart';
import 'package:flutter_app_new/matrix.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as imageLib;

class MatrixCache {
  Map<Size2D, List<List>> cache;
  int minDelta;
  int maxValues;

  MatrixCache({
    List<List> matrix,
    List<List> matrices,
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

    this.minDelta = (minDelta == null) ? 50 : minDelta;
    this.maxValues = (maxValues == null) ? 100 : maxValues;
  }

  operator [](index) => this.cache[index];

  void _add(List<List> matrix) {
    this.cache[sizeOfMatrix(matrix)] = matrix;
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

  void add(List<List> matrix) {
    var matrixSize = sizeOfMatrix(matrix);
    if (sizeShouldBeAdded(matrixSize)) {
      this._add(matrix);
    }
  }

  void _addAll(List<List<List>> matrices) {
    for (var matrix in matrices) {
      this._add(matrix);
    }
  }

  void addAll(List<List<List>> matrices) {
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

  List<List<List<int>>> closestBiggerMatrix(Size2D size) {
    return this.cache[this.closestBiggerSize(size)];
  }
}

class ResizeableImage {
  // imageLib.Image imageBytes;
  int height;
  int width;
  Size2D originalSize;
  MatrixCache pixelMatrixCache;
  MatrixCache energyMatrixCache;
  MatrixCache minEnergyMatrixCache;
  MatrixCache directionMatrixCache;
  List<List<int>> energyMatrix;

  ResizeableImage(imageLib.Image imageBytes) {
    // this.imageBytes = imageBytes;
    List<List<List<int>>> pixelMatrix = pixelMatrixFromImage(imageBytes);
    // this.height = pixelMatrix.length;
    // this.width = pixelMatrix[0].length;
    // this.originalSize = Size(this.height, this.width);

    energyMatrix = forwardEnergy(imageBytes);
    energyMatrixCache = MatrixCache(matrix: energyMatrix);

    var vals = minEnergy(energyMatrix);
    var minEnergyMatrix = vals[0];
    var directionMatrix = vals[1];

    this.minEnergyMatrixCache = MatrixCache(matrix: minEnergyMatrix);
    this.directionMatrixCache = MatrixCache(matrix: directionMatrix);

    this.pixelMatrixCache = MatrixCache(matrix: pixelMatrix);
  }

  List<List> atSize(Size2D size) {
    // @todo: I think closestBiggerSize isn't working

    Size2D closestSize = this.pixelMatrixCache.closestBiggerSize(size);
    debugPrint('closest size to $size was $closestSize');

    List<List<List<int>>> pixelMatrix =
        matrixCopy3D(this.pixelMatrixCache[closestSize]);
    List<List<int>> energyMatrix =
        matrixCopy2D(this.energyMatrixCache[closestSize]);
    List<List<int>> minEnergyMatrix =
        matrixCopy2D(this.minEnergyMatrixCache[closestSize]);
    List<List<int>> directionMatrix =
        matrixCopy2D(this.directionMatrixCache[closestSize]);

    var vals;
    List<List<int>> seam;
    List<List<List<int>>> lastSeams;

    // from manual plotting, a speedup of 4 seems most worth it
    int speedup = 4;

    Size2D sizeDelta = closestSize - size;
    debugPrint('carving $sizeDelta seams');

    Stopwatch loopStopwatch = new Stopwatch()..start();
    for (int i = 0; i < (sizeDelta.width / speedup).ceil(); i++) {
      int numCarvings = min(speedup, sizeDelta.width - i * speedup);

      assert(numCarvings > 0);

      if (i == 0) {
        vals = minEnergy(energyMatrix);
        minEnergyMatrix = vals[0];
        directionMatrix = vals[1];
      } else {
        recalculateMinEnergySuperMatrix_(
            energyMatrix, minEnergyMatrix, directionMatrix, lastSeams);
      }

      lastSeams = [];

      for (int _ = 0; _ < numCarvings; _++) {
        seam = getMinEnergyVerticalSeam(
          directionMatrix,
          minEnergyMatrix,
          correctEdges: speedup != 1,
        );

        carveSeamFromMatrix2D_(energyMatrix, seam);
        carveSeamFromMatrix3D_(pixelMatrix, seam);
        carveSeamFromMatrix2D_(minEnergyMatrix, seam);
        carveSeamFromMatrix2D_(directionMatrix, seam);

        lastSeams.add(seam);
      }

      Size2D newSize = sizeOfMatrix(pixelMatrix);

      if (energyMatrixCache.sizeShouldBeAdded(newSize)) {
        debugPrint('$newSize is being added to cache');
        this.energyMatrixCache._add(matrixCopy2D(energyMatrix));
        this.pixelMatrixCache._add(matrixCopy3D(pixelMatrix));
        this.minEnergyMatrixCache._add(matrixCopy2D(minEnergyMatrix));
        this.directionMatrixCache._add(matrixCopy2D(directionMatrix));
      }

      // debugPrint(i);
    }
    debugPrint('cropped in ${loopStopwatch.elapsed}');
    debugPrint('resulting matrix dimensions are ${sizeOfMatrix(pixelMatrix)}');
    debugPrint('');

    return pixelMatrix;
  }
}

sizeOfMatrix(List<List<List<int>>> pixelMatrix) {
  return Size2D(pixelMatrix.length, pixelMatrix[0].length);
}

List<List<int>> pixelBrightnessMatrixFromImage(imageLib.Image image) =>
    List.generate(
        image.height,
        (y) => List.generate(image.width,
            (x) => ARGBToBrightness(pixelDataToARGB(image.getPixel(x, y))),
            growable: true),
        growable: true);

int ARGBToBrightness(List<int> argb) {
  return imageLib.getLuminanceRgb(argb[1], argb[2], argb[3]);
}

List<List<List<int>>> pixelMatrixFromImage(imageLib.Image image) =>
    List.generate(
        image.height,
        (y) => List.generate(
            image.width, (x) => pixelDataToARGB(image.getPixel(x, y)),
            growable: true),
        growable: true);

List<List<int>> redChannelPixelMatrixFromImage(imageLib.Image image) =>
    List.generate(
        image.height,
        (y) => List.generate(
            image.width,
            (x) => int.parse(
                image.getPixel(x, y).toRadixString(2).substring(24, 32),
                radix: 2),
            growable: true),
        growable: true);

List<List<int>> matrixCopy2D(List<List<int>> matrix) =>
    List.generate(matrix.length, (y) => List.from(matrix[y], growable: true),
        growable: true);
//
// List<List<int>> matrixCopy2D(List<List<int>> matrix) => List.generate(
//     matrix.length,
//     (y) => List.generate(matrix[0].length, (x) => matrix[y][x], growable: true),
//     growable: true);

List<List<List<int>>> matrixCopy3D(List<List<List<int>>> matrix) =>
    List.generate(
        matrix.length,
        (y) => List.generate(
            matrix[0].length, (x) => List.from(matrix[y][x], growable: false),
            growable: true),
        growable: true);
//
// List<List<List<int>>> matrixCopy3D(List<List<List<int>>> matrix) =>
//     List.generate(
//         matrix.length,
//         (y) => List.generate(
//             matrix[0].length,
//             (x) => List.generate(matrix[0][0].length, (z) => matrix[y][x][z],
//                 growable: true),
//             growable: true),
//         growable: true);

List<int> pixelDataToARGB(int pixelData) {
  int alpha = pixelData >> 24 & 255;
  int red = pixelData >> 16 & 255;
  int green = pixelData >> 8 & 255;
  int blue = pixelData >> 0 & 255;
  return [alpha, red, green, blue];
}

List<List<int>> getMinEnergyVerticalSeam(
    List<List<int>> dirs, List<List<int>> minimumEdgyness,
    {bool correctEdges: false}) {
  var height = dirs.length;
  var width = dirs[0].length;
  List<List<int>> seam = new List(height);

  int x = argmin(minimumEdgyness[0]);

  for (int y = 0; y < height; y++) {
    seam[y] = [y, x];
    x += dirs[y][x];
    if (correctEdges) {
      x = x.clamp(0, width - 1);
    }

    try {
      assert(x >= 0);
    } catch (e) {
      throw e;
    }
    assert(x < width);
  }

  return seam;
}

List<List<List<int>>> paintSeam(
    List<List<List<int>>> pixelMatrix, List<List<int>> seam) {
  var seamColor = [255, 0, 0, 255];

  for (List<int> seamYX in seam) {
    pixelMatrix[seamYX[0]][seamYX[1]] = seamColor;
  }

  return pixelMatrix;
}

// ignore: non_constant_identifier_names
void carveSeamFromMatrix3D_(List<List> pixelMatrix, List<List<int>> seam) {
  for (List<int> seamYX in seam) {
    var y = seamYX[0];
    var x = seamYX[1];
    pixelMatrix[y].removeAt(x);
  }
}

// ignore: non_constant_identifier_names
void carveSeamFromMatrix2D_(List<List<int>> pixelMatrix, List<List<int>> seam) {
  for (List<int> seamYX in seam) {
    var y = seamYX[0];
    var x = seamYX[1];
    pixelMatrix[y].removeAt(x);
  }
}

minEnergy(List<List<int>> energyMatrix) {
  int height = energyMatrix.length;
  int width = energyMatrix[0].length;

  List<List<int>> leastE = fill2d(height, width, 0);
  List<List<int>> dirs = fill2d(height, width, 0);

  for (int i = 0; i < width; i++) {
    leastE[height - 1][i] = energyMatrix[height - 1][i];
  }

  for (int y = height - 2; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      var j1 = max(0, x - 1);
      var j2 = min(width - 1, x + 1);

      var options = leastE[y + 1].sublist(j1, j2 + 1);
      var ind = argmin(options);
      var e = options[ind];
      leastE[y][x] = energyMatrix[y][x] + e;
      dirs[y][x] = [-1, 0, 1][ind + boolToInt(x == 0)];

      if (dirs[y][x] == -1 && x == 0) {
        debugPrint('');
      }
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
  List<List<int>> energyMatrix,
  List<List<int>> minEnergyMatrix,
  List<List<int>> dirs,
  List<List<int>> lastSeam,
) {
  int height = energyMatrix.length;
  int width = energyMatrix[0].length;

//  for (int j = 0; j < dirs.length; j++) {
//    if (dirs[j][0] == -1) {
//      debugPrint('hw2');
//      debugPrint('');
//    }
//  }

//  for (int i = 0; i < width; i++) {
//    minEnergyMatrix[height - 1][i] = energyMatrix[height - 1][i];
//  }

  PriorityQueue<BottomRightPriorityCoordinates> toBeUpdated =
      new PriorityQueue();

//  Queue<YPriorityCoordinates> toBeUpdated = new Queue();

  int c = 0;

  for (List<int> seamYX in lastSeam.reversed.skip(1)) {
    var y = seamYX[0];
    var x = seamYX[1];

    for (int dx = -1; dx <= 1; dx++) {
      // <= 0 possible I think
      var xp = x + dx;
      if (xp >= 0 && xp < width) {
        toBeUpdated.add(new BottomRightPriorityCoordinates(y, xp));
      }
    }
  }

//  for (int x = seamEndXCoord - 1; x <= seamEndXCoord + 1; x++) {
//    toBeUpdated.add(new YPriorityCoordinates(height -2, x));
//  }

  while (toBeUpdated.isNotEmpty) {
    BottomRightPriorityCoordinates coords = toBeUpdated.removeFirst();
    int y = coords.y;
    int x = coords.x;

    c++;

    var leftBound = max(0, x - 1);
    var rightBound = min(width - 1, x + 1);

    var options = minEnergyMatrix[y + 1].sublist(leftBound, rightBound + 1);
    var ind = argmin(options);
    var e = options[ind];

    int newDir = [-1, 0, 1][ind + boolToInt(x == 0)];

    var newMinEnergy = energyMatrix[y][x] + e;

    if (minEnergyMatrix[y][x] != newMinEnergy || dirs[y][x] != newDir) {
      minEnergyMatrix[y][x] = newMinEnergy;
      dirs[y][x] = newDir;

      if (y == 0) {
        continue;
      }

      for (int dx = -1; dx <= 1; dx++) {
        var newX = x + dx;
        var newY = y - 1;
        if (newX >= 0 && newX < width) {
          var newCoords = BottomRightPriorityCoordinates(newY, newX);
          if (!toBeUpdated.contains(newCoords)) {
            toBeUpdated.add(newCoords);
          }
        }
      }
    }
//    assert(dirs[y][x] == newDir);
//    assert(minEnergyMatrix[y][x] == energyMatrix[y][x] + e);
  }
}

recalculateMinEnergySuperMatrix_(
  List<List<int>> energyMatrix,
  List<List<int>> minEnergyMatrix,
  List<List<int>> dirs,
  List<List<List<int>>> lastSeams,
) {
  int height = energyMatrix.length;
  int width = energyMatrix[0].length;

  List<List<bool>> updateMatrix = fill2dBool(height, width, false);

  int c = 0;

  for (var seam in lastSeams) {
    for (List<int> seamYX in seam.reversed.skip(1)) {
      var y = seamYX[0];
      var x = seamYX[1];

      for (int dx = -1; dx <= 1; dx++) {
        var xp = x + dx;
        if (xp >= 0 && xp < width) {
          updateMatrix[y][xp] = true;
          // totalUpdated[y][xp] = true;
        }
      }
    }
  }

  // int lastSeamBottomX = lastSeam[lastSeam.length - 1][1];

  for (int y = height - 2; y >= 0; y--) {
    for (int x = 0; x < width; x++) {
      // for (int x = lastSeamBottomX - i; x <= lastSeamBottomX + i; x++) {
      if (x < 0 || x >= width) {
        continue;
      }
      if (!updateMatrix[y][x]) {
        continue;
      }

      c++;

      var leftBound = max(0, x - 1);
      var rightBound = min(width - 1, x + 1);

      var options = minEnergyMatrix[y + 1].sublist(leftBound, rightBound + 1);
      var ind = argminLe3(options);
      var e = options[ind];

      int newDir = [-1, 0, 1][ind + boolToInt(x == 0)];

      var newMinEnergy = energyMatrix[y][x] + e;
      if (minEnergyMatrix[y][x] != newMinEnergy || dirs[y][x] != newDir) {
        minEnergyMatrix[y][x] = newMinEnergy;
        dirs[y][x] = newDir;

        if (y == 0) {
          continue;
        }

        for (int dx = -1; dx <= 1; dx++) {
          var newX = x + dx;
          var newY = y - 1;
          if (newX >= 0 && newX < width) {
            updateMatrix[newY][newX] = true;
            // totalUpdated[newY][newX] = true;
          }
        }
      }

      updateMatrix[y][x] = false;
    }
  }

//  debugPrint(c);

//  matrixToGalleryImage(totalUpdated, boolToARGBBytes,
//      '/data/user/0/com.example.flutter_app_new/cache/tempi2m.jpg'); // this is just for debgging. will brake
}

bool onDiagonal(List<int> coordYX, List<int> sourceYX, int dx) {
  for (int i = sourceYX[0]; i >= 0; i++) {
    List<int> currYX = [sourceYX[0] - i, sourceYX[0] + i * dx];

    if (currYX[0] > coordYX[0]) {
      return false;
    }

    if (currYX[0] == coordYX[0] && currYX[1] == coordYX[1]) {
      return true;
    }
  }

  return false;
}

List<List<int>> sobelEnergy(imageLib.Image imageBytes, [saveDir]) {
  var sobel = imageLib.sobel(imageBytes.clone());

  if (saveDir != null) {
    new File(saveDir).writeAsBytesSync(imageLib.encodePng(sobel));
    GallerySaver.saveImage(saveDir);
  }

  return redChannelPixelMatrixFromImage(sobel);
}

List<List<int>> forwardEnergy(imageLib.Image imageBytes, [saveDir]) {
  // https://nbviewer.jupyter.org/github/axu2/improved-seam-carving/blob/master/Improved%20Seam%20Carving.ipynb

  List<List<int>> imageMatrix = pixelBrightnessMatrixFromImage(imageBytes);

  int height = imageMatrix.length;
  int width = imageMatrix[0].length;

  List<List<int>> energy = fill2d(height, width, 0);
  List<List<int>> m = fill2d(height, width, 0);

  for (int i = 1; i < height; i++) {
    for (int j = 0; j < width; j++) {
      int up = (i - 1) % height;
      int down = (i + 1) % height;
      int left = (j - 1) % width;
      int right = (j + 1) % width;

      int mU = m[up][j];
      int mL = m[up][left];
      int mR = m[up][right];

      int cU = (imageMatrix[i][right] - imageMatrix[i][left]).abs();
      int cL = (imageMatrix[up][j] - imageMatrix[i][left]).abs() + cU;
      int cR = (imageMatrix[up][j] - imageMatrix[i][right]).abs() + cU;

      List<int> cULR = [cU, cL, cR];
      List<int> mULR = [mU, mL, mR] + cULR;

      int indMin = argmin(mULR);
      m[i][j] = mULR[indMin];
      energy[i][j] = cULR[indMin];
    }
  }

  if (saveDir != null) {
    matrixToGalleryImage(energy, pixelBrightnessToARGBBytes, saveDir);
//    new File(saveDir).writeAsBytesSync(imageLib.encodePng(energy));
//    GallerySaver.saveImage(saveDir);
  }

  return energy;
}

int boolToInt(bool b) => b ? 1 : 0;

int bitsToInt(String bitString) =>
    int.parse(int.parse(bitString, radix: 2).toRadixString(10));

int dirToBytes(dir) {
  String bitString;
  switch (dir) {
    case -1:
      bitString = '11111111111111110000000000000000';
      break;
    case 0:
      bitString = '11111111000000001111111100000000';
      break;
    case 1:
      bitString = '11111111000000000000000011111111';
      break;
  }

  return bitsToInt(bitString);
}

int pixelARGBChannelsToARGBBytes(List<int> channels) {
  int argbBytes = 0;

  for (int i = 0; i < 4; i++) {
    argbBytes += channels[i] << (3 - i) * 8;
  }
  return argbBytes;
}

int pixelBrightnessToARGBBytes(int brightness) {
  String bitString = '';

  bitString += 255.toRadixString(2).padLeft(8, '0');
  bitString += brightness.toRadixString(2).padLeft(8, '0') * 3;

  return bitsToInt(bitString);
}

int boolToARGBBytes(bool b) => bitsToInt((b ? '1' : '0') * 8 * 4);

void matrixToGalleryImage(
    List<List<dynamic>> matrix, Function pixelToBytes, String savePath) {
  imageLib.Image image;

  int height = matrix.length;
  int width = matrix[0].length;

  Int32List pixelArray = Int32List(height * width);

  int i;
  var pixel;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      i = y * width + x;
      pixel = matrix[y][x];
      pixelArray[i] = pixelToBytes(pixel);
    }
  }

  decodeImageFromPixels(
    pixelArray.buffer.asUint8List(),
    width,
    height,
    PixelFormat.rgba8888,
    (Image im) async {
      ByteData byteData = await im.toByteData();
      return {
        image = imageLib.Image.fromBytes(
            width, height, (byteData).buffer.asInt8List()),
        new File(savePath).writeAsBytesSync(imageLib.encodePng(image)),
        GallerySaver.saveImage(savePath),
      };
    },
  );
}

void visualizeDirs(List<List<int>> dirs, savePath) {
  matrixToGalleryImage(dirs, dirToBytes, savePath);
}

int minPathSum(List<List<int>> grid) {
  int m = grid.length;
  int n = grid[0].length;

  List<List<int>> dp = fill2d(m, n, 0);
  dp[0][0] = grid[0][0];

// initialize top row
  for (int i = 1; i < n; i++) {
    dp[0][i] = dp[0][i - 1] + grid[0][i];
  }

// initialize left column
  for (int j = 1; j < m; j++) {
    dp[j][0] = dp[j - 1][0] + grid[j][0];
  }

// fill up the dp table
  for (int i = 1; i < m; i++) {
    for (int j = 1; j < n; j++) {
      if (dp[i - 1][j] > dp[i][j - 1]) {
        dp[i][j] = dp[i][j - 1] + grid[i][j];
      } else {
        dp[i][j] = dp[i - 1][j] + grid[i][j];
      }
    }
  }

  return dp[m - 1][n - 1];
}
