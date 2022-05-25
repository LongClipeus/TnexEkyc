import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

class CaptureView extends StatefulWidget {
  const CaptureView(
      this.height,
      this.width,
      this.captureResults,
      this.captureError,
      {Key? key}
    ) : super(key: key);

  final int height;
  final int width;
  final Function(String) captureResults;
  final Function(String) captureError;

  @override
  State<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends State<CaptureView> {
  bool isPermission = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    checkPermission();
  }

  Future<void> checkPermission() async {
    PermissionStatus camera = await Permission.camera.request();
    PermissionStatus storage = await Permission.storage.request();

    if(camera.isGranted && storage.isGranted){
      setState(() {
        isPermission = true;
      });

      const EventChannel('tnex_capture_listener').receiveBroadcastStream()
          .listen(captureEvent);
    }else{
      widget.captureError("NO_PERMISSION");
    }
  }

  void captureEvent(dynamic event) {
    debugPrint("ekycEventBIENNT captureEvent lib $event");
    var eventType = event['eventType'];
    if(eventType == 'SUCCESS'){
      var imagePath = event['imagePath'];
      widget.captureResults(imagePath);
    }else{
      var errorType = event['errorType'];
      widget.captureError(errorType);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is used in the platform side to register the view.
    const String viewType = 'plugins.tnex.capture/camera';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    creationParams["height"] = widget.height;
    creationParams["width"] = widget.width;

    if (isPermission == true){
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