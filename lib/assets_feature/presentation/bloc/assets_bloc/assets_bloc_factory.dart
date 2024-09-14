import 'package:tractian_test/assets_feature/presentation/bloc/assets_bloc/assets_bloc.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/http_service.dart';
import '../../../data/datasources/assets_remote_datasource.dart';
import '../../../data/services/assets_feature_service.dart';

class AssetsBlocFactory {
  AssetsBloc create() {
    final IHttpService httpService = HttpService(http.Client());
    final IAssetsRemoteDatasource remoteDatasource =
        AssetsRemoteDatasource(httpService);
    final AssetsFeatureService service = AssetsFeatureService(remoteDatasource);
    return AssetsBloc(service: service);
  }
}
