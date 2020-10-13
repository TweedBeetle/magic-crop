import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as im;

void main() => runApp(MyApp());class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Image from assets"),
        ),
        body: Image.asset('assets/images/jellyfish.bmp'), //   <-- image
      ),
    );
  }
}
