import 'package:the_purple_alliance/util.dart';

import 'data_manager.dart';

abstract class SearchDataEmitter {
  int getMaxPoints(dynamic config);
  int getCurrentPoints(dynamic config);
  dynamic get defaultConfig;
}

extension RankableDatamanager on DataManager {
  /*
  (points, maxPoints)
   */
  Couple<int> getSearchRanking(Map<String, dynamic> config) {
    int points = 0;
    int maxPoints = 0;

    for (MapEntry<String, dynamic> entry in config.entries) {
      DataValue? val = values[entry.key];
      if (val is SearchDataEmitter) {
        SearchDataEmitter emitter = val as SearchDataEmitter;
        points += emitter.getCurrentPoints(entry.value);
        maxPoints += emitter.getMaxPoints(entry.value);
      }
    }

    return Couple.of(points, maxPoints);
  }

  double getSearchIndex(Map<String, dynamic> config) {
    Couple<int> ranking = getSearchRanking(config);
    return ranking.first / ranking.second;
  }
}

extension RankableTeamDataManager on TeamDataManager {
  /// 1st item is best team,
  /// 2nd item is 2nd best team,
  /// nth item is nth best team
  List<int> getRankedTeams(Map<String, dynamic> config) {
    List<int> teams = managers.keys.toList();
    teams.sort((a, b) {
      var managerA = managers[a]!;
      var managerB = managers[b]!;
      return managerA.getSearchIndex(config)
          .compareTo(managerB.getSearchIndex(config));
    });
    return teams.reversed.toList();
  }
}