import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'prescription_models.dart';

final prescriptionsRepositoryProvider = Provider<PrescriptionsRepository>((ref) => PrescriptionsRepository(ref.watch(apiClientProvider)));

class PrescriptionsRepository {
  PrescriptionsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Prescription>> list({String? search, String status = 'open', int page = 1}) async => Paginated.fromJson(
        await _api.get(ApiEndpoints.prescriptions, query: {'search': search, 'status': status, 'page': page, 'per_page': 30}, offlineCopy: false),
        Prescription.fromJson,
      );

  Future<Prescription> show(int id) async => Prescription.fromJson(ApiClient.data(await _api.get(ApiEndpoints.prescription(id), offlineCopy: false)));

  Future<Prescription> create(Map<String, dynamic> data) async =>
      Prescription.fromJson(ApiClient.data(await _api.post(ApiEndpoints.prescriptions, data: data)));

  Future<Prescription> verify(int id) async => Prescription.fromJson(ApiClient.data(await _api.post(ApiEndpoints.prescriptionVerify(id))));

  Future<Prescription> cancel(int id) async => Prescription.fromJson(ApiClient.data(await _api.post(ApiEndpoints.prescriptionCancel(id))));

  Future<Prescription> uploadImage(int id, String filePath) async =>
      Prescription.fromJson(ApiClient.data(await _api.upload(ApiEndpoints.prescriptionImage(id), field: 'image', filePath: filePath)));

  Future<List<int>> image(int id) => _api.getBytes(ApiEndpoints.prescriptionImage(id));
}
