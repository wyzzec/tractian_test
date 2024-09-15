import 'package:flutter/cupertino.dart';
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                _onSearchChanged(searchQuery);
              });
            },
            onFilterCriticalChanged: (selected) {
              setState(() {
                filterCritical = selected;
                _onSearchChanged(searchQuery);
              });
            },
          ),
          BlocBuilder<AssetsBloc, AssetsState>(
            bloc: _assetsBloc,
            builder: (context, state) {
              if (state is AssetsLoading) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              if (state is AssetsLoaded) {
                return AssetTree(
                  nodes: state.assets.nodes,
                  components: state.assets.components,
                  isSearching: filterEnergySensor ||
                      filterCritical ||
                      searchQuery.isNotEmpty,
                );
              }
              if (state is AssetsError) {
                return Center(child: Text(state.message));
              }
              return Container();
            },
          ),
        ],
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;

  const SearchBar({super.key, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar ativos ou locais',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onChanged: onSearchChanged,
    );
  }
}

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
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilterChip(
            label: const Row(
              children: [
                Icon(
                  Icons.bolt,
                  size: 20,
                ),
                Text('Sensor de Energia'),
              ],
            ),
            selected: filterEnergySensor,
            onSelected: onFilterEnergySensorChanged,
          ),
        ),
        FilterChip(
          label: const Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 20,
              ),
              SizedBox(
                width: 5,
              ),
              Text('Crítico'),
            ],
          ),
          selected: filterCritical,
          onSelected: onFilterCriticalChanged,
        ),
      ],
    );
  }
}

class AssetTree extends StatelessWidget {
  final List<NodeEntity> nodes;
  final List<ComponentEntity> components;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.726,
              child: ListView.builder(
                itemCount: nodes.length + components.length,
                itemBuilder: (BuildContext context, int index) {
                  if (index < nodes.length) {
                    return AssetNode(
                        node: nodes[index], expanded: isSearching, depth: 0);
                  }
                  return ComponentTile(
                    component: components[index - nodes.length],
                  );
                },
              ),
            ),

            // ...nodes
            //     .map((node) => AssetNode(
            //           node: node,
            //           depth: 0,
            //           expanded: isSearching,
            //         ))
            //     .toList(),
            // ...components
            //     .map((component) => ComponentTile(component: component)),
          ],
        ),
      ),
    );
  }
}

class AssetNode extends StatefulWidget {
  final NodeEntity node;
  final int depth;
  final bool expanded;

  const AssetNode(
      {super.key, required this.node, required this.expanded, this.depth = 10});

  @override
  State<AssetNode> createState() => _AssetNodeState();
}

class _AssetNodeState extends State<AssetNode>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller;

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
                      : Icons.all_inbox_outlined,
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
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: widget.node.nodes!.map((child) {
                return AssetNode(
                  node: child,
                  depth: widget.depth + 1,
                  expanded: widget.expanded,
                );
              }).toList(),
            ),
          ),
        ),
      if (widget.node.components != null)
        Padding(
          padding: const EdgeInsets.only(left: 11.0),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: widget.node.components!
                  .map(
                    (component) => ComponentTile(
                      component: component,
                      depth: widget.depth + 1,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
    ];
  }
}

class ComponentTile extends StatelessWidget {
  final ComponentEntity component;
  final int depth;

  const ComponentTile({super.key, required this.component, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth.toDouble()),
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
