import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:image/image.dart' as imageLib;
import 'dart:math';

import 'package:quiver/iterables.dart';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

Future<File> fixExifRotation(String imagePath) async {
  final originalFile = File(imagePath);
  List<int> imageBytes = await originalFile.readAsBytes();

  final originalImage = img.decodeImage(imageBytes);

  final height = originalImage.height;
  final width = originalImage.width;

  // Let's check for the image size
  if (height >= width) {
    // I'm interested in portrait photos so
    // I'll just return here
    return originalFile;
  }

  // We'll use the exif package to read exif data
  // This is map of several exif properties
  // Let's check 'Image Orientation'
  final exifData = await readExifFromBytes(imageBytes);

  img.Image fixedImage;

  if (height < width) {
    // logger.logInfo('Rotating image necessary');
    print('Rotating image necessary');
    // rotate
    if (exifData['Image Orientation'].printable.contains('Horizontal')) {
      fixedImage = img.copyRotate(originalImage, 90);
    } else if (exifData['Image Orientation'].printable.contains('180')) {
      fixedImage = img.copyRotate(originalImage, -90);
    } else {
      fixedImage = img.copyRotate(originalImage, 0);
    }
  }

  // Here you can select whether you'd like to save it as png
  // or jpg with some compression
  // I choose jpg with 100% quality
  final fixedFile = await originalFile.writeAsBytes(img.encodeJpg(fixedImage));

  return fixedFile;
}

final _random = new Random();

/**
 * Generates a positive random integer uniformly distributed on the range
 * from [min], inclusive, to [max], exclusive.
 */
int randInt(int min, int max) => min + _random.nextInt(max - min);

reshape2(List<int> l, List<int> dims) {
  assert(dims.length == 2);

  int width = dims[1];

  List<List<int>> m = List.generate(
      dims[0], (i) => List.generate(dims[1], (j) => l[i * width] + j),
      growable: false);
  return m;
}

int boolToInt(bool b) => b ? 1 : 0;

getTempDir() async {
  Directory tempDir = await getTemporaryDirectory();
  String tempPath = tempDir.path;
}

imageLib.Image applyFilterAlt(Map<String, dynamic> params) {
  Filter filter = params["filter"];
  imageLib.Image image = params["image"];
  String filename = params["filename"];
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes, image.width, image.height);
  }
  imageLib.Image _image =
      imageLib.Image.fromBytes(image.width, image.height, _bytes);
  return _image;
}

void setImageBytes(imageBytes) {
  print("setImageBytes");
  List<int> values = imageBytes.buffer.asUint8List();
  imageLib.Image image = imageLib.decodeImage(values);
}

List<List<int>> fill2d(int height, int width, int elem) {
  return List.generate(height, (y) => List.generate(width, (x) => elem));
}

List<List<bool>> fill2dBool(int height, int width, bool elem) {
  return List.generate(height, (y) => List.generate(width, (x) => elem));
}

findmin(List l) {
  var ind = argmin(l);
  return [ind, l[ind]];
}

argminLe3(List l) {
  assert(l.length > 0);

  if (l.length == 1) {
    return 0;
  }

  int minOf2 = l[0] < l[1] ? 0 : 1;

  if (l.length == 2) {
    return minOf2;
  }

  return l[minOf2] < l[2] ? minOf2 : 2;
}

argmin(List l) {
  assert(l.length > 0);

  if (l.length == 1) return 0;

  var min = l[0];
  var ind = 0;

  for (int i = 1; i < l.length; i++) {
    if (l[i] < min) {
      min = l[i];
      ind = i;
    }
  }

  return ind;
}

range({int start: 0, int step: 1, int steps}) {
  if (steps == null) {
    return count(start, step);
  }

  return count(start, step).take(steps);
}

argmins(List l, int n) {
  assert(l.length >= n);
  assert(n >= 0);

  List<int> indices = List.generate(l.length, (index) => index);

  indices.sort((a, b) => l[a].compareTo(l[b]));

  return indices.take(n).toList();
}

//class ImageUtils {
//  File imagePlaceHolder;
//  _setPlaceHolder() async {
//    this.imagePlaceHolder = await ImageUtils.imageToFile(
//        imageName: "photo_placeholder", ext: "jpg");
//  }
//
//  ...
//  Image.file(this.imagePlaceHolder),
//}
