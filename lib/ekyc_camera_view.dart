import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tnexekyc/tnexekyc.dart';

class CameraView extends StatefulWidget {
  const CameraView(
      this.height,
      this.width,
      this.detectType,
      this.ekycResults,
      this.ekycStartDetectType,
      {Key? key}
    ) : super(key: key);

  final int height;
  final int width;
  final List<String> detectType;
  final Function(Map<dynamic, dynamic>) ekycResults;
  final Function(String) ekycStartDetectType;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool isPermission = false;
  bool isPauseCamera = false;
  dynamic eventEkyc;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    checkPermission();
  }



  @override
  void activate(){
    super.activate();
    debugPrint("BienNT CaptureView CameraView activate");
  }

  @override
  void dispose(){
    super.dispose();
    debugPrint("BienNT CaptureView CameraView dispose");
    if(eventEkyc != null){
      eventEkyc.cancel();
    }

    Tnexekyc.onStopEkyc();
  }

  @override
  void deactivate(){
    super.deactivate();
    debugPrint("BienNT CaptureView CameraView deactivate");
  }

  Future<void> checkPermission() async {
    PermissionStatus camera = await Permission.camera.request();
    PermissionStatus storage = await Permission.storage.request();

    if(camera.isGranted && storage.isGranted){
      setState(() {
        isPermission = true;
      });

      eventEkyc = const EventChannel('tnex_ekyc_listener').receiveBroadcastStream()
          .listen(ekycEvent);
    }else{
      var event = <dynamic, dynamic>{
        'eventType': "NO_PERMISSION",
      };

      widget.ekycResults(event);
    }
  }

  void ekycEvent(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    debugPrint("ekycEventBIENNT ekycEvent lib $event");
    var eventType = event['eventType'];
    if(eventType == 'START_DETECTION'){
      var detectType = event['detectionType'];
      widget.ekycStartDetectType(detectType);
    }else{
      widget.ekycResults(map);
    }
  }


  @override
  Widget build(BuildContext context) {
    // This is used in the platform side to register the view.
    const String viewType = 'plugins.tnex.ekyc/camera';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    creationParams["height"] = widget.height;
    creationParams["width"] = widget.width;
    creationParams["detectType"] = widget.detectType;
    debugPrint('ekycEvent build detectType = ${widget.detectType}');

    if (isPermission == true && isPauseCamera == false){
      if (defaultTargetPlatform == TargetPlatform.android) {
        return AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      }

      return UiKitView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return Container(
      color: const Color(0xff000000),
      height: widget.height.toDouble(),
      width: widget.width.toDouble(),
    );

  }
}