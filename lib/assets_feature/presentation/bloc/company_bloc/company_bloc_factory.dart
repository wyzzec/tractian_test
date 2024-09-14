import 'package:http/http.dart' as http;
import 'package:tractian_test/assets_feature/data/datasources/assets_remote_datasource.dart';
import 'package:tractian_test/assets_feature/data/services/assets_feature_service.dart';
import 'package:tractian_test/assets_feature/presentation/bloc/company_bloc/company_bloc.dart';
import 'package:tractian_test/core/services/http_service.dart';

class CompanyBlocFactory {
  CompanyBloc create() {
    final IHttpService httpService = HttpService(http.Client());
    final IAssetsRemoteDatasource remoteDatasource =
        AssetsRemoteDatasource(httpService);
    final AssetsFeatureService service = AssetsFeatureService(remoteDatasource);

    return CompanyBloc(service: service);
  }
}
