final Map<Type, DataValue Function()> _valueTypes = {};

int _generateTimestamp() {
  return DateTime.now().toUtc().millisecondsSinceEpoch;
}

abstract class DataValue {
  int _lastEdited = -1;
  bool get _localChanges => _lastEdited != -1;
  void Function() changeNotifier = () {};
  void fromJson(dynamic data);
  
  static dynamic load(Type t) {
    if (_valueTypes.containsKey(t)) {
      return _valueTypes[t]!();
    } else {
      throw "Type $t is not registered";
    }
  }

  dynamic toJson();

  void reset() {
    _lastEdited = -1;
  }

  void markChange() {
    _lastEdited = _generateTimestamp();
  }

  void setChangeNotifier(void Function() changeNotifier) {
    this.changeNotifier = changeNotifier;
  }
}

class TextDataValue extends DataValue {

  String _value = "";

  @override
  void fromJson(dynamic data) {
    assert (data is String);
    _value = data;
  }

  @override
  toJson() {
    return _value;
  }

  @override
  void reset() {
    super.reset();
    _value = "";
  }

  static dynamic getDefault() {
    return "";
  }

  String get value => _value;

  set value(String value) {
    _value = value;
    markChange();
  }
}

void initializeValueHolders() {
  _valueTypes.clear();
  _valueTypes[TextDataValue] = TextDataValue.new;
}

class DataManager {
  final Map<String, DataValue> values = {};
  bool initialized = false;

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, DataValue> entry in values.entries) {
        if (data.containsKey(entry.key)) {
          var entryData = data[entry.key];
          if (entryData is Map<String, dynamic> && entryData.containsKey("value")) {
            if (entryData.containsKey("timestamp")) {
              var timestamp = entryData["timestamp"];
              if (timestamp is int) {
                if (timestamp > entry.value._lastEdited || fromDisk) {
                  entry.value.fromJson(entryData["value"]);
                  entry.value._lastEdited = fromDisk ? entryData["timestamp"] : -1;
                }
              } else if (fromDisk) {
                print("Invalid timestamp: $timestamp");
                entry.value.fromJson(entryData["value"]);
                entry.value._lastEdited = _generateTimestamp();
              }
            } else {
              entry.value.fromJson(entryData["value"]);
              entry.value._lastEdited = fromDisk ? _generateTimestamp() : -1;
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
        "timestamp": entry.value._lastEdited,
      };
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<String, DataValue> entry in values.entries) {
      if (entry.value._localChanges) {
        data[entry.key] = {
          "value": entry.value.toJson(),
          "timestamp": entry.value._lastEdited,
        };
      }
    }
    return data;
  }
}

class TeamDataManager {
  final Map<int, DataManager> managers = {};
  final void Function(DataManager) initializeManager;

  TeamDataManager(this.initializeManager);

  DataManager getManager(int teamNumber) {
    if (managers.containsKey(teamNumber) && managers[teamNumber] != null) {
      return managers[teamNumber]!;
    } else {
      var manager = DataManager();
      managers[teamNumber] = manager;
      return manager;
    }
  }

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, dynamic> entry in data.entries) {
        var teamNumber = int.tryParse(entry.key);
        if (teamNumber != null && (entry.value == null || entry.value is Map<String, dynamic>)) {
          var dataManager = managers.putIfAbsent(teamNumber, DataManager.new);
          if (!dataManager.initialized) {
            initializeManager(dataManager);
            dataManager.initialized = true;
          }
          dataManager.load(entry.value, fromDisk);
        }
      }
    } else {
      managers.clear();
    }
  }

  Map<String, dynamic> save() {
    Map<String, dynamic> data = {};
    for (MapEntry<int, DataManager> entry in managers.entries) {
      data["${entry.key}"] = entry.value.save();
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<int, DataManager> entry in managers.entries) {
      var deltas = entry.value.saveNetworkDeltas();
      if (deltas.isNotEmpty) {
        data["${entry.key}"] = deltas;
      }
    }
    return data;
  }
}