int asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime? asDate(dynamic value) => value == null ? null : DateTime.tryParse('$value');

Map<String, dynamic> asMap(dynamic value) => value is Map<String, dynamic> ? value : const {};

List<Map<String, dynamic>> asList(dynamic value) => value is List ? value.cast<Map<String, dynamic>>() : const [];
