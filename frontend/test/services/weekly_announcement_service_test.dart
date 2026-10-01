import 'package:climbing_gym_app/services/weekly_announcement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shows a new announcement version once', () async {
    SharedPreferences.setMockInitialValues({
      'weekly_announcement_last_shown_version': 1,
    });
    final service = WeeklyAnnouncementService();

    expect(await service.shouldShowCurrentVersion(), isTrue);

    await service.markCurrentVersionShown();

    expect(await service.shouldShowCurrentVersion(), isFalse);
  });
}
