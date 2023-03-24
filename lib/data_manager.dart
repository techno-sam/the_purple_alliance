final Map<Type, DataValue Function()> valueTypes = {};

abstract class DataValue {
  int? _lastEdited;
  void Function() changeNotifer = () {};
  void fromJson(dynamic data);
  
  static dynamic load(Type t) {
    if (valueTypes.containsKey(t)) {
      return valueTypes[t]!();
    } else {
      throw "Type $t is not registered";
    }
  }

  dynamic toJson();

  void reset() {
    _lastEdited = null;
  }

  void markChange() {
    _lastEdited = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  void setChangeNotifier(void Function() changeNotifier) {
    changeNotifer = changeNotifier;
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
  valueTypes.clear();
  valueTypes[TextDataValue] = TextDataValue.new;
}

class DataManager {
  final Map<String, DataValue> values = {};

  void load(Map<String, dynamic>? data) {
    if (data != null) {
      for (MapEntry<String, DataValue> entry in values.entries) {
        if (data.containsKey(entry.key)) {
          entry.value.fromJson(data[entry.key]);
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
      data[entry.key] = entry.value.toJson();
    }
    return data;
  }
}

class TeamDataManager {
  final Map<int, DataManager> managers = {};

  DataManager getManager(int teamNumber) {
    if (managers.containsKey(teamNumber) && managers[teamNumber] != null) {
      return managers[teamNumber]!;
    } else {
      var manager = DataManager();
      managers[teamNumber] = manager;
      return manager;
    }
  }

  void load(Map<String, dynamic>? data) {
    if (data != null) {
      for (MapEntry<String, dynamic> entry in data.entries) {
        var teamNumber = int.tryParse(entry.key);
        if (teamNumber != null && (entry.value == null || entry.value is Map<String, dynamic>)) {
          var dataManager = DataManager();
          dataManager.load(entry.value);
          managers[teamNumber] = dataManager;
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
}