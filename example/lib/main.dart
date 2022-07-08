import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tnexekyc/capture_camera_view.dart';

import 'package:tnexekyc/tnexekyc.dart';
import 'package:tnexekyc_example/ekyc.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: "My Demo Media Query",
      home: HomeApp(),
    );
  }
}

class HomeApp extends StatefulWidget {
  const HomeApp({Key? key}) : super(key: key);

  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> {
  @override
  void initState() {
    super.initState();
  }

  void captureResults(String imagePath) {
    debugPrint("ekycEventBIENNT ekycResults Main $imagePath");
    Tnexekyc.onStopCamera();
    _showCaptureDialog(imagePath);
  }

  void captureError(String detectType){
    Tnexekyc.onStopCamera();
    _showMyDialog("Lỗi chụp ảnh", "Ảnh chụp của bạn có vấn đề, bạn vui lòng thử lại.");
  }

  Future<void> _showMyDialog(String title, String mess) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(mess)
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Tnexekyc.onStartCamera();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCaptureDialog(String path) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("HIHI"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Image.file(
                  File(path),
                  width: 200,
                  fit: BoxFit.fitWidth,
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EkycView()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double hCamera = 2*width/3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.only(left: 30.0, right: 30.0, bottom: 30.0, top: 60.0),
          color: const Color(0xff000000),
          height: hCamera,
          width: width - 60,
          child: CaptureView(hCamera.round(), width.round() - 60, captureResults, captureError),
        ),
        TextButton(
          child: const Text('Capture'),
          onPressed: () {
            Tnexekyc.onCapture();
          },
        ),
      ],),
    );
  }
}
