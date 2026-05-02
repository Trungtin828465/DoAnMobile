import 'dart:convert';

import 'package:vector_math/vector_math.dart';

class Vec3Data {
  const Vec3Data({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  factory Vec3Data.fromJson(Map<String, dynamic> json) {
    return Vec3Data(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      z: (json['z'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'z': z};
  }

  Vector3 toVector3() => Vector3(x, y, z);

  Vec3Data copyWith({double? x, double? y, double? z}) {
    return Vec3Data(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);
  }
}

class RoomBounds {
  const RoomBounds({
    required this.minX,
    required this.maxX,
    required this.minZ,
    required this.maxZ,
  });

  final double minX;
  final double maxX;
  final double minZ;
  final double maxZ;

  factory RoomBounds.fromJson(Map<String, dynamic> json) {
    return RoomBounds(
      minX: (json['minX'] as num?)?.toDouble() ?? -2,
      maxX: (json['maxX'] as num?)?.toDouble() ?? 2,
      minZ: (json['minZ'] as num?)?.toDouble() ?? -3,
      maxZ: (json['maxZ'] as num?)?.toDouble() ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {'minX': minX, 'maxX': maxX, 'minZ': minZ, 'maxZ': maxZ};
  }
}

class RoomConfig {
  const RoomConfig({required this.bounds, required this.eyeHeight});

  final RoomBounds bounds;
  final double eyeHeight;

  factory RoomConfig.fromJson(Map<String, dynamic> json) {
    return RoomConfig(
      bounds: RoomBounds.fromJson(
        (json['bounds'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      eyeHeight: (json['eyeHeight'] as num?)?.toDouble() ?? 1.6,
    );
  }

  Map<String, dynamic> toJson() {
    return {'bounds': bounds.toJson(), 'eyeHeight': eyeHeight};
  }
}

class LayoutObject {
  const LayoutObject({
    required this.id,
    required this.classId,
    required this.className,
    required this.asset,
    required this.position,
    required this.rotationEulerDeg,
    required this.scale,
  });

  final String id;
  final int classId;
  final String className;
  final String asset;
  final Vec3Data position;
  final Vec3Data rotationEulerDeg;
  final Vec3Data scale;

  factory LayoutObject.fromJson(Map<String, dynamic> json) {
    return LayoutObject(
      id: (json['id'] as String?) ?? 'unknown',
      classId: (json['classId'] as num?)?.toInt() ?? -1,
      className: (json['className'] as String?) ?? 'unknown',
      asset: (json['asset'] as String?) ?? '',
      position: Vec3Data.fromJson(
        (json['position'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      rotationEulerDeg: Vec3Data.fromJson(
        (json['rotationEulerDeg'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      scale: Vec3Data.fromJson(
        (json['scale'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'className': className,
      'asset': asset,
      'position': position.toJson(),
      'rotationEulerDeg': rotationEulerDeg.toJson(),
      'scale': scale.toJson(),
    };
  }

  LayoutObject copyWith({
    String? id,
    int? classId,
    String? className,
    String? asset,
    Vec3Data? position,
    Vec3Data? rotationEulerDeg,
    Vec3Data? scale,
  }) {
    return LayoutObject(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      asset: asset ?? this.asset,
      position: position ?? this.position,
      rotationEulerDeg: rotationEulerDeg ?? this.rotationEulerDeg,
      scale: scale ?? this.scale,
    );
  }
}

class LayoutData {
  const LayoutData({
    required this.version,
    required this.units,
    required this.room,
    required this.objects,
  });

  final int version;
  final String units;
  final RoomConfig room;
  final List<LayoutObject> objects;

  factory LayoutData.fromJson(Map<String, dynamic> json) {
    final objectJson = (json['objects'] as List?) ?? <dynamic>[];
    return LayoutData(
      version: (json['version'] as num?)?.toInt() ?? 1,
      units: (json['units'] as String?) ?? 'meters',
      room: RoomConfig.fromJson(
        (json['room'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      objects: objectJson
          .map(
            (entry) =>
                LayoutObject.fromJson((entry as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'units': units,
      'room': room.toJson(),
      'objects': objects.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  LayoutData copyWith({
    int? version,
    String? units,
    RoomConfig? room,
    List<LayoutObject>? objects,
  }) {
    return LayoutData(
      version: version ?? this.version,
      units: units ?? this.units,
      room: room ?? this.room,
      objects: objects ?? this.objects,
    );
  }
}
