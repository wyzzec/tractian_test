import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tractian_test/assets_feature/data/datasources/assets_remote_datasource.dart';
import 'package:tractian_test/assets_feature/data/services/assets_feature_service.dart';
import 'package:tractian_test/assets_feature/domain/entities/company_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/root_entity.dart';
import 'package:tractian_test/assets_feature/domain/entities/status.dart';

class MockAssetsRemoteDatasource extends Mock
    implements IAssetsRemoteDatasource {}

void main() {
  late final AssetsFeatureService assetsFeatureService;
  late final MockAssetsRemoteDatasource mockRemoteDatasource;

  setUpAll(() {
    mockRemoteDatasource = MockAssetsRemoteDatasource();
    assetsFeatureService = AssetsFeatureService(mockRemoteDatasource);
  });

  group('AssetsFeatureService', () {
    const companyId = '662fd0ee639069143a8fc387';

    test('fetchCompanies deve retornar uma lista de CompanyEntity', () async {
      // Mock de dados de companhias
      final companiesMockData = [
        {"id": "662fd0ee639069143a8fc387", "name": "Jaguar"},
        {"id": "662fd0fab3fd5656edb39af5", "name": "Tobias"},
        {"id": "662fd100f990557384756e58", "name": "Apex"}
      ];

      // Definindo comportamento do mock
      when(() => mockRemoteDatasource.fetchCompanies())
          .thenAnswer((_) async => companiesMockData);

      // Executa o serviço
      final companies = await assetsFeatureService.fetchCompanies();

      // Verificações
      expect(companies, isA<List<CompanyEntity>>());
      expect(companies.length, 3);
      expect(companies[0].id, '662fd0ee639069143a8fc387');
      expect(companies[0].name, 'Jaguar');
    });

    test('fetchNodes deve retornar uma RootEntity com componentes e nós', () async {
      // Mock de dados de localizações e ativos
      final locationsMockData = [
        {
          "id": "656a07b3f2d4a1001e2144bf",
          "name": "CHARCOAL STORAGE SECTOR",
          "parentId": "65674204664c41001e91ecb4"
        },
        {
          "id": "656733611f4664001f295dd0",
          "name": "Empty Machine house",
          "parentId": null
        },
        {
          "id": "656733b1664c41001e91d9ed",
          "name": "Machinery house",
          "parentId": null
        },
        {
          "id": "65674204664c41001e91ecb4",
          "name": "PRODUCTION AREA - RAW MATERIAL",
          "parentId": null
        },
      ];

      final assetsMockData = [
        {
          "id": "656a07bbf2d4a1001e2144c2",
          "locationId": "656a07b3f2d4a1001e2144bf",
          "name": "CONVEYOR BELT ASSEMBLY",
          "parentId": null,
          "sensorType": null,
          "status": null
        },
        {
          "gatewayId": "QHI640",
          "id": "656734821f4664001f296973",
          "locationId": null,
          "name": "Fan - External",
          "parentId": null,
          "sensorId": "MTC052",
          "sensorType": "energy",
          "status": "operating"
        },
        {
          "id": "656734448eb037001e474a62",
          "locationId": "656733b1664c41001e91d9ed",
          "name": "Fan H12D",
          "parentId": null,
          "sensorType": null,
          "status": null
        },
        {
          "gatewayId": "FRH546",
          "id": "656a07cdc50ec9001e84167b",
          "locationId": null,
          "name": "MOTOR RT COAL AF01",
          "parentId": "656a07c3f2d4a1001e2144c5",
          "sensorId": "FIJ309",
          "sensorType": "vibration",
          "status": "operating"
        },
        {
          "id": "656a07c3f2d4a1001e2144c5",
          "locationId": null,
          "name": "MOTOR TC01 COAL UNLOADING AF02",
          "parentId": "656a07bbf2d4a1001e2144c2",
          "sensorType": null,
          "status": null
        },
        {
          "gatewayId": "QBK282",
          "id": "6567340c1f4664001f29622e",
          "locationId": null,
          "name": "Motor H12D- Stage 1",
          "parentId": "656734968eb037001e474d5a",
          "sensorId": "CFX848",
          "sensorType": "vibration",
          "status": "alert"
        },
        {
          "gatewayId": "VHS387",
          "id": "6567340c664c41001e91dceb",
          "locationId": null,
          "name": "Motor H12D-Stage 2",
          "parentId": "656734968eb037001e474d5a",
          "sensorId": "GYB119",
          "sensorType": "vibration",
          "status": "alert"
        },
        {
          "gatewayId": "VZO694",
          "id": "656733921f4664001f295e9b",
          "locationId": null,
          "name": "Motor H12D-Stage 3",
          "parentId": "656734968eb037001e474d5a",
          "sensorId": "SIF016",
          "sensorType": "vibration",
          "status": "alert"
        },
        {
          "id": "656734968eb037001e474d5a",
          "locationId": "656733b1664c41001e91d9ed",
          "name": "Motors H12D",
          "parentId": null,
          "sensorType": null,
          "status": null
        },
      ];

      // Definindo comportamento do mock
      when(() => mockRemoteDatasource.fetchLocations(companyId))
          .thenAnswer((_) async => locationsMockData);
      when(() => mockRemoteDatasource.fetchAssets(companyId))
          .thenAnswer((_) async => assetsMockData);

      // Executa o serviço
      final rootEntity = await assetsFeatureService.fetchNodes(companyId);

      // Verificações
      expect(rootEntity, isA<RootEntity>());
      expect(rootEntity.nodes.length,
          3); // Três nós raiz: Empty Machine house, Machinery house, PRODUCTION AREA - RAW MATERIAL
      expect(rootEntity.components.length,
          1); // Fan - External deve estar na raiz como componente

      // Verifica nós na raiz
      final rootNode =
      rootEntity.nodes.firstWhere((node) => node.id == '65674204664c41001e91ecb4');
      expect(rootNode.name, 'PRODUCTION AREA - RAW MATERIAL');
      expect(
          rootNode.nodes?.length, 1); // Tem 1 filho (CHARCOAL STORAGE SECTOR)
      final subLocation = rootNode.nodes!.first;
      expect(subLocation.name, 'CHARCOAL STORAGE SECTOR');

      // Verifica o ativo associado à localização CHARCOAL STORAGE SECTOR
      final conveyorBelt = subLocation.nodes!
          .firstWhere((n) => n.name == 'CONVEYOR BELT ASSEMBLY');
      expect(conveyorBelt.name, 'CONVEYOR BELT ASSEMBLY');

      // Verifica componente na raiz
      final fanExternal = rootEntity.components
          .firstWhere((component) => component.name == 'Fan - External');
      expect(fanExternal.name, 'Fan - External');
      expect(fanExternal.status, Status.operating);
    });
  });
}
