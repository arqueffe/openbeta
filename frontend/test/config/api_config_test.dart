import 'package:climbing_gym_app/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses an absolute WordPress API URL on native platforms', () {
    final baseUri = Uri.parse(ApiConfig.baseUrl);

    expect(baseUri.hasScheme, isTrue);
    expect(baseUri.hasAuthority, isTrue);
    expect(ApiConfig.baseUrl, ApiConfig.wordPressApiUrl);
  });
}
