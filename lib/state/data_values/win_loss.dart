import 'package:the_purple_alliance/state/search_system.dart';
import 'package:the_purple_alliance/utils/util.dart';

import 'abstract_data_value.dart';

enum WinLossSearchOption {
  win("Win Points", "winValue"),
  loss("Loss Points", "lossValue"),
  tie("Tie Points", "tieValue")
  ;
  final String searchLabel;
  final String searchKey;

  const WinLossSearchOption(this.searchLabel, this.searchKey);
}

class WinLossDataValue extends DataValue implements SearchDataEmitter {
  int _wins = 0;
  int _losses = 0;
  int _ties = 0;


  int get wins => _wins;
  int get losses => _losses;
  int get ties => _ties;

  @override
  int get lastEdited => -1;
  @override
  @Deprecated("Read-only")
  set lastEdited(int _) => {};

  @override
  void fromJson(data) {
    if (data is Map<String, dynamic>) {
      _wins = data["wins"] ?? 0;
      _losses = data["losses"] ?? 0;
      _ties = data["ties"] ?? 0;
    } else {
      reset();
    }
  }

  @override
  bool get localChanges => false;

  @override
  void markChange() {}

  @override
  void reset() {
    _wins = 0;
    _losses = 0;
    _ties = 0;
  }

  @override
  toJson() => {
    "wins": _wins,
    "losses": _losses,
    "ties": _ties,
  };

  @override
  get defaultConfig => {
    "winValue": 1,
    "lossValue": -1,
    "tieValue": 0
  };

  @override
  int getCurrentPoints(config) {
    if (!(config is Map<String, dynamic> || (config is Map && config.isEffectively<String, int>()))) {
      return 0;
    }
    Map<String, dynamic> cfg = config;
    return (cfg["winValue"] ?? 0) * _wins
        + (cfg["lossValue"] ?? 0) * _losses
        + (cfg["tieValue"] ?? 0) * _ties;
  }

  @override
  int getMaxPoints(config) {
    return 1; // there is no max, but must emit at least 1 to prevent div-by-zero error
  }
}