import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tractian_test/assets_feature/presentation/bloc/assets_bloc/assets_bloc.dart';
import 'package:tractian_test/assets_feature/domain/entities/node_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/component_entity.dart';
import '../../domain/entities/node_type.dart';
import '../../domain/entities/sensor_type.dart';
import '../../domain/entities/status.dart';
import '../bloc/assets_bloc/assets_bloc_factory.dart';

class AssetsPage extends StatefulWidget {
  final String companyId;

  const AssetsPage({super.key, required this.companyId});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  late AssetsBloc _assetsBloc;
  bool filterEnergySensor = false;
  bool filterCritical = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _assetsBloc = AssetsBlocFactory().create();
    _assetsBloc.fetchAssets(widget.companyId);
  }

  @override
  void dispose() {
    _assetsBloc.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _assetsBloc.searchAssets(
      query,
      widget.companyId,
      filterEnergySensor: filterEnergySensor,
      filterCritical: filterCritical,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        centerTitle: true,
        title: const Text(
          "Assets",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SearchBar(
                onSearchChanged: _onSearchChanged,
              ),
            ),
            FilterRow(
              filterEnergySensor: filterEnergySensor,
              filterCritical: filterCritical,
              onFilterEnergySensorChanged: (selected) {
                setState(() {
                  filterEnergySensor = selected;
                  _onSearchChanged(
                      searchQuery); // Aplica o filtro junto à pesquisa
                });
              },
              onFilterCriticalChanged: (selected) {
                setState(() {
                  filterCritical = selected;
                  _onSearchChanged(
                      searchQuery); // Aplica o filtro junto à pesquisa
                });
              },
            ),
            BlocBuilder<AssetsBloc, AssetsState>(
              bloc: _assetsBloc,
              builder: (context, state) {
                if (state is AssetsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is AssetsLoaded) {
                  return AssetTree(
                    nodes: state.assets.nodes,
                    components: state.assets.components,
                    isSearching: filterEnergySensor ||
                        filterCritical ||
                        searchQuery.isNotEmpty,
                  );
                } else if (state is AssetsError) {
                  return Center(child: Text(state.message));
                } else {
                  return Container();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para a barra de busca
class SearchBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;

  const SearchBar({super.key, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar Ativo ou Local',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: onSearchChanged,
    );
  }
}

// Widget para os filtros
class FilterRow extends StatelessWidget {
  final bool filterEnergySensor;
  final bool filterCritical;
  final ValueChanged<bool> onFilterEnergySensorChanged;
  final ValueChanged<bool> onFilterCriticalChanged;

  const FilterRow({
    super.key,
    required this.filterEnergySensor,
    required this.filterCritical,
    required this.onFilterEnergySensorChanged,
    required this.onFilterCriticalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FilterChip(
          label: const Text('Sensor de Energia'),
          selected: filterEnergySensor,
          onSelected: onFilterEnergySensorChanged,
        ),
        FilterChip(
          label: const Text('Crítico'),
          selected: filterCritical,
          onSelected: onFilterCriticalChanged,
        ),
      ],
    );
  }
}

// Widget para exibir a árvore de ativos e localizações
class AssetTree extends StatelessWidget {
  final List<NodeEntity> nodes;
  final List<ComponentEntity> components; // Componentes na raiz
  final bool isSearching;

  const AssetTree({
    super.key,
    required this.nodes,
    required this.components,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Ajuste de alinhamento
          children: [
            // Exibe os nós (localizações e ativos)
            ...nodes
                .map((node) => AssetNode(
                      node: node,
                      depth: 0,
                      expanded: isSearching,
                    ))
                .toList(),
            // Exibe os componentes diretamente na raiz
            ...components
                .map((component) => ComponentTile(component: component)),
          ],
        ),
      ),
    );
  }
}

// Widget para exibir cada nó da árvore (localização ou ativo)
class AssetNode extends StatefulWidget {
  final NodeEntity node;
  final int depth; // Adicionado para controle da indentação
  final bool expanded;

  const AssetNode(
      {super.key, required this.node, required this.expanded, this.depth = 10});

  @override
  State<AssetNode> createState() => _AssetNodeState();
}

class _AssetNodeState extends State<AssetNode>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false; // Controla o estado de expansão
  late final AnimationController _controller; // Controlador da animação

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    if (widget.expanded) {
      _toggleExpand();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 10.0 + widget.depth, bottom: 10, top: 10),
      // Indentação conforme o nível
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleExpand,
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more, // Ícone de expandir/recolher
                ),
                Icon(
                  widget.node.type == NodeType.location
                      ? Icons.location_on
                      : Icons.inventory_2,
                ),
                const SizedBox(width: 2),
                Text(widget.node.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              children: _isExpanded ? _buildExpandedContent() : [],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandedContent() {
    return [
      if (widget.node.nodes != null)
        Padding(
          padding: const EdgeInsets.only(left: 11.0),
          // Espaçamento entre pai e filhos
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: Colors.blue,
                      width: 2)), // Linha vertical à esquerda
            ),
            child: Column(
              children: widget.node.nodes!.map((child) {
                return AssetNode(
                  node: child,
                  depth: widget.depth + 1,
                  // Aumenta a indentação para os filhos
                  expanded: widget.expanded,
                );
              }).toList(),
            ),
          ),
        ),
      if (widget.node.components != null)
        Padding(
          padding: const EdgeInsets.only(left: 11.0),
          // Espaçamento entre pai e componentes
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: Colors.blue,
                      width: 2)), // Linha vertical à esquerda
            ),
            child: Column(
              children: widget.node.components!
                  .map((component) => ComponentTile(
                      component: component, depth: widget.depth + 1))
                  .toList(),
            ),
          ),
        ),
    ];
  }
}

// Widget para exibir cada componente na árvore
class ComponentTile extends StatelessWidget {
  final ComponentEntity component;
  final int depth;

  const ComponentTile({super.key, required this.component, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth.toDouble()),
      // Indentação para componentes
      child: ListTile(
        leading: Icon(
          component.sensorType == SensorType.energy
              ? Icons.bolt
              : Icons.vibration,
          color:
              component.status == Status.operating ? Colors.green : Colors.red,
        ),
        title: Text(component.name),
      ),
    );
  }
}
