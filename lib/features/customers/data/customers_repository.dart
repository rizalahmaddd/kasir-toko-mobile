import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) => CustomersRepository(ref.watch(apiClientProvider)));

class Customer {
  const Customer({
    required this.id,
    required this.code,
    required this.name,
    this.type,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.npwp,
    required this.paymentTermDays,
    required this.isActive,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String,
        type: json['type'] as String?,
        contactPerson: json['contact_person'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        npwp: json['npwp'] as String?,
        paymentTermDays: asInt(json['payment_term_days']),
        isActive: json['is_active'] as bool? ?? true,
      );

  final int id;
  final String code;
  final String name;
  final String? type;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? npwp;
  final int paymentTermDays;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'type': type,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'npwp': npwp,
        'payment_term_days': paymentTermDays,
        'is_active': isActive,
      };
}

class CustomersRepository {
  CustomersRepository(this._api);

  final ApiClient _api;

  Future<Paginated<Customer>> list({String? search, bool? isActive, int page = 1}) async {
    final body = await _api.get(
      ApiEndpoints.customers,
      query: {'search': search, 'is_active': isActive == null ? null : (isActive ? 1 : 0), 'page': page, 'per_page': 30},
    );

    return Paginated.fromJson(body, Customer.fromJson);
  }

  Future<Customer> show(int id) async => Customer.fromJson(ApiClient.data(await _api.get(ApiEndpoints.customer(id))));

  Future<Customer?> getCached(int id) async {
    final copy = await _api.offlineCopy(ApiEndpoints.customer(id));
    if (copy == null) {
      return null;
    }
    try {
      return Customer.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<Customer> save(Customer customer, {int? id}) async {
    final body = id == null
        ? await _api.post(ApiEndpoints.customers, data: customer.toJson())
        : await _api.put(ApiEndpoints.customer(id), data: customer.toJson());

    if (id != null) {
      await _api.updateCached(ApiEndpoints.customer(id), body);
    }
    return Customer.fromJson(ApiClient.data(body));
  }

  Future<void> delete(int id) async {
    await _api.delete(ApiEndpoints.customer(id));
    await _api.removeCached(ApiEndpoints.customer(id));
  }
}
