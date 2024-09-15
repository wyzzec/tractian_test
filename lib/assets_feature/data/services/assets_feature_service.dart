import 'dart:developer';
import 'package:tractian_test/assets_feature/data/datasources/assets_remote_datasource.dart';
import 'package:tractian_test/assets_feature/domain/entities/company_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_type.dart';
import 'package:tractian_test/assets_feature/domain/entities/sensor_type.dart';
import '../../domain/entities/component_entity.dart';
import '../../domain/entities/status.dart';
import 'package:tractian_test/assets_feature/domain/entities/root_entity.dart';

import 'isolate_service.dart';

abstract class IAssetsFeatureService {
  Future<List<CompanyEntity>> fetchCompanies();

  Future<RootEntity> fetchNodes(String companyId);
}

final class AssetsFeatureService implements IAssetsFeatureService {
  final IAssetsRemoteDatasource _remoteDatasource;

  const AssetsFeatureService(this._remoteDatasource);

  @override
  Future<List<CompanyEntity>> fetchCompanies() async {
    try {
      final companiesData = await _remoteDatasource.fetchCompanies();
      return companiesData.map((map) => _mapToCompanyEntity(map)).toList();
    } catch (e, s) {
      log('Error fetching companies in AssetsFeatureService\n$e\n$s');
      rethrow;
    }
  }

  @override
  Future<RootEntity> fetchNodes(String companyId) async {
    try {
      final List<Map<String, dynamic>> locationsData =
          await _remoteDatasource.fetchLocations(companyId);
      final List<Map<String, dynamic>> assetsData =
          await _remoteDatasource.fetchAssets(companyId);

      final Map<String, NodeEntity> locationMap = {};

      final RootEntity processedRootEntity = await runIsolate<RootEntity>(
        () async {
          final List<NodeEntity> nodes =
              _processLocations(locationsData, locationMap);
          final rootEntity = RootEntity(nodes: nodes, components: []);
          _processAssets(assetsData, rootEntity);
          return rootEntity;
        },
      );

      return processedRootEntity;
    } catch (e, s) {
      log('Error fetching nodes in AssetsFeatureService\n$e\n$s');
      rethrow;
    }
  }

  CompanyEntity _mapToCompanyEntity(Map<String, dynamic> map) {
    return CompanyEntity(id: map[kId], name: map[kName]);
  }

  static ComponentEntity _mapToComponentEntity(Map<String, dynamic> map) {
    Status status;
    SensorType sensorType;
    if (map[kStatus] == kOperating) {
      status = Status.operating;
    } else {
      status = Status.alert;
    }

    if (map[kSensorType] == kVibration) {
      sensorType = SensorType.vibration;
    } else {
      sensorType = SensorType.energy;
    }
    return ComponentEntity(
        name: map[kName] as String, status: status, sensorType: sensorType);
  }

  static List<NodeEntity> _processLocations(
      List<Map<String, dynamic>> locationsData,
      Map<String, NodeEntity> locationMap) {
    final List<Map<String, dynamic>> orphanedLocations = [];
    final List<NodeEntity> nodes = [];

    for (Map<String, dynamic> location in locationsData) {
      final NodeEntity node = NodeEntity(
        id: location[kId],
        type: NodeType.location,
        name: location[kName],
        nodes: [],
        components: [],
      );

      locationMap[location[kId]] = node;

      if (_hasParent(location)) {
        final String parentId = location[kParentId];
        if (locationMap.containsKey(parentId)) {
          locationMap[parentId]?.nodes?.add(node);
        } else {
          orphanedLocations.add(location);
        }
      } else {
        nodes.add(node);
      }
    }

    _resolveOrphanedLocations(orphanedLocations, nodes);
    return nodes;
  }

  static void _processAssets(
      List<Map<String, dynamic>> assetsData, RootEntity rootEntity) {
    final List<Map<String, dynamic>> orphanedAssets = [];
    final List<Map<String, dynamic>> orphanedComponents = [];

    for (Map<String, dynamic> asset in assetsData) {
      if (_isComponent(asset)) {
        final ComponentEntity component = _mapToComponentEntity(asset);
        final String? parentId = asset[kParentId] ?? asset[kLocationId];

        if (parentId != null) {
          NodeEntity? parentNode =
              _findParentNodeInTree(rootEntity.nodes, parentId);
          if (parentNode != null) {
            parentNode.components?.add(component);
          } else {
            orphanedComponents.add(asset);
          }
        } else {
          rootEntity.components.add(component);
        }
      } else {
        _processAssetWithoutComponent(asset, rootEntity, orphanedAssets);
      }
    }

    _resolveOrphanedAssets(orphanedAssets, rootEntity);
    _resolveOrphanedComponents(orphanedComponents, rootEntity);
  }

  static void _processAssetWithoutComponent(Map<String, dynamic> asset,
      RootEntity rootEntity, List<Map<String, dynamic>> orphanedAssets) {
    final node = NodeEntity(
      id: asset[kId],
      type: NodeType.asset,
      name: asset[kName],
      nodes: [],
      components: [],
    );

    final String? parentId = asset[kParentId] ?? asset[kLocationId];
    if (parentId != null) {
      NodeEntity? parentNode =
          _findParentNodeInTree(rootEntity.nodes, parentId);
      if (parentNode != null) {
        parentNode.nodes?.add(node);
      } else {
        orphanedAssets.add(asset);
      }
    } else {
      rootEntity.nodes.add(node);
    }
  }

  static void _resolveOrphanedLocations(
      List<Map<String, dynamic>> orphanedLocations, List<NodeEntity> nodes) {
    bool hasResolvedAnyLocation = true;

    while (hasResolvedAnyLocation) {
      hasResolvedAnyLocation = false;
      final List<Map<String, dynamic>> unresolvedLocations = [];

      for (Map<String, dynamic> orphanedLocation in orphanedLocations) {
        final String parentId = orphanedLocation[kParentId];
        NodeEntity? parentNode = _findParentNodeInTree(nodes, parentId);
        if (parentNode != null) {
          final NodeEntity node = NodeEntity(
            id: orphanedLocation[kId],
            type: NodeType.location,
            name: orphanedLocation[kName],
            nodes: [],
            components: [],
          );
          parentNode.nodes?.add(node);
          hasResolvedAnyLocation = true;
        } else {
          unresolvedLocations.add(orphanedLocation);
        }
      }

      orphanedLocations.clear();
      orphanedLocations.addAll(unresolvedLocations);
    }

    if (orphanedLocations.isNotEmpty) {
      log('Inconsistent data: Some locations could not be resolved.');
    }
  }

  static void _resolveOrphanedAssets(
      List<Map<String, dynamic>> orphanedAssets, RootEntity rootEntity) {
    bool hasResolvedAnyAsset = true;

    while (hasResolvedAnyAsset) {
      hasResolvedAnyAsset = false;
      final List<Map<String, dynamic>> unresolvedAssets = [];

      for (var orphanedAsset in orphanedAssets) {
        final String? parentId =
            orphanedAsset[kParentId] ?? orphanedAsset[kLocationId];
        NodeEntity? parentNode =
            _findParentNodeInTree(rootEntity.nodes, parentId!);
        if (parentNode != null) {
          final NodeEntity node = NodeEntity(
            id: orphanedAsset[kId],
            type: NodeType.asset,
            name: orphanedAsset[kName],
            nodes: [],
            components: [],
          );
          parentNode.nodes?.add(node);
          hasResolvedAnyAsset = true;
        } else {
          unresolvedAssets.add(orphanedAsset);
        }
      }

      orphanedAssets.clear();
      orphanedAssets.addAll(unresolvedAssets);
    }

    if (orphanedAssets.isNotEmpty) {
      log('Inconsistent data: Some assets could not be resolved.');
    }
  }

  static void _resolveOrphanedComponents(
      List<Map<String, dynamic>> orphanedComponents, RootEntity rootEntity) {
    bool hasResolvedAnyComponent = true;

    while (hasResolvedAnyComponent) {
      hasResolvedAnyComponent = false;
      final List<Map<String, dynamic>> unresolvedComponents = [];

      for (var orphanedComponent in orphanedComponents) {
        final String? parentId =
            orphanedComponent[kParentId] ?? orphanedComponent[kLocationId];

        if (parentId != null) {
          NodeEntity? parentNode =
              _findParentNodeInTree(rootEntity.nodes, parentId);

          if (parentNode != null) {
            final ComponentEntity component =
                _mapToComponentEntity(orphanedComponent);
            parentNode.components?.add(component);
            hasResolvedAnyComponent = true;
          } else {
            unresolvedComponents.add(orphanedComponent);
          }
        }
      }

      orphanedComponents.clear();
      orphanedComponents.addAll(unresolvedComponents);
    }

    if (orphanedComponents.isNotEmpty) {
      log('Inconsistent data: Some components could not be resolved.');
    }
  }

  static NodeEntity? _findParentNodeInTree(
      List<NodeEntity> nodes, String parentId) {
    for (NodeEntity node in nodes) {
      final NodeEntity? parentNode = _findParentNode(node, parentId);
      if (parentNode != null) {
        return parentNode;
      }
    }
    return null;
  }

  static NodeEntity? _findParentNode(NodeEntity currentNode, String parentId) {
    if (currentNode.id == parentId) {
      return currentNode;
    }

    for (NodeEntity childNode in currentNode.nodes ?? []) {
      final foundNode = _findParentNode(childNode, parentId);
      if (foundNode != null) {
        return foundNode;
      }
    }

    return null;
  }

  static bool _hasParent(Map<String, dynamic> data) {
    return data[kParentId] != null;
  }

  static bool _isComponent(Map<String, dynamic> asset) {
    return asset[kSensorType] != null;
  }

  static const kId = 'id';
  static const kName = 'name';
  static const kStatus = 'status';
  static const kOperating = 'operating';
  static const kVibration = 'vibration';
  static const kEnergy = 'energy';
  static const kSensorType = 'sensorType';
  static const kLocationId = 'locationId';
  static const kParentId = 'parentId';
}
