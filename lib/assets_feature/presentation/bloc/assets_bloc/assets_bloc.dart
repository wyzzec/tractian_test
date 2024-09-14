import 'package:bloc/bloc.dart';
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
  Timer? _debounce; // Timer para debouncer

  AssetsBloc({required this.service}) : super(AssetsInitial());

  void fetchAssets(String companyId) async {
    try {
      emit(AssetsLoading());
      final assets = await service.fetchNodes(companyId);
      emit(AssetsLoaded(assets: assets));
    } catch (e) {
      emit(AssetsError(message: "Failed to load assets"));
    }
  }

  // Adicionando função para pesquisa com debounce
  void searchAssets(
      String query,
      String companyId, {
        required bool filterEnergySensor,
        required bool filterCritical,
      }) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        emit(AssetsLoading()); // Exibe estado de carregamento enquanto pesquisa

        final assets = await service.fetchNodes(companyId);

        final filteredNodes = _filterAndSearchNodes(
          assets.nodes,
          query,
          filterEnergySensor,
          filterCritical,
        );
        final filteredComponents = _filterRootComponents(
          assets.components,
          query,
          filterEnergySensor,
          filterCritical,
        );

        emit(AssetsLoaded(assets: RootEntity(nodes: filteredNodes, components: filteredComponents)));
      } catch (e) {
        emit(AssetsError(message: "Failed to search assets"));
      }
    });
  }

  List<NodeEntity> _filterAndSearchNodes(
      List<NodeEntity> nodes,
      String searchQuery,
      bool filterEnergySensor,
      bool filterCritical,
      ) {
    List<NodeEntity> filteredNodes = [];

    for (var node in nodes) {
      // Verifica se o filtro de sensor de energia ou crítico está ativado
      final bool shouldIgnoreSearch = filterEnergySensor || filterCritical;

      // Verifica se o nome do nó corresponde à pesquisa
      final matchesSearch = !shouldIgnoreSearch &&
          (searchQuery.isEmpty || node.name.toLowerCase().contains(searchQuery.toLowerCase()));

      // Verifica se os componentes do nó correspondem aos filtros
      final matchesComponentFilters = node.components?.any((component) {
        if (filterEnergySensor && component.sensorType == SensorType.energy) {
          return true;
        }
        if (filterCritical && component.status == Status.alert) {
          return true;
        }
        if (!shouldIgnoreSearch &&
            component.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return true;
        }
        return false;
      }) ??
          false;

      // Verifica os filhos do nó
      final childMatches = _filterAndSearchNodes(node.nodes ?? [], searchQuery, filterEnergySensor, filterCritical);
      final componentMatches = _filterRootComponents(node.components ?? [], searchQuery, filterEnergySensor, filterCritical);

      if (matchesSearch || matchesComponentFilters || childMatches.isNotEmpty) {
        filteredNodes.add(NodeEntity(
          id: node.id,
          name: node.name,
          type: node.type,
          nodes: childMatches,
          components: componentMatches,
        ));
      }
    }

    return filteredNodes;
  }

  List<ComponentEntity> _filterRootComponents(
      List<ComponentEntity> components,
      String searchQuery,
      bool filterEnergySensor,
      bool filterCritical,
      ) {
    final bool shouldIgnoreSearch = filterEnergySensor || filterCritical;

    return components.where((component) {
      if (filterEnergySensor && component.sensorType == SensorType.energy) {
        return true;
      }
      if (filterCritical && component.status == Status.alert) {
        return true;
      }
      if (!shouldIgnoreSearch && (searchQuery.isEmpty || component.name.toLowerCase().contains(searchQuery.toLowerCase()))) {
        return true;
      }
      return false;
    }).toList();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
