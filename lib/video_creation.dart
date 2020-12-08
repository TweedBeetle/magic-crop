import 'dart:io';

import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:gallery_saver/gallery_saver.dart';

final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();

Future<void> videoFromImageFolder(
  String folderPath,
  String filenameBase,
  String filenameSuffix,
  String outputPath, {
  double fps: 5,
  saveInGallery: true,
}) async {
  String input = folderPath + '/' + filenameBase + "%d" + filenameSuffix;
  // print(input);
  print('-------------------------------');
  print(fps);
  print(folderPath);
  print(Directory(folderPath).listSync());

  // int height = 1920;
  // int width = 1920;
  // int height = 1580;
  // int width = 1580;
  int height = 1380;
  int width = 1380;
  // int height = 1080;
  // int width = 1080;
  // int height = 720;
  // int width = 720;

  var command =
      '-r $fps -start_number 0 -i "$input" -vf "scale=\'if(gt(a,$height/$width),$height,-1)\':\'if(gt(a,$height/$width),-1,$width)\':eval=frame,pad=$height:$width:(ow-iw)/2:(oh-ih)/2" -r 30 -y "$outputPath"';
      // '-r $fps -start_number 0 -i "$input" -vf "color=white:scale=\'if(gt(a,$height/$width),$height,-1)\':\'if(gt(a,$height/$width),-1,$width)\':eval=frame,pad=$height:$width:(ow-iw)/2:(oh-ih)/2" -r 30 -y "$outputPath"';
      // '-r $fps -start_number 0 -i "$input" -vcodec libx265 -vf "scale=\'if(gt(a,$height/$width),$height,-1)\':\'if(gt(a,$height/$width),-1,$width)\':eval=frame,pad=$height:$width:(ow-iw)/2:(oh-ih)/2" -r 30 -y "$outputPath"';
  print(command);

  // return;
  await _flutterFFmpeg
      .execute(command)
      .then((rc) => print("FFmpeg process exited with rc $rc"));

  if (saveInGallery) {
    GallerySaver.saveVideo(outputPath);
  }
}
