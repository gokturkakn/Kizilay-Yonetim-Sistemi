import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/formatters.dart';
import '../../core/layout.dart';
import '../../core/strings.dart';
import '../../core/strings_v2.dart';
import '../../forms/field_spec.dart';
import '../../forms/form_controller.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';

/// `type: personPicker` alanı — docs/UX-V2.md §4.6.
///
/// v1 §3.5'teki arama listesi deseni (300 ms debounce, kişi kartı).
class PersonPickerField extends StatelessWidget {
  const PersonPickerField({
    super.key,
    required this.spec,
    required this.controller,
    this.onCreatePerson,
  });

  final FieldSpec spec;
  final FormController controller;
  final Future<Person?> Function()? onCreatePerson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = controller.selectedOption(spec.key);
    final error = controller.displayError(spec);
    final enabled = controller.isEnabled(spec);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(spec.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kTextSecondary)),
            ),
            if (onCreatePerson != null)
              TextButton(
                onPressed: () async {
                  final person = await onCreatePerson!();
                  if (person == null) return;
                  controller.seedOptions(spec.key, [
                    FormOption(value: person.id, label: person.fullName),
                  ]);
                  controller.setValue(spec.key, person.id);
                },
                child: const Text('Yeni Kişi Ekle'),
              ),
          ],
        ),
        const SizedBox(height: s4),
        InkWell(
          onTap: enabled
              ? () async {
                  final person = await showPersonPicker(context);
                  if (person == null) return;
                  controller.markTouched(spec.key);
                  controller.seedOptions(spec.key, [
                    FormOption(value: person.id, label: person.fullName),
                  ]);
                  controller.setValue(spec.key, person.id);
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              enabled: enabled,
              suffixIcon:
                  const Icon(Icons.chevron_right, color: kTextSecondary),
            ),
            child: Text(
              selected?.label ?? Str.secilmedi,
              style: TextStyle(
                color: selected == null ? kTextDisabled : kTextPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: s4),
            child: Text(error,
                style: theme.textTheme.bodySmall?.copyWith(color: kError)),
          ),
      ],
    );
  }
}

/// Kişi arama seçicisi — `< 600` tam sayfa, `>= 600` dialog.
Future<Person?> showPersonPicker(BuildContext context) {
  if (layoutOf(context) == LayoutClass.compact) {
    return Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: _PersonPickerBody()),
        fullscreenDialog: true,
      ),
    );
  }
  return showDialog<Person>(
    context: context,
    builder: (_) => const Dialog(
      child: SizedBox(width: 480, height: 560, child: _PersonPickerBody()),
    ),
  );
}

class _PersonPickerBody extends StatefulWidget {
  const _PersonPickerBody();

  @override
  State<_PersonPickerBody> createState() => _PersonPickerBodyState();
}

class _PersonPickerBodyState extends State<_PersonPickerBody> {
  Timer? _debounce;
  String _query = '';
  bool _loading = true;
  List<Person> _people = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await context.read<Api>().persons(
            q: _query.trim().isEmpty ? null : _query.trim(),
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        _people = page.data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _people = const [];
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String v) {
    _query = v;
    _debounce?.cancel();
    // v1 §3.5 — 300 ms debounce.
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(s16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Kişi ara...',
                      prefixIcon: Icon(Icons.search, color: kTextSecondary),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _people.isEmpty
                    ? Center(
                        child: Text(S2.aramaBos,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: kTextSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _people.length,
                        itemBuilder: (context, i) {
                          final p = _people[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kPrimaryContainer,
                              child: Text(
                                Formats.initials(p.firstName, p.lastName),
                                style: const TextStyle(
                                    color: kPrimary, fontSize: 13),
                              ),
                            ),
                            title: Text(p.fullName,
                                style: theme.textTheme.titleMedium),
                            subtitle: Text(p.provinceName ?? ''),
                            onTap: () => Navigator.of(context).pop(p),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
