import 'abstract_data_value.dart';

class CommentsDataValue extends DataValue with TimestampSpecialBehaviorMixin {
  String? _personalComment;
  String? get personalComment => _personalComment;
  set personalComment(String? value) {
    _personalComment = value;
    markChange();
  }

  Map<String, dynamic> otherComments = {};

  Map<String, String> get stringComments {
    Map<String, String> out = {};
    otherComments.forEach((key, value) {
      if (value is String) {
        out[key] = value;
      }
    });
    return out;
  }

  CommentsDataValue();

  @override
  void fromJson(data) {
    assert (data is Map<String, dynamic>);
    _personalComment = data["personal_comment"];
    otherComments = data["other_comments"];
  }

  @override
  bool fromJsonSpecial(dynamic data, bool localOld, bool fromDisk) {
    assert (data is Map<String, dynamic>);
    // we always set the other comments, since those is server-provided
    // we only set the personal comment if it is newer than the local value, or if the local value does not exist
    otherComments = data["other_comments"];
    if (localOld || _personalComment == null) {
      _personalComment = data["personal_comment"];
      return false; // data is now completely from the server, update timestamp to match
    }
    return true; // our data is still potentially unique, keep the timestamp
  }

  @override
  bool fromJsonBackup(dynamic data, bool fromDisk) {
    fromJson(data);
    return false; // data is now completely from the server, update timestamp to match
  }

  @override
  toJson() {
    return {
      "personal_comment": _personalComment,
      "other_comments": otherComments, // this is, of course, ignored by the server, but it is needed to save to disc locally
    };
  }

  static String getDefault() {
    return "";
  }
}