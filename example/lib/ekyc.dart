import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tnexekyc/ekyc_camera_view.dart';

import 'package:tnexekyc/tnexekyc.dart';
import 'package:video_player/video_player.dart';

class EkycView extends StatefulWidget {
  const EkycView({Key? key}) : super(key: key);

  @override
  State<EkycView> createState() => _EkycViewState();
}

class _EkycViewState extends State<EkycView> {
  String selectType = '';
  List<String> detectType = [];
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    setState(() {
      detectType = ["blink_eye", "smile", "turn_right", "turn_left"];
    });
  }


  String getTitle(String eventType) {
    switch (eventType) {
      case 'NO_PERMISSION':
        return 'Không có quyền';
      case 'FAILED':
        return 'Nhận diện lỗi';
      case 'LOST_FACE':
        return 'Khuôn mặt không tốt';
      case 'DETECTION_EMPTY':
        return 'Không có danh sách nhận diện';
      case 'MULTIPLE_FACE':
        return 'Nhiều khuôn mặt';
      case 'SUCCESS':
        return 'Nhận diện thành công';
      case 'FAKE_FACE':
        return 'Khuôn mặt ảo';
      case 'NO_FACE':
        return 'Không có khuôn mặt';
      default:
        return '';
    }
  }

  String getMss(String eventType) {
    switch (eventType) {
      case 'NO_PERMISSION':
        return 'Không có quyền truy cập bộ nhớ hoặc camera. Bạn vui lòng cấp quyền và thử lại';
      case 'FAILED':
        return 'Nhận diện khuôn mặt xảy ra lỗi, bạn vui lòng thử lại';
      case 'LOST_FACE':
        return 'Khuôn mặt của bạn có vấn đề, bạn vui lòng thử lại';
      case 'DETECTION_EMPTY':
        return 'Không có danh sách nhận diện, bạn vui lòng thử lại';
      case 'MULTIPLE_FACE':
        return 'Nhiều hơn 1 khuôn mặt. Bạn vui lòng chỉ giữ 1 khuôn mặt khi nhận diện';
      case 'SUCCESS':
        return 'Nhận diện thành công. Bạn có muốn thử lại';
      case 'FAKE_FACE':
        return 'Có vẻ đây không phải 1 khuôn mặt thật. Bạn vui lòng thử lại';
      case 'NO_FACE':
        return 'Không tìm thấy khuôn mặt của bạn. Bạn vui lòng thử lại';
      default:
        return '';
    }
  }

  Future<double> getFileSize(String filePath) async {
    final file = File(filePath);
    int sizeInBytes = file.lengthSync();
    double sizeInMb = sizeInBytes / (1024 * 1024);
    return sizeInMb;
  }

  Future<void> compressVideo(String imagePath, String videoPathUpload) async {
    String mediaPath = videoPathUpload;
    var videoSize = await getFileSize(mediaPath);
    debugPrint("addKYCDocument videoPathUpload = $mediaPath");
    debugPrint("addKYCDocument videoSize = $videoSize");
    try{
      String? newPath = await Tnexekyc.compressVideo(videoPathUpload,
          quality: VideoQuality.MediumQuality);
      debugPrint("addKYCDocument newPath =  $newPath");

      if(newPath != null && newPath.isNotEmpty){
        videoSize = await getFileSize(newPath);
        if(videoSize > 0){
          mediaPath = newPath;
        }
        debugPrint("addKYCDocument videoNewSize = $videoSize");
      }
    }catch(err){
      debugPrint("addKYCDocument compressVideo err ${err.toString()}");
    }


    _controller = VideoPlayerController.file(File(mediaPath))
      ..initialize().then((_) {
        debugPrint("addKYCDocument VideoPlayerController initialize");
        _ekycDoneDialog("EKYC", "EKYC SUCCESS" , imagePath);
      });
  }

  void ekycResults(Map<dynamic, dynamic> map) {
    debugPrint("ekycEventBIENNT ekycResults Main $map");
    Tnexekyc.onStopEkyc();
    var eventType = map['eventType'];
    if(eventType == "SUCCESS"){
      var videoPathUpload =  map['videoPath'];
      String imagePath = map[detectType[detectType.length - 1]];
      compressVideo(imagePath, videoPathUpload);
    }else{
      var title = getTitle(eventType);
      var mss = getMss(eventType);
      _showMyDialog(title, mss);
    }
  }

  void ekycStartDetectType(String detectType){
    debugPrint("ekycEventBIENNT detectType $detectType");
    setState(() {
      selectType = detectType;
    });
  }

  Future<void> _ekycDoneDialog(String title, String mess, String imagePath) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(mess),
                Image.file(
                  File(imagePath),
                  height: 50,
                  fit: BoxFit.fitHeight,
                ),
                SizedBox(width: 200,child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),),
                TextButton(
                  child: const Text('Playvideo'),
                  onPressed: () {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
                Tnexekyc.onStartEkyc();
              },
            ),
          ],
        );
      },
    );
  }

  List<String> randomListDetectType(){
    List<String> detectType = ["turn_right", "blink_eye", "turn_left", "smile"];
    List<String> listType =[];
    Random random = Random();
    while(listType.length<4){
      int randomNumber = random.nextInt(4);
      String type = detectType[randomNumber];
      debugPrint('randomListDetectType randomNumber = $randomNumber type = $type');
      if (!listType.contains(type)){
        listType.add(type);
      }
    }

    debugPrint('randomListDetectType listType = $listType');

    return listType;
  }


  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double hCamera = width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Column(children: [
        SizedBox(
          width: width,
          height: 100,
          child: Row(children: [
            const Spacer(flex: 1,),
            Text(detectType[0], style: TextStyle(color: selectType == detectType[0] ? const Color(
                0xff00d178) : const Color(0xff000000)),),
            const Spacer(flex: 1,),
            Text(detectType[1], style: TextStyle(color: selectType == detectType[1] ? const Color(
                0xff00d178) : const Color(0xff000000)),),
            const Spacer(flex: 1,),
            Text(detectType[2], style: TextStyle(color: selectType == detectType[2] ? const Color(
                0xff00d178) : const Color(0xff000000)),),
            const Spacer(flex: 1,),
            Text(detectType[3], style: TextStyle(color: selectType == detectType[3] ? const Color(
                0xff00d178) : const Color(0xff000000)),),
            const Spacer(flex: 1,),
          ],
            mainAxisAlignment: MainAxisAlignment.center,
          ),),
        Expanded(flex:1,child: Container(
          color: const Color(0xff000000),
          height: height,
          width: width,
          child: detectType.isEmpty ? null : CameraView(hCamera.round(), width.round(), detectType, ekycResults, ekycStartDetectType),
        ),),
        Container(
          margin: EdgeInsets.only(left: 45, right: 45, bottom: 60),
          padding: EdgeInsets.all(33),
          decoration: BoxDecoration(
              boxShadow: const [
                BoxShadow(
                    color: Color(0xff14C8FA),
                    blurRadius: 1,
                    spreadRadius: 1)
              ],
              color: const Color(0xff000A41),
              borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 10,),
              const SizedBox(
                height: 5,
              ),
              Container(
                height: 10,)
            ],
          ),
        )
      ],),
    );
  }
}
