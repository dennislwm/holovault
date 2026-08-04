import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holovault/screens/collection_list_screen.dart';

void main() {
  test('parseImportFile parses a CSV file, header row and quoted commas', () async {
    final file = File(
      '${Directory.systemTemp.path}/holovault_test_import.csv',
    );
    await file.writeAsString(
      'importedId,name,extra\ncard-1,"Charizard, Base Set",\ncard-2,Blastoise,rare\n',
    );

    final rows = await parseImportFile(file.path);

    expect(rows, [
      {'importedId': 'card-1', 'name': 'Charizard, Base Set', 'extra': ''},
      {'importedId': 'card-2', 'name': 'Blastoise', 'extra': 'rare'},
    ]);

    await file.delete();
  });

  test('parseImportFile parses a JSON file', () async {
    final file = File(
      '${Directory.systemTemp.path}/holovault_test_import.json',
    );
    await file.writeAsString(
      '[{"importedId": "card-1", "name": "Charizard"}]',
    );

    final rows = await parseImportFile(file.path);

    expect(rows, [
      {'importedId': 'card-1', 'name': 'Charizard'},
    ]);

    await file.delete();
  });
}
