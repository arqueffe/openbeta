import 'package:flutter_test/flutter_test.dart';
import 'package:climbing_gym_app/utils/lane_deep_link.dart';

void main() {
  group('laneIdFromUri', () {
    test('reads the lane parameter while ignoring other query parameters', () {
      final uri = Uri.parse(
        'https://gym.example/app/?view=routes&lane=12&source=share',
      );

      expect(laneIdFromUri(uri), 12);
    });

    test('returns null when the lane parameter is missing', () {
      expect(laneIdFromUri(Uri.parse('https://gym.example/app/')), isNull);
    });

    test('returns null for malformed or non-positive lane IDs', () {
      for (final lane in ['abc', '0', '-2']) {
        expect(
          laneIdFromUri(Uri.parse('https://gym.example/app/?lane=$lane')),
          isNull,
        );
      }
    });

    test('returns null when the lane parameter is repeated', () {
      expect(
        laneIdFromUri(Uri.parse('https://gym.example/app/?lane=12&lane=13')),
        isNull,
      );
    });
  });
}
