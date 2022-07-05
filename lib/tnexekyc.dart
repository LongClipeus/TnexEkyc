
import 'dart:async';

import 'package:flutter/services.dart';

enum VideoQuality {
  DefaultQuality,
  LowQuality,
  MediumQuality,
  HighestQuality,
  Res640x480Quality,
  Res960x540Quality,
  Res1280x720Quality,
  Res1920x1080Quality
}

class Tnexekyc {
  static const MethodChannel _channel = MethodChannel('tnexekyc');

  static onStartEkyc(){
    _channel.invokeMethod('onStartEkyc');
  }

  static onStopEkyc(){
    _channel.invokeMethod('onStopEkyc');
  }

  static onStartCamera(){
    _channel.invokeMethod('onStartCamera');
  }

  static onStopCamera(){
    _channel.invokeMethod('onStopCamera');
  }

  static onCapture(){
    _channel.invokeMethod('onCapture');
  }

  static Future<String?> compressVideo(
      String path, {
        VideoQuality quality = VideoQuality.DefaultQuality,
      }) async {

    final jsonStr = await _channel.invokeMethod('compressVideo', {
      'path': path,
      'quality': quality.index,
    });

    return jsonStr;
  }
}
