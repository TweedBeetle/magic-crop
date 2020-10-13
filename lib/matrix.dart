import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:image/image.dart' as imageLib;

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

  Size2D inverted () {
    return Size2D(width, height);
  }

  @override
  String toString() => '<Size ($height, $width)>';

  Size2D operator -(Size2D other) {
    return Size2D(this.height - other.height, this.width - other.width);
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

  int total() => height + width;
}

class Sizeable2D {
  Size2D size() {}
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
        data = Uint32List(length) as T;
      }
      break;
    case Uint8List:
      {
        data = Uint8List(length) as T;
      }
      break;
    case Int8List:
      {
        data = Int8List(length) as T;
      }
      break;
    default:
      {
        throw UnimplementedError;
      }
      break;
  }

  if (fillValue != null) {
    data.setAll(0, List.filled(length, fillValue));
  }

  return data;
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

class Matrix2D<T extends List<int>> implements Sizeable2D {
  int width;

  int height;

  final T data;

  int rotation = 0; //clockwise

  Matrix2D(this.width, this.height, [int fillValue])
      : data = initializeData<T>(width * height, fillValue),
        rotation = 0 {
    assert(width * height == data.length);
  }

  /// Create a copy of the image [other].
  Matrix2D.from(Matrix2D other)
      : width = other.width,
        height = other.height,
        data = other.data.sublist(0),
        rotation = other.rotation;

  Matrix2D.fromImage(imageLib.Image image)
      : width = image.width,
        height = image.height,
        data =
            initializeDataFromList<T>(Int32List.view(image.getBytes().buffer)),
        rotation = 0 {
    assert(data.length == image.data.length);
  }

  Matrix2D.fromData(
    int width,
    int height,
    List<int> data,
  )   : width = width,
        height = height,
        data = data is T ? data : initializeDataFromList<T>(data);

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
  }

  void pseudoRotateLeft() {
    assert(rotation != -1);
    rotation -= 1;
    _switchHeightAndWidth();
  }

  int operator [](int index) => data[index];

  void operator []=(int index, int color) {
    data[index] = color;
  }

  int index(int x, int y) {

    switch (rotation) {
      case 0: {
        return y * width + x;
      }
      case 1: {
        int newX = y;
        int newY = width - x - 1;
        return newY * height + newX;
      }
      case -1: {
        int newY = x;
        int newX = height - y - 1;
        return newY * height + newX;
      }
      default: {
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

  Matrix2D<T> carveIndices(
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
      int insertStart = lastInsertEnd + 0;
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

  Matrix2D<T> carveSeams(
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

    return carveIndices(indices, ordered: false);
  }

  Matrix2D<T> carveSeam(
    List<List<int>> seam, {
    ordered: false,
  }) {
    List<int> indices =
        seam.map((coordYX) => this.index(coordYX[1], coordYX[0])).toList();

    return carveIndices(indices, ordered: ordered);
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

  @override
  String toString() {
    return (List.generate(height, (y) => getRow(y))).join('\n');
  }
}

Matrix2D carveSeam(
  Matrix2D matrix,
  List<List<int>> seam, {
  ordered: false,
}) {
  return matrix.carveSeam(seam, ordered: ordered);
}
