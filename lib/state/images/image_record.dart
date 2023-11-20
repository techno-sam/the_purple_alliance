import 'package:flutter/material.dart';

class ImageRecord {
  final String uuid; //DONE hash bad, use uuid.
  final String author;
  final List<String> tags;
  final int team;

  ImageRecord(this.uuid, this.author, this.tags, this.team) {
    for (var character in uuid.characters) {
      if (!("0123456789abcdef".contains(character))) {
        throw "Illegal hash passed to image record, aborting";
      }
    }
  }

  bool tagsEqual(ImageRecord other) {
    tags.sort();
    other.tags.sort();
    if (tags.length != other.tags.length) {
      return false;
    }
    for (int i = 0; i < tags.length; i++) {
      if (tags[i] != other.tags[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ImageRecord) {
      return false;
    }
    return uuid == other.uuid && author == other.author && tagsEqual(other) && team == other.team;
  }

  static ImageRecord? fromJson(dynamic item) {
    if (item is Map<String, dynamic>) {
      var author = item['author'];
      var tags = item['tags'];
      var uuid = item['uuid'];
      var team = item['team'];
      if (author is String && tags is List && uuid is String && team is int) {
        return ImageRecord(uuid, author, tags.whereType<String>().toList(), team);
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'tags': tags,
      'uuid': uuid,
      'team': team
    };
  }

  @override
  int get hashCode {
    return Object.hash(uuid, author, tags, team);
  }
}