import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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

  T map<T>(T Function(A, B) mapper) {
    return mapper.call(first, second);
  }
}

class Couple<T> extends Pair<T, T> {
  Couple.of(super.first, super.second) : super.of();
}

class Triple<A, B, C> {
  late final A _first;
  A get first => _first;
  late final B _second;
  B get second => _second;
  late final C _third;
  C get third => _third;

  Triple.of(A first, B second, C third) {
    _first = first;
    _second = second;
    _third = third;
  }
}

T typeOr<T>(dynamic val, T default_) {
  return (val is T) ? val : default_;
}

bool isCameraSupported() {
  return Platform.isIOS || Platform.isAndroid || kIsWeb;
}

extension MapExtension<K, V> on Map<K, V> {
  void put(K key, V value) {
    this[key] = value;
  }

  V? get(K key) {
    return this[key];
  }
}

double roundDouble(double value, int places){
  num mod = pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}


/// Returns the problem with the url if there is one, or null if the url is OK
String? verifyServerUrl(String url) {
  var tmp = Uri.tryParse(url);
  if (tmp == null) {
    return "Failed to parse url";
  }
  if (!tmp.isScheme("https")) { //just don't verify scheme temporarily
    return "Invalid scheme for server: ${tmp.scheme.isEmpty ? "[Blank]" : tmp.scheme}. Must be 'https'.";
  }
  return null;
}

int generateTimestamp() {
  return DateTime.now().toUtc().millisecondsSinceEpoch;
}

String makeUUID() {
  return const Uuid().v4().replaceAll("-", "").replaceAll("_", "");
}

extension All<T> on Iterable<T> {
  bool all(bool Function(T) test) {
    for (T element in this) {
      if (!test(element)) return false;
    }
    return true;
  }
}

extension EffectiveType<A, B> on Map<A, B> {
  bool isEffectively<K, V>() {
    if (K == A && V == B) {
      return true;
    }
    return entries.all((e) => e.key is K && e.value is V);
  }
}