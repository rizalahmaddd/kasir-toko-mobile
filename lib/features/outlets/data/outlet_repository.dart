import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import 'outlet_models.dart';

final outletRepositoryProvider = Provider<OutletRepository>((ref) => OutletRepository(ref.watch(apiClientProvider)));

class OutletRepository {
  OutletRepository(this._api);

  final ApiClient _api;

  /// Outlets this account may use; [all] lists every outlet (owner and admins) with user counts.
  Future<List<OutletInfo>> list({bool all = false}) async =>
      ApiClient.list(await _api.get(ApiEndpoints.outlets, query: {'scope': all ? 'all' : null}, offlineCopy: false)).map(OutletInfo.fromJson).toList();

  /// [storeType] on a new outlet applies that store type's preset to this outlet only; on an existing
  /// outlet it adds the preset's categories and features without removing the old ones.
  Future<OutletInfo> save({
    int? id,
    required String name,
    required String code,
    String? address,
    String? phone,
    int? copyFromOutletId,
    String? storeType,
    bool includeSampleProducts = true,
    List<String>? capabilities,
  }) async {
    final payload = {
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      if (id == null && copyFromOutletId != null) 'copy_from_outlet_id': copyFromOutletId,
      'store_type': ?storeType,
      if (id == null && storeType != null) 'include_sample_products': includeSampleProducts,
      if (id == null && storeType != null && capabilities != null) 'capabilities': capabilities,
    };
    final body = id == null ? await _api.post(ApiEndpoints.outlets, data: payload) : await _api.put(ApiEndpoints.outlet(id), data: payload);

    return OutletInfo.fromJson(ApiClient.data(body));
  }

  Future<void> delete(int id) => _api.delete(ApiEndpoints.outlet(id));

  Future<OutletInfo> setPrimary(int id) async => OutletInfo.fromJson(ApiClient.data(await _api.post(ApiEndpoints.outletPrimary(id))));

  Future<OutletInfo> setActive(int id, {required bool active}) async =>
      OutletInfo.fromJson(ApiClient.data(await _api.put(ApiEndpoints.outletActive(id), data: {'is_active': active})));

  Future<List<OutletUser>> access(int id) async =>
      ApiClient.list(await _api.get(ApiEndpoints.outletUsers(id), offlineCopy: false)).map(OutletUser.fromJson).toList();

  Future<void> saveAccess(int id, List<int> userIds) => _api.put(ApiEndpoints.outletUsers(id), data: {'user_ids': userIds});

  /// [includeBusiness] also copies the store type, business features, and switched-off cashier features.
  Future<void> copyFrom(int id, int sourceId, {bool includeBusiness = false}) =>
      _api.post(ApiEndpoints.outletCopy(id), data: {'source_outlet_id': sourceId, if (includeBusiness) 'include_business': true});

  Future<OutletInfo> saveCapabilities(int id, List<String> capabilities) async =>
      OutletInfo.fromJson(ApiClient.data(await _api.put(ApiEndpoints.outletCapabilities(id), data: {'capabilities': capabilities})));

  Future<OutletSettingsData> settings(int id) async =>
      OutletSettingsData.fromJson(ApiClient.data(await _api.get(ApiEndpoints.outletSettings(id), offlineCopy: false)));

  Future<OutletSettingsData> saveSettings(int id, OutletSettingsData data) async =>
      OutletSettingsData.fromJson(ApiClient.data(await _api.put(ApiEndpoints.outletSettings(id), data: data.toJson())));

  /// Remembers the choice on the server so another device of the same account starts on it.
  Future<void> rememberCurrent(int id) => _api.put(ApiEndpoints.authCurrentOutlet, data: {'outlet_id': id});
}
