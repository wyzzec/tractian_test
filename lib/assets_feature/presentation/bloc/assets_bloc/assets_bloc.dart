import 'package:bloc/bloc.dart';
import 'package:tractian_test/assets_feature/domain/entities/root_entity.dart';

import '../../../data/services/assets_feature_service.dart';

part 'assets_bloc_state.dart';

class AssetsBloc extends Cubit<AssetsState> {
  final IAssetsFeatureService service;

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
}
