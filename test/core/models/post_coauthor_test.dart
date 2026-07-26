import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';

void main() {
  test('legacy solo post doc parses with defaults', () {
    final p = Post.fromMap('p1', {
      'authorId': 'ahmed', 'sessionId': 's1', 'visibility': 'public',
      'title': 'Leg day', 'type': 'strength', 'summary': {}, 'likesCount': 0,
      'commentsCount': 0,
    });
    expect(p.authorIds, ['ahmed']);
    expect(p.status, 'published');
    expect(p.coAuthored, false);
    expect(p.authors, isEmpty);
  });

  test('co-authored draft doc parses author slots', () {
    final p = Post.fromMap('p2', {
      'authorIds': ['ahmed', 'mohamed'], 'coAuthored': true, 'status': 'draft',
      'sessionId': 's1', 'visibility': 'public', 'title': 'Push day',
      'type': 'strength', 'summary': {}, 'likesCount': 0, 'commentsCount': 0,
      'authors': {
        'ahmed':  {'userId':'ahmed','caption':'PR!','photoUrl':null,'confirmed':true,'removed':false,'visibility':'public','summary':{}},
        'mohamed':{'userId':'mohamed','caption':null,'photoUrl':null,'confirmed':false,'removed':false,'visibility':'private','summary':{}},
      },
    });
    expect(p.coAuthored, true);
    expect(p.authors['ahmed']!.confirmed, true);
    expect(p.authors['mohamed']!.visibility, 'private');
  });
}
