import '../../../core/models/models.dart';

List<String> activeAuthorIds(Map<String, PostAuthorSlot> authors) =>
    authors.values.where((s) => !s.removed).map((s) => s.userId).toList();

bool bothConfirmed(Map<String, PostAuthorSlot> authors) {
  final active = authors.values.where((s) => !s.removed).toList();
  return active.length >= 2 && active.every((s) => s.confirmed);
}

String resolveJointVisibility(Map<String, PostAuthorSlot> authors) =>
    authors.values.any((s) => !s.removed && s.visibility == 'private')
        ? 'private'
        : 'public';
