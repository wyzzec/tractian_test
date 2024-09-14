import 'component_entity.dart';
import 'node_type.dart';

class NodeEntity {
  final String id;
  final NodeType type;
  final String name;
  final List<NodeEntity>? nodes;
  final List<ComponentEntity>? components;

  const NodeEntity({
    required this.id,
    required this.type,
    required this.name,
    this.nodes,
    this.components,
  });
}
