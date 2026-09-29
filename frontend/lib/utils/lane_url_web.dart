import 'package:web/web.dart' as web;

void replaceLaneUrl(int laneId) {
  final query = Map<String, String>.from(Uri.base.queryParameters);
  query['lane'] = laneId.toString();
  final uri = Uri.base.replace(queryParameters: query);
  web.window.history.replaceState(null, '', uri.toString());
}
