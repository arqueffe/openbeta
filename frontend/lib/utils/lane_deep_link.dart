int? laneIdFromUri(Uri uri) {
  final values = uri.queryParametersAll['lane'];
  if (values == null || values.length != 1) {
    return null;
  }

  final laneId = int.tryParse(values.single);
  return laneId != null && laneId > 0 ? laneId : null;
}
