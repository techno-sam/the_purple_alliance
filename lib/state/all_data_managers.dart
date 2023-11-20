import 'data_values/text.dart';
import 'team_specific_data_manager.dart';

class AllDataManagers {
  final Map<int, TeamSpecificDataManager> managers = {};
  final void Function(TeamSpecificDataManager) initializeManager;

  AllDataManagers(this.initializeManager);

  TeamSpecificDataManager getManager(int teamNumber) {
    if (managers.containsKey(teamNumber) && managers[teamNumber] != null) {
      return managers[teamNumber]!;
    } else {
      var manager = TeamSpecificDataManager();
      managers[teamNumber] = manager;
      return manager;
    }
  }

  void load(Map<String, dynamic>? data, bool fromDisk) {
    if (data != null) {
      for (MapEntry<String, dynamic> entry in data.entries) {
        var teamNumber = int.tryParse(entry.key);
        if (teamNumber != null && (entry.value == null || entry.value is Map<String, dynamic>)) {
          var dataManager = managers.putIfAbsent(teamNumber, TeamSpecificDataManager.new);
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
    for (MapEntry<int, TeamSpecificDataManager> entry in managers.entries) {
      data["${entry.key}"] = entry.value.save();
    }
    return data;
  }

  Map<String, dynamic> saveNetworkDeltas() {
    Map<String, dynamic> data = {};
    for (MapEntry<int, TeamSpecificDataManager> entry in managers.entries) {
      var deltas = entry.value.saveNetworkDeltas();
      if (deltas.isNotEmpty) {
        data["${entry.key}"] = deltas;
      }
    }
    return data;
  }

  String getTeamName(int team) {
    TeamSpecificDataManager? manager = managers[team];
    if (manager != null) {
      var name = manager.values["name"];
      if (name is TextDataValue) {
        return name.value;
      }
    }
    return "Unknown Team";
  }
}