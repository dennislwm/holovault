import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/collection_search.dart';
import 'package:holovault/database/database.dart';
import 'package:holovault/set_lookup.dart';
import 'package:holovault/widgets/item_row.dart';

// REQ-054: the row chips (language, grade, discriminator).
MergedItem _item({String? set, String? grader, String? subtype, String? number}) => MergedItem(
      id: 1,
      importedId: 'x',
      name: 'Pikachu',
      setName: set,
      gradeType: grader,
      gradeSubtype: subtype,
      discriminator: number,
    );

void main() {
  setUp(() => setLookup = {
        'Set A': const SetLookupRow(aliasName: 'Set A', language: 'ja', tcgdexId: null, officialName: null),
      });
  tearDown(() => setLookup = {});

  test('chip rule: language, grade with no space, discriminator; blanks omitted', () {
    expect(rowChips(_item(set: 'Set A', grader: 'PSA', subtype: '10 GEM-MT', number: '074/071')),
        ['ja', 'PSA10', '074/071']);
    expect(rowChips(_item(grader: 'PSA', subtype: '9 MINT')), ['PSA9']);
    expect(rowChips(_item(grader: 'BGS', subtype: '9.5')), ['BGS9.5']);
    expect(rowChips(_item(grader: 'CGC', subtype: 'Pristine')), ['Pristine']);
    expect(rowChips(_item(grader: 'Ungraded', subtype: 'Near Mint')), isEmpty);
    expect(rowChips(_item(grader: '', subtype: '10')), isEmpty);
    expect(rowChips(_item(set: 'Unknown', number: '')), isEmpty);
  });

  testWidgets('ItemRow draws the chips from rowChips', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ItemRow(
          item: _item(set: 'Set A', grader: 'PSA', subtype: '10 GEM-MT', number: '074/071'),
          columns: const ['name', 'setName'],
        ),
      ),
    ));
    for (final t in ['ja', 'PSA10', '074/071']) {
      expect(find.text(t), findsOneWidget);
    }
  });
}
