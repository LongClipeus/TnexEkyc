
import 'dart:async';

import 'package:flutter/services.dart';

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
}
