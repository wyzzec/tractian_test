import 'package:bloc/bloc.dart';

import '../../../data/services/assets_feature_service.dart';
import '../../../domain/entities/company_entity.dart';

part 'company_state.dart';

// O Cubit que gerencia o estado
class CompanyBloc extends Cubit<CompanyState> {
  final IAssetsFeatureService service;

  CompanyBloc({required this.service}) : super(CompanyInitial());

  void fetchCompanies() async {
    try {
      emit(CompanyLoading());
      final companies = await service.fetchCompanies();
      emit(CompanyLoaded(companies: companies));
    } catch (e) {
      emit(CompanyError(message: "Failed to load companies."));
    }
  }
}
