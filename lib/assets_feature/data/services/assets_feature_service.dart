import 'dart:developer';
import 'package:tractian_test/assets_feature/data/datasources/assets_remote_datasource.dart';
import 'package:tractian_test/assets_feature/domain/entities/company_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_type.dart';
import 'package:tractian_test/assets_feature/domain/entities/sensor_type.dart';
import '../../domain/entities/component_entity.dart';
import '../../domain/entities/status.dart';
import 'package:tractian_test/assets_feature/domain/entities/root_entity.dart';

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
      final List<NodeEntity> nodes =
          _processLocations(locationsData, locationMap);

      final RootEntity rootEntity = RootEntity(nodes: nodes, components: []);
      _processAssets(assetsData, rootEntity);

      return rootEntity;
    } catch (e, s) {
      log('Error fetching nodes in AssetsFeatureService\n$e\n$s');
      rethrow;
    }
  }

  // Mapeia os dados da empresa
  CompanyEntity _mapToCompanyEntity(Map<String, dynamic> map) {
    return CompanyEntity(id: map[kId], name: map[kName]);
  }

  // Mapeia os dados de componentes
  ComponentEntity _mapToComponentEntity(Map<String, dynamic> map) {
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

  // Processa e mapeia as localizações e resolve nós órfãos
  List<NodeEntity> _processLocations(List<Map<String, dynamic>> locationsData,
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
        // Adiciona nó raiz
        nodes.add(node);
      }
    }

    _resolveOrphanedLocations(orphanedLocations, nodes);
    return nodes;
  }

  // Processa ativos e componentes
  void _processAssets(
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
          // Se não tem parentId ou locationId, adiciona o componente na raiz
          rootEntity.components.add(component);
        }
      } else {
        _processAssetWithoutComponent(asset, rootEntity, orphanedAssets);
      }
    }

    _resolveOrphanedAssets(orphanedAssets, rootEntity);
    _resolveOrphanedComponents(orphanedComponents, rootEntity);
  }

  // Processa ativo que não é um componente
  void _processAssetWithoutComponent(Map<String, dynamic> asset,
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
      // Se não tem parentId ou locationId, adiciona o ativo na raiz
      rootEntity.nodes.add(node);
    }
  }

  // Resolve localizações órfãs
  void _resolveOrphanedLocations(
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
          hasResolvedAnyLocation = true; // Uma localização foi resolvida
        } else {
          unresolvedLocations.add(orphanedLocation);
        }
      }

      orphanedLocations.clear();
      orphanedLocations.addAll(unresolvedLocations);
    }

    // Se restarem localizações órfãs, lança uma exceção
    if (orphanedLocations.isNotEmpty) {
      log('Inconsistent data: Some locations could not be resolved.');
    }
  }

  // Resolve ativos órfãos
  void _resolveOrphanedAssets(
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
          hasResolvedAnyAsset = true; // Um ativo foi resolvido
        } else {
          unresolvedAssets.add(orphanedAsset);
        }
      }

      orphanedAssets.clear();
      orphanedAssets.addAll(unresolvedAssets);
    }

    // Se restarem ativos órfãos, lança uma exceção
    if (orphanedAssets.isNotEmpty) {
      log('Inconsistent data: Some assets could not be resolved.');
    }
  }

  // Resolve componentes órfãos
  void _resolveOrphanedComponents(
      List<Map<String, dynamic>> orphanedComponents, RootEntity rootEntity) {
    bool hasResolvedAnyComponent = true;

    // Continua tentando até que não haja mais componentes órfãos a serem resolvidos
    while (hasResolvedAnyComponent) {
      hasResolvedAnyComponent = false;
      final List<Map<String, dynamic>> unresolvedComponents = [];

      for (var orphanedComponent in orphanedComponents) {
        final String? parentId =
            orphanedComponent[kParentId] ?? orphanedComponent[kLocationId];

        if (parentId != null) {
          NodeEntity? parentNode =
              _findParentNodeInTree(rootEntity.nodes, parentId);

          // Se o nó pai foi encontrado, adiciona o componente
          if (parentNode != null) {
            final ComponentEntity component =
                _mapToComponentEntity(orphanedComponent);
            parentNode.components?.add(component);
            hasResolvedAnyComponent = true; // Um componente foi resolvido
          } else {
            // Adiciona à lista de componentes não resolvidos para tentar na próxima iteração
            unresolvedComponents.add(orphanedComponent);
          }
        }
      }

      // Atualiza a lista de componentes órfãos para os não resolvidos
      orphanedComponents.clear();
      orphanedComponents.addAll(unresolvedComponents);
    }

    // Se restarem componentes órfãos, lança uma exceção
    if (orphanedComponents.isNotEmpty) {
      log('Inconsistent data: Some components could not be resolved.');
    }
  }

  // Função auxiliar para buscar recursivamente o pai em qualquer nível da árvore
  NodeEntity? _findParentNodeInTree(List<NodeEntity> nodes, String parentId) {
    for (NodeEntity node in nodes) {
      final NodeEntity? parentNode = _findParentNode(node, parentId);
      if (parentNode != null) {
        return parentNode;
      }
    }
    return null;
  }

  NodeEntity? _findParentNode(NodeEntity currentNode, String parentId) {
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

  // Verifica se a localização ou ativo tem um pai
  bool _hasParent(Map<String, dynamic> data) {
    return data[kParentId] != null;
  }

  // Verifica se o ativo é um componente
  bool _isComponent(Map<String, dynamic> asset) {
    return asset[kSensorType] != null;
  }

  // Constantes
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
