import 'dart:developer';

import 'package:the_purple_alliance/utils/util.dart';

import 'data_values/abstract_data_value.dart';

class TeamSpecificDataManager {
  final Map<String, DataValue> values = {};
  bool initialized = false;

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, DataValue> entry in values.entries) {
        if (data.containsKey(entry.key)) {
          var entryData = data[entry.key];
          if (entryData is Map<String, dynamic> && entryData.containsKey("value")) {
            bool specialTimestampHandling = entry.value is TimestampSpecialBehaviorMixin;
            if (entryData.containsKey("timestamp")) {
              var timestamp = entryData["timestamp"];
              if (timestamp is int) {
                if (timestamp >= entry.value.lastEdited || fromDisk) {
                  var keepTimestamp = false;
                  if (specialTimestampHandling) {
                    keepTimestamp = (entry.value as TimestampSpecialBehaviorMixin).fromJsonSpecial(entryData["value"], true, fromDisk); // local is always old because of the above check
                  } else {
                    entry.value.fromJson(entryData["value"]);
                  }
                  if (!keepTimestamp || fromDisk) {
                    entry.value.lastEdited = fromDisk ? entryData["timestamp"] : -1;
                  }
                }
              } else if (fromDisk) {
                log("Invalid timestamp: $timestamp");
                if (specialTimestampHandling) {
                  (entry.value as TimestampSpecialBehaviorMixin).fromJsonBackup(entryData["value"], fromDisk);
                } else {
                  entry.value.fromJson(entryData["value"]);
                }
                entry.value.lastEdited = generateTimestamp();
              }
            } else {
              var keepTimestamp = false;
              if (specialTimestampHandling) {
                keepTimestamp = (entry.value as TimestampSpecialBehaviorMixin).fromJsonBackup(entryData["value"], fromDisk);
              } else {
                entry.value.fromJson(entryData["value"]);
              }
              if (!keepTimestamp || fromDisk) { // don't care what the data value asks, if we have no timestamp set yet, and we are loading from disk, it should be set to the current time
                entry.value.lastEdited = fromDisk ? generateTimestamp() : -1;
              }
            }
          } else {
            entry.value.reset();
          }
        } else {
          entry.value.reset();
        }
      }
    } else {
      for (DataValue value in values.values) {
        value.reset();
      }
    }
  }

  Map<String, dynamic> save() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      data[entry.key] = {
        "value": entry.value.toJson(),
        "timestamp": entry.value.lastEdited,
      };
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      if (entry.value.localChanges) {
        data[entry.key] = {
          "value": entry.value.toJson(),
          "timestamp": entry.value.lastEdited,
        };
      }
    }
    return data;
  }
}