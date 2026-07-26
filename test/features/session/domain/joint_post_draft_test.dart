import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/joint_post_draft.dart';

PostAuthorSlot slot(String id, {bool c = false, bool r = false, String v = 'public'}) =>
    PostAuthorSlot(userId: id, confirmed: c, removed: r, visibility: v, summary: SessionSummary());

void main() {
  test('bothConfirmed only when all active slots confirmed', () {
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', c: false)}), false);
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', c: true)}), true);
  });
  test('removed slot is ignored by bothConfirmed', () {
    expect(bothConfirmed({'a': slot('a', c: true), 'b': slot('b', r: true)}), false); // <2 active
  });
  test('resolveJointVisibility private wins', () {
    expect(resolveJointVisibility({'a': slot('a', v: 'public'), 'b': slot('b', v: 'private')}), 'private');
    expect(resolveJointVisibility({'a': slot('a', v: 'public'), 'b': slot('b', v: 'public')}), 'public');
  });
}
