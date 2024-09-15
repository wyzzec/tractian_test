import 'package:bloc/bloc.dart';
import 'package:tractian_test/assets_feature/data/services/isolate_service.dart';
import 'package:tractian_test/assets_feature/domain/entities/root_entity.dart';
import 'dart:async';
import '../../../data/services/assets_feature_service.dart';
import '../../../domain/entities/component_entity.dart';
import '../../../domain/entities/node_entity.dart';
import '../../../domain/entities/sensor_type.dart';
import '../../../domain/entities/status.dart';

part 'assets_bloc_state.dart';

class AssetsBloc extends Cubit<AssetsState> {
  final IAssetsFeatureService service;
  Timer? _debounce;

  AssetsBloc({required this.service}) : super(AssetsInitial());

  late final RootEntity _rootEntity;

  void fetchAssets(String companyId) async {
    try {
      emit(AssetsLoading());
      _rootEntity = await service.fetchNodes(companyId);
      emit(AssetsLoaded(assets: _rootEntity));
    } catch (e) {
      emit(AssetsError(message: "Failed to load assets"));
    }
  }

  void searchAssets(
    String query,
    String companyId, {
    required bool filterEnergySensor,
    required bool filterCritical,
  }) async {
    if (query.isEmpty && !filterEnergySensor && !filterCritical) {
      emit(
        AssetsLoaded(
          assets: _rootEntity,
        ),
      );
      return;
    }
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          emit(AssetsLoading());
          final List<NodeEntity> filteredNodes = await _filterAndSearchNodes(
            _rootEntity.nodes,
            query,
            filterEnergySensor,
            filterCritical,
          );
          final List<ComponentEntity> filteredComponents =
              await _filterRootComponents(
            _rootEntity.components,
            query,
            filterEnergySensor,
            filterCritical,
          );

          emit(
            AssetsLoaded(
              assets: RootEntity(
                nodes: filteredNodes,
                components: filteredComponents,
              ),
            ),
          );
        } catch (e) {
          emit(AssetsError(message: "Failed to search assets"));
        }
      },
    );
  }

  static Future<List<NodeEntity>> _filterAndSearchNodes(
    List<NodeEntity> nodes,
    String searchQuery,
    bool filterEnergySensor,
    bool filterCritical,
  ) async {
    final bool shouldIgnoreSearch = filterEnergySensor || filterCritical;

    final List<NodeEntity> filteredNodes = await runIsolate(() async {
      List<NodeEntity> isolateFilteredNodes = [];

      for (var node in nodes) {
        final matchesSearch = !shouldIgnoreSearch &&
            (searchQuery.isEmpty ||
                node.name.toLowerCase().contains(searchQuery.toLowerCase()));

        bool matchesComponentFilters = false;
        if (node.components != null) {
          for (var component in node.components!) {
            if (filterEnergySensor &&
                component.sensorType == SensorType.energy) {
              matchesComponentFilters = true;
              break;
            }
            if (filterCritical && component.status == Status.alert) {
              matchesComponentFilters = true;
              break;
            }
            if (!shouldIgnoreSearch &&
                component.name
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase())) {
              matchesComponentFilters = true;
              break;
            }
          }
        }

        final childMatches = await _filterAndSearchNodes(
          node.nodes ?? [],
          searchQuery,
          filterEnergySensor,
          filterCritical,
        );

        final componentMatches = await _filterRootComponents(
          node.components ?? [],
          searchQuery,
          filterEnergySensor,
          filterCritical,
        );

        if (matchesSearch ||
            matchesComponentFilters ||
            childMatches.isNotEmpty) {
          isolateFilteredNodes.add(NodeEntity(
            id: node.id,
            name: node.name,
            type: node.type,
            nodes: childMatches,
            components: componentMatches,
          ));
        }
      }
      return isolateFilteredNodes;
    });

    return filteredNodes;
  }

  static Future<List<ComponentEntity>> _filterRootComponents(
    List<ComponentEntity> components,
    String searchQuery,
    bool filterEnergySensor,
    bool filterCritical,
  ) async {
    final bool shouldIgnoreSearch = filterEnergySensor || filterCritical;
    List<ComponentEntity> filteredComponents = [];

    filteredComponents = await runIsolate(() async {
      List<ComponentEntity> isolateFilteredComponents = [];

      for (var component in components) {
        bool matches = false;
        if (filterEnergySensor && component.sensorType == SensorType.energy) {
          matches = true;
        }
        if (filterCritical && component.status == Status.alert) {
          matches = true;
        }
        if (!shouldIgnoreSearch &&
            (searchQuery.isEmpty ||
                component.name
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))) {
          matches = true;
        }

        if (matches) {
          isolateFilteredComponents.add(component);
        }
      }
      return isolateFilteredComponents;
    });

    return filteredComponents;
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
