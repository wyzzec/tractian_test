import 'package:tractian_test/assets_feature/domain/entities/sensor_type.dart';

import 'status.dart';

class ComponentEntity {
  final String name;
  final Status status;
  final SensorType sensorType;

  const ComponentEntity({
    required this.name,
    required this.status,
    required this.sensorType,
  });

}
