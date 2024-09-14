import 'package:tractian_test/core/entities/http_response_entity.dart';
import 'package:tractian_test/core/services/http_service.dart';

abstract class IAssetsRemoteDatasource {
  Future<List<Map<String, dynamic>>> fetchCompanies();

  Future<List<Map<String, dynamic>>> fetchLocations(String companyId);

  Future<List<Map<String, dynamic>>> fetchAssets(String locationId);
}

final class AssetsRemoteDatasource implements IAssetsRemoteDatasource {
  final IHttpService httpService;

  const AssetsRemoteDatasource(this.httpService);

  @override
  Future<List<Map<String, dynamic>>> fetchCompanies() async {
    try {
      final HttpResponseEntity response =
          await httpService.get<List<dynamic>>(kCompaniesEndpoint);
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLocations(String companyId) async {
    try {
      final HttpResponseEntity response =
          await httpService.get<List<dynamic>>(
              '$kCompaniesEndpoint/$companyId/locations');
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAssets(String locationId) async {
    try {
      final HttpResponseEntity response =
          await httpService.get<List<dynamic>>(
              '$kCompaniesEndpoint/$locationId/assets');
      return (response.data as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      rethrow;
    }
  }

  static const kTractianBaseUrl = 'https://fake-api.tractian.com';
  static const kCompaniesEndpoint = '$kTractianBaseUrl/companies';
}
