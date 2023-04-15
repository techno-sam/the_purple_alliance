import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

Future<R> compute2<R, A, B>(FutureOr<R> Function(A, B) callback, A arg1, B arg2) async {
  //log("Compute2 with arg types: ${callback.runtimeType}, ${arg1.runtimeType}, ${arg2.runtimeType}");
  return await compute((List<dynamic> args) async {
    //print("before calling callback");
    return await callback(args[0], args[1]);
  }, [arg1, arg2]);
}

Future<R> compute3<R, A, B, C>(FutureOr<R> Function(A, B, C) callback, A arg1, B arg2, C arg3) async {
  //log("Compute2 with arg types: ${callback.runtimeType}, ${arg1.runtimeType}, ${arg2.runtimeType}");
  return await compute((List<dynamic> args) async {
    //print("before calling callback");
    return await callback(args[0], args[1], args[2]);
  }, [arg1, arg2, arg3]);
}

class Pair<A, B> {
  late final A _first;
  A get first => _first;
  late final B _second;
  B get second => _second;

  Pair.of(A first, B second) {
    _first = first;
    _second = second;
  }
}

T typeOr<T>(dynamic val, T default_) {
  return (val is T) ? val : default_;
}

bool isCameraSupported() {
  return Platform.isIOS || Platform.isAndroid || kIsWeb;
}
