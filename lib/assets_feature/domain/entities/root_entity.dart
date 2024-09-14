import 'package:tractian_test/assets_feature/domain/entities/component_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_entity.dart';

class RootEntity {

  final List<NodeEntity> nodes;
  final List<ComponentEntity> components;

  const RootEntity({
    required this.nodes,
    required this.components,
  });
}