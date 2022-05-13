
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
}
