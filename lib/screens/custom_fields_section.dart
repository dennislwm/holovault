import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../custom_field_logic.dart';
import '../database/database.dart';
import '../database/overrides_schema.dart';

String _fieldName(CustomColumn c) => 'cf.${c.name}';

/// REQ-043 (b): maps the form's raw values to a name-to-value map for
/// [AppDatabase.saveCustomFields]. Empty text and choice become null. A column
/// whose form key is absent (section not yet loaded) is skipped, so its stored
/// value is left alone.
Map<String, Object?> collectCustomValues(
  List<CustomColumn> registry,
  Map<String, dynamic> form,
) {
  final out = <String, Object?>{};
  for (final c in registry) {
    if (!form.containsKey(_fieldName(c))) continue;
    final v = form[_fieldName(c)];
    out[c.name] = switch (c.type) {
      CustomColumnType.text ||
      CustomColumnType.choice => (v is String && v.isNotEmpty) ? v : null,
      CustomColumnType.real => parseNumber(v as String?, whole: false),
      CustomColumnType.int => parseNumber(v as String?, whole: true),
      CustomColumnType.bool || CustomColumnType.date => v,
    };
  }
  return out;
}

/// REQ-043 (b): the "Custom fields" inputs, one per registry entry. Must be
/// placed inside a [FormBuilder] whose key is [formKey].
class CustomFieldsSection extends StatefulWidget {
  const CustomFieldsSection({
    super.key,
    required this.database,
    required this.importedId,
    required this.formKey,
    required this.registry,
  });

  final AppDatabase database;
  final String importedId;
  final GlobalKey<FormBuilderState> formKey;
  final List<CustomColumn> registry;

  @override
  State<CustomFieldsSection> createState() => _CustomFieldsSectionState();
}

class _CustomFieldsSectionState extends State<CustomFieldsSection> {
  late final Future<(MergedItem?, Map<String, List<String>>)> _load = _doLoad();

  Future<(MergedItem?, Map<String, List<String>>)> _doLoad() async {
    final row = await widget.database.mergedItemByImportedId(widget.importedId);
    final sugg = <String, List<String>>{};
    for (final c in widget.registry) {
      if (c.type == CustomColumnType.choice) {
        sugg[c.name] = suggestionList(await widget.database.storedValues(c));
      }
    }
    return (row, sugg);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _load,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        final (row, sugg) = data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in widget.registry)
              _field(c, row == null ? null : c.value(row), sugg[c.name] ?? []),
          ],
        );
      },
    );
  }

  Widget _field(CustomColumn c, Object? initial, List<String> options) {
    final name = _fieldName(c);
    final decoration = InputDecoration(labelText: c.name);
    switch (c.type) {
      case CustomColumnType.text:
        return FormBuilderTextField(
          name: name,
          initialValue: (initial as String?) ?? '',
          decoration: decoration,
        );
      case CustomColumnType.real:
      case CustomColumnType.int:
        final whole = c.type == CustomColumnType.int;
        return FormBuilderTextField(
          name: name,
          initialValue: initial?.toString() ?? '',
          decoration: decoration,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !whole,
            signed: true,
          ),
          validator: (v) => validateNumber(v, whole: whole),
        );
      case CustomColumnType.bool:
        return FormBuilderCheckbox(
          name: name,
          initialValue: initial as bool?,
          tristate: true,
          title: Text(c.name),
        );
      case CustomColumnType.choice:
        return FormBuilderField<String>(
          name: name,
          initialValue: initial as String?,
          builder: (field) => _ChoiceInput(
            label: c.name,
            options: options,
            initial: field.value ?? '',
            onText: field.didChange,
          ),
        );
      case CustomColumnType.date:
        return FormBuilderDateTimePicker(
          name: name,
          initialValue: initial as DateTime?,
          inputType: InputType.date,
          decoration: InputDecoration(
            labelText: c.name,
            // The field has no clear control of its own: clearing is
            // didChange(null), which also empties its text.
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () => widget.formKey.currentState?.fields[name]
                  ?.didChange(null),
            ),
          ),
        );
    }
  }
}

/// Suggestion input: the saved value is whatever the text controller holds
/// (typed text stays there; selecting a suggestion writes it there too).
class _ChoiceInput extends StatefulWidget {
  const _ChoiceInput({
    required this.label,
    required this.options,
    required this.initial,
    required this.onText,
  });

  final String label;
  final List<String> options;
  final String initial;
  final ValueChanged<String?> onText;

  @override
  State<_ChoiceInput> createState() => _ChoiceInputState();
}

class _ChoiceInputState extends State<_ChoiceInput> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => widget.onText(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focus,
      optionsBuilder: (v) => widget.options.where((o) => o.contains(v.text)),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        decoration: InputDecoration(labelText: widget.label),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    dense: true,
                    title: Text(o),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
