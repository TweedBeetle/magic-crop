import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:quiver/core.dart';
import 'package:quiver/iterables.dart' show cycle, count, enumerate;

import 'package:equatable/equatable.dart';
import 'package:flutter_app_new/seam_carving.dart';
import 'package:image/image.dart' as imageLib;

import 'utils.dart';

class Size2D extends Equatable implements Comparable {
  final int height;
  final int width;

  Size2D(this.height, this.width);

  @override
  int compareTo(other) {
    if (this.height == other.height && this.width == other.width) {
      return 0;
    } else if (this.height > other.height || this.width > other.width) {
      return 1; // other fits in this
    } else {
      return -1; // this fits in other
    }
  }

  Size2D inverted() {
    return Size2D(width, height);
  }

  @override
  String toString() => '<Size ($height, $width)>';

  Size2D operator -(Size2D other) {
    return Size2D(this.height - other.height, this.width - other.width);
  }

  Size2D operator +(Size2D other) {
    return Size2D(this.height + other.height, this.width + other.width);
  }

  int totalDelta(Size2D other) {
    // assert(other.compareTo(this) == 1);

    return (other.height - this.height).abs() +
        (other.width - this.width).abs();

    // Size diffSize = other - this;
    // return diffSize.width + diffSize.height;
  }

  @override
  List<Object> get props => [height, width];

  int total() => height.abs() + width.abs();
}

class Sizeable2D {
  Size2D size() {}
}

class Matrix2D<T extends List<int>> implements Sizeable2D {
  int width;

  int height;

  final T data;

  int rotation = 0; //clockwise

  Map<int, int> indexCache;

  Matrix2D(this.width, this.height, [int fillValue])
      : data = initializeData<T>(width * height, fillValue),
        indexCache = Map<int, int>(),
        rotation = 0 {
    assert(width * height == data.length);
  }

  /// Create a copy of the image [other].
  Matrix2D.from(Matrix2D other)
      : width = other.width,
        height = other.height,
        data = other.data.sublist(0),
        indexCache = Map<int, int>.from(other.indexCache),
        rotation = other.rotation;

  Matrix2D.fromImage(imageLib.Image image)
      : width = image.width,
        height = image.height,
        data =
            // initializeDataFromList<T>(Uint32List.view(image.getBytes().buffer)),
            initializeDataFromList<T>(image.getBytes().buffer.asUint32List()),
        indexCache = Map<int, int>(),
        rotation = 0 {
    assert(data.length == image.data.length);
  }

  Matrix2D.fromData(
    int width,
    int height,
    List<int> data,
  )   : width = width,
        height = height,
        data = data is T ? data : initializeDataFromList<T>(data),
        indexCache = Map<int, int>() {
    assert(width * height == data.length);
  }

  Matrix2D<T> rotated(int newRotation) {
    if (newRotation == 0) {
      return clone();
    }

    int oldRotation = rotation;
    rotation = newRotation;

    _switchHeightAndWidth();

    T newData = initializeData<T>(length);

    int i = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        newData[i] = getCell(x, y);
        i++;
      }
    }
    Matrix2D<T> rotatedMatrix = Matrix2D<T>.fromData(width, height, newData);

    rotation = oldRotation;
    _switchHeightAndWidth();

    return rotatedMatrix;
  }

  Matrix2D<T> clone() => Matrix2D.from(this);

  T getData() {
    return data;
  }

  Matrix2D<T> fill(int value) {
    data.fillRange(0, data.length, value);
    return this;
  }

  int get length => data.length;

  void _switchHeightAndWidth() {
    int oldWidth = width;
    width = height;
    height = oldWidth;
  }

  void pseudoRotateRight() {
    assert(rotation != 1);
    rotation += 1;
    _switchHeightAndWidth();
    indexCache = Map<int, int>();
  }

  void pseudoRotateLeft() {
    assert(rotation != -1);
    rotation -= 1;
    _switchHeightAndWidth();
    indexCache = Map<int, int>();
  }

  int operator [](int index) => data[index];

  void operator []=(int index, int color) {
    data[index] = color;
  }

  int index(int x, int y) {
    switch (rotation) {
      case 0:
        {
          // int hash = hash2(x, y);
          //
          // if (! indexCachRe.containsKey(hash)) {
          //   int index = y * width + x;
          //   indexCache[hash] = index;
          //   return index;
          // }
          //
          // return indexCache[hash];

          return y * width + x;
        }
      case 1:
        {
          int newX = y;
          int newY = width - x - 1;
          return newY * height + newX;
        }
      case -1:
        {
          int newY = x;
          int newX = height - y - 1;
          return newY * height + newX;
        }
      default:
        {
          throw Exception('rotation $rotation not supported');
        }
    }

    // if (rotation == 1) {
    //   int newX = y;
    //   int newY = width - x - 1;
    //   return newY * height + newX;
    // } else {
    //   return y * width + x;
    // }
  }

  /// Is the given [x], [y] pixel coordinates within the resolution of the image.
  bool boundsSafe(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  /// Get the pixel from the given [x], [y] coordinate. Color is encoded in a
  /// Uint32 as #AABBGGRR. No range checking is done.
  int getCell(int x, int y) => data[index(x, y)];

  T getRow(int y) {
    if (rotation != 0) {
      return initializeDataFromList<T>(
          List.generate(width, (x) => data[index(x, y)]));
    } else {
      return data.sublist(y * width, y * width + width);
    }
  }

  int getCellSafe(int x, int y) => boundsSafe(x, y) ? data[index(x, y)] : 0;

  /// Set the pixel at the given [x], [y] coordinate to the [value].
  /// No range checking is done.
  void setCell(int x, int y, int value) {
    data[index(x, y)] = value;
  }

  /// Set the pixel at the given [x], [y] coordinate to the [value].
  /// If the pixel coordinates are out of bounds, nothing is done.
  void setCellSafe(int x, int y, int value) {
    if (boundsSafe(x, y)) {
      data[index(x, y)] = value;
    }
  }

  @override
  Size2D size() {
    return Size2D(height, width);
  }

  Matrix2D<T> withCarvedIndices(
    List<int> indices, {
    ordered: false,
  }) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    if (!ordered) {
      indices.sort();
    }

    var newLength = data.length - indices.length;
    final T newData = initializeData(newLength);

    // int di = 0;
    // for (int i = 0; i < newData.length; i++) {
    //   if (indices[di] == i) {
    //     di++;
    //   }
    //   newData[i] = this.data[i + di];
    // }

    int lastRemovalEnd = -1;
    int lastInsertEnd = 0;
    for (int removalEnd in indices) {
      int insertStart = lastInsertEnd;
      int insertEnd = insertStart + (removalEnd - lastRemovalEnd) - 1;
      int skip = lastRemovalEnd + 1;
      newData.setRange(
        insertStart,
        insertEnd,
        data,
        skip,
      );

      lastInsertEnd = insertEnd + 0;
      lastRemovalEnd = removalEnd + 0;
    }

    newData.setRange(
      lastInsertEnd,
      newLength,
      data,
      lastRemovalEnd + 1,
    );

    // assert (newData.length + di == data.length);

    return Matrix2D.fromData(width - 1, height, newData);
  }

  Matrix2D<T> withCarvedSeams(
    List<List<List<int>>> seams,
  ) {
    var seamLength = seams[0].length;
    List<int> indices = List(seams.length * seamLength);

    for (int seamInd = 0; seamInd < seams.length; seamInd++) {
      indices.setRange(
        seamInd * seamLength,
        seamInd * seamLength + seamLength,
        seams[seamInd].map((coordYX) => index(coordYX[1], coordYX[0])),
      );
    }

    return withCarvedIndices(indices, ordered: false);
  }

  Matrix2D<T> withCarvedSeam(
    List<List<int>> seam, {
    ordered: false,
  }) {
    List<int> indices =
        seam.map((coordYX) => this.index(coordYX[1], coordYX[0])).toList();

    return withCarvedIndices(indices, ordered: ordered);
  }

  List withExpandedSeams(
    List<List<List<int>>> seams,
  ) {
    List<List<int>> cells = seams.expand((x) => x).toList(growable: false);
    // cells.sort((a, b) => -1 * a[1].compareTo(b[1]));

    List<int> indices =
        cells.map((coordYX) => this.index(coordYX[1], coordYX[0])).toList();

    return withExpandedIndices(indices);
  }

  List withExpandedIndices(List<int> indices) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    int widthDelta = indices.length ~/ height;

    assert(widthDelta > 0);

    var newLength = data.length + indices.length;
    assert(newLength == data.length + widthDelta * height);

    final T newData = initializeData(newLength);

    Uint32List indicesToFill = Uint32List(indices.length);

    int i = 0;
    indices.sort();
    int lastRemovalEnd = -1;
    int lastInsertEnd = -1;
    for (int removalEnd in indices) {
      int insertStart = lastInsertEnd + 1;
      int insertEnd = insertStart + (removalEnd - lastRemovalEnd);
      int skip = lastRemovalEnd + 1;
      newData.setRange(
        insertStart,
        insertEnd,
        data,
        skip,
      );
      indicesToFill[i++] = insertEnd;

      lastInsertEnd = insertEnd;
      lastRemovalEnd = removalEnd;
    }

    newData.setRange(
      lastInsertEnd + 1,
      newLength,
      data,
      lastRemovalEnd + 1,
    );

    // int di = 0;
    // for (int i = 0; i < newData.length; i++) {
    //   if (indices[di] == i) {
    //     di++;
    //   }
    //   newData[i] = this.data[i + di];
    // }

    // indicesToFill.forEach((index) {assert (newData[index] == 0);});

    Matrix2D<T> newMatrix =
        Matrix2D.fromData(width + widthDelta, height, newData);

    return [newMatrix, indicesToFill];
  }

  rowSublist(int y, int leftBound, int rightBound) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    return data.sublist(y * width + leftBound, y * width + rightBound);
  }

  argminAndValminOfRowSublist(int y, int leftBound, int rightBound) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    int left = y * width + leftBound;
    int right = y * width + rightBound;

    int diff = right - left;

    // assert (diff <= 3 && diff > 0);

    var firstVal = data[left];
    if (diff == 1) {
      return [0, firstVal];
    }

    int argminOf2 = firstVal < data[left + 1] ? 0 : 1;

    var valminOf2 = data[left + argminOf2];
    if (diff == 2) {
      return [argminOf2, valminOf2];
    }

    var thirdVal = data[left + 2];
    return valminOf2 < thirdVal ? [argminOf2, valminOf2] : [2, thirdVal];
  }

  imageLib.Image toImage(List<int> Function(int) pixelFunc) =>
      imageLib.Image.fromBytes(width, height,
          this.getData().map(pixelFunc).expand((x) => x).toList());

  // .map(pixelARGBChannelsToARGBBytes)
  // .toList(growable: false));

  @override
  String toString() {
    return (List.generate(height, (y) => getRow(y))).join('\n');
  }

  void fillSeam(List<List<int>> seam, int value) {
    seam.forEach((YXind) {
      setCell(YXind[1], YXind[0], value);
    });
  }

  List<int> xyFromIndex(int i) {
    // y * width + x

    int y = (i / width).floor();
    int x = i - y * width;

    assert(index(x, y) == i);

    return [x, y];
  }

  double mean() {
    return data.reduce((a, b) => a + b) / data.length;
  }

  double std([mean]) {
    mean = mean ?? this.mean();

    double variance =
        data.map((v) => pow(mean - v, 2)).reduce((a, b) => a + b) / data.length;

    return sqrt(variance);
  }

  int max() {
    return data.reduce((a, b) => a < b ? b : a);
  }

  Matrix2D<Uint8List> getForwardEnergyVertical() {
    // https://nbviewer.jupyter.org/github/axu2/improved-seam-carving/blob/master/Improved%20Seam%20Carving.ipynb

    Matrix2D<Uint8List> energyMatrix = Matrix2D(width, height, 0);
    Matrix2D<Uint32List> m = Matrix2D(width, height, 0);

    for (int y = 1; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int up = (y - 1) % height;
        // int down = (y + 1) % height;
        int left = (x - 1) % width;
        int right = (x + 1) % width;

        int mU = m.getCell(x, up);
        int mL = m.getCell(left, up);
        int mR = m.getCell(right, up);

        int cU = (getCell(right, y) - getCell(left, y)).abs();
        int cL = (getCell(x, up) - getCell(left, y)).abs() + cU;
        int cR = (getCell(x, up) - getCell(right, y)).abs() + cU;


        List<int> cULR = [cU, cL, cR];
        List<int> mULR = List<int>(6);

        mULR[0]= mU;
        mULR[1]= mL;
        mULR[2]= mR;
        mULR[3]= cU;
        mULR[4]= cL;
        mULR[5]= cR;
        // mULR.setRange(0, 3, [mU, mL, mR]);
        // mULR.replaceRange(3, 6, cULR);

        // mULR = [mU, mL, mR] + cULR;

        int indMin = argmin(mULR);
        m.setCell(x, y, mULR[indMin]);
        energyMatrix.setCell(x, y, cULR[indMin]);
      }
    }

    return energyMatrix;
  }

  Matrix2D<Uint8List> getForwardEnergy() {
    // https://nbviewer.jupyter.org/github/axu2/improved-seam-carving/blob/master/Improved%20Seam%20Carving.ipynb

    Matrix2D<Uint8List> energyMatrixVert = getForwardEnergyVertical();
    Matrix2D<Uint8List> energyMatrixHor =
        rotated(1).getForwardEnergyVertical().rotated(-1);

    return energyMatrixVert.meanWith(energyMatrixHor);
  }

  Uint8List forwardEnergyIndices(List<int> indices, {sorted: false}) {
    throw UnimplementedError('forward energy hast to rotate and stuff');

    if (!sorted) {
      throw Exception('indices must be sorted');
    }

    Matrix2D<Uint32List> m = Matrix2D(width, height);

    Uint8List energies = Uint8List(indices.length);

    // for (int i in count().take(indices.length)) {
    //   var xy = xyFromIndex(indices[i]);
    for (var keyVal in enumerate(indices)) {
      var xy = xyFromIndex(keyVal.value);
      int y = xy[1];

      if (y == 0) {
        energies[keyVal.index] = 0;
        continue;
      }

      int x = xy[0];

      int up = (y - 1) % height;
      // int down = (y + 1) % height;
      int left = (x - 1) % width;
      int right = (x + 1) % width;

      int mU = m.getCell(x, up);
      int mL = m.getCell(left, up);
      int mR = m.getCell(right, up);

      int cU = (getCell(right, y) - getCell(left, y)).abs();
      int cL = (getCell(x, up) - getCell(left, y)).abs() + cU;
      int cR = (getCell(x, up) - getCell(right, y)).abs() + cU;

      List<int> cULR = [cU, cL, cR];
      List<int> mULR = [mU, mL, mR] + cULR;

      int indMin = argmin(mULR);
      m.setCell(x, y, mULR[indMin]);

      energies[keyVal.index] = cULR[indMin];
    }
    return energies;
  }

  void setIndicesToValues(List<int> indices, List<int> values) {
    for (var keyVal in enumerate(indices)) {
      data[keyVal.value] = values[keyVal.index];
    }
  }

  void setIndicesToValue(List<int> indices, int value) {
    for (int index in indices) {
      data[index] = value;
    }
  }

  void increaseIndicesByValue(List<int> indices, int value, int max) {
    for (int index in indices) {
      int newVal = data[index] + value;
      data[index] = min(max, newVal);
    }
  }

  List<int> indicesCenterLeftAndRightOfSeams(
    List<List<List<int>>> seams, {
    right: true,
  }) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    int width = size().width;

    List<int> indices = [];

    for (List<List<int>> seam in seams) {
      for (List<int> coordYX in seam) {
        int y = coordYX[0];
        int x = coordYX[1];

        indices.add(index(x, y));

        if (x >= 1) {
          indices.add(index(x - 1, y));
        }

        if (right && x <= width - 2) {
          indices.add(index(x + 1, y));
        }
      }
    }

    return indices;
  }

  List<int> indicesCenterLeftAndPerhapsRightOfIndices(
    List<int> indices, {
    right: true,
  }) {
    if (rotation != 0) {
      throw UnimplementedError;
    }

    int width = size().width;

    List<int> newIndices = [];

    for (int i in indices) {
      List<int> coordXY = xyFromIndex(i);

      int x = coordXY[0];
      int y = coordXY[1];

      newIndices.add(index(x, y));

      if (x >= 1) {
        newIndices.add(index(x - 1, y));
      }

      if (right && x <= width - 2) {
        newIndices.add(index(x + 1, y));
      }
    }

    return newIndices;
  }

  void fillIndicesByInterpolation(List<int> indicesToFill, {penalty}) {
    int left;
    int right;
    int steps;

    List<int> curr = [];
    List<int> allVals = [];

    for (int index in indicesToFill) {
      // for (int ii = 0; ii < indicesToFill.length; ii++) {
      //   int index = indicesToFill[ii];
      var vars = xyFromIndex(index);
      int x = vars[0];
      // int y = vars[1];
      List<int> interpolates;

      if ((curr.length == 0 || index == curr[curr.length - 1] + 1 && x != 0)) {
        curr.add(index);
      } else {
        left = curr[0];
        right = curr[curr.length - 1];
        steps = curr.length;

        if (xyFromIndex(left)[0] == 0) {
          // not lefter pixels
          int fillVal = data[right + 1];
          interpolates = cycle([fillVal]).take(steps).toList();
        } else if (xyFromIndex(right)[0] == width - 1) {
          // no pixels to right
          int fillVal = data[left - 1];
          interpolates = cycle([fillVal]).take(steps).toList();
        } else {
          int leftVal = data[left - 1];
          int rightVal = data[right + 1];

          // print([leftVal, rightVal]);

          int delta = ((rightVal - leftVal) / (steps + 1)).round();

          interpolates =
              List.generate(steps, (step) => leftVal + (step + 1) * delta);
        }

        // data.setRange()

        // assert(curr.isNotEmpty);
        // assert(interpolates.isNotEmpty);

        enumerate(curr).forEach((element) {
          // print(interpolates[element.index]);
          var num = interpolates[element.index] + (penalty ?? 0);
          data[element.value] = min(255, num);
          // data[element.value] = 10;
        });

        // allVals.addAll(interpolates);

        curr = [index];
      }
    }
    // print(allVals.reduce((a, b) => a > b ? a : b));
  }

  Matrix2D<T> withExpandedAndInterpolatedSeams(
    List<List<List<int>>> seams, {
    penalty,
  }) {
    var vars = withExpandedSeams(seams);
    Matrix2D<T> newMatrix = vars[0];
    List<int> indicesToFill = vars[1];

    newMatrix.fillIndicesByInterpolation(indicesToFill, penalty: penalty);

    return newMatrix;
  }

  int seamsMax(List<List<List<int>>> seams) =>
      seams.map(seamMax).reduce((a, b) => a > b ? a : b);

  seamsSum(List<List<List<int>>> seams) => seams
      .map((seam) => seam
          .map((coordYX) => data[index(coordYX[1], coordYX[0])])
          .reduce((a, b) => a + b))
      .reduce((a, b) => a + b);

  int seamsMean(List<List<List<int>>> seams) {
    return seamsSum(seams) ~/
        seams
            .map((seam) => seam.length)
            .reduce((value, element) => value + element);
  }

  int seamMax(List<List<int>> seam) => seam
      .map((coordYX) => data[index(coordYX[1], coordYX[0])])
      .reduce((a, b) => a > b ? a : b);

  Matrix2D<T> meanWith(Matrix2D<T> other) {
    assert(width == other.width);
    assert(height == other.height);

    T newData = initializeData(data.length);

    count().take(data.length).forEach((i) {
      newData[i] = ((other.data[i] + data[i]) / 2).round();
      // newData[i] = (sqrt(other.data[i] * data[i])).round();
    });

    return Matrix2D<T>.fromData(width, height, newData);
  }
}

class MatrixCache {
  Map<Size2D, Matrix2D> cache;
  int minDelta;
  int maxValues;
  Size2D originalSize;

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

    Size2D closestSize = this.closestBiggerEqualSize(size);

    if (closestSize.totalDelta(size) < this.minDelta) {
      return false;
    }

    return true;
  }

  void add(Matrix2D matrix, {check: true}) {
    var matrixSize = matrix.size();
    if (!check || sizeShouldBeAdded(matrixSize)) {
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

  Size2D closestBiggerEqualSize(Size2D size) {
    List<Size2D> biggerSizes = this
        .cache
        .keys
        .where((element) => element.compareTo(size) >= 0)
        .toList();

    Size2D key = biggerSizes.reduce((curr, element) =>
        curr.totalDelta(size) <= element.totalDelta(size) ? curr : element);

    return key;
  }

  Matrix2D closestBiggerMatrix(Size2D size) {
    return this.cache[this.closestBiggerEqualSize(size)];
  }
}

T initializeData<T extends List<int>>(
  int length, [
  int fillValue,
]) {
  T data;

  switch (T) {
    // case List:
    //   {
    //     data = Uint32List(length) as T;
    //   }
    //   break;
    case Uint32List:
      {
        return fillValue == null
            ? Uint32List(length)
            : Uint32List.fromList(List.filled(length, fillValue)) as T;
        data = Uint32List(length) as T;
      }
      break;
    case Uint8List:
      {
        return fillValue == null
            ? Uint8List(length)
            : Uint8List.fromList(List.filled(length, fillValue)) as T;
        data = Uint8List(length) as T;
      }
      break;
    case Int8List:
      {
        return fillValue == null
            ? Int8List(length)
            : Int8List.fromList(List.filled(length, fillValue)) as T;
        data = Int8List(length) as T;
      }
      break;
    default:
      {
        throw UnimplementedError;
      }
      break;
  }

  // if (fillValue != null) {
  //   data.setAll(0, cycle([fillValue]));
  //   // data.setAll(0, List.filled(length, fillValue));
  // }
  //
  // return data;
}

T initializeDataFromList<T extends List<int>>(
  List<int> data,
) {
  switch (T) {
    case Uint32List:
      {
        return Uint32List.fromList(data) as T;
      }
      break;
    case Uint8List:
      {
        return Uint8List.fromList(data) as T;
      }
      break;
    case Int8List:
      {
        return Int8List.fromList(data) as T;
      }
      break;
    default:
      {
        throw UnimplementedError;
      }
      break;
  }
}

Matrix2D carveSeam(
  Matrix2D matrix,
  List<List<int>> seam, {
  ordered: false,
}) {
  return matrix.withCarvedSeam(seam, ordered: ordered);
}
