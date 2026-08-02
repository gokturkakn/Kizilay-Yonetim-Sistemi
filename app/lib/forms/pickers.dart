import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/layout.dart';
import '../core/strings_v2.dart';
import '../theme/tokens.dart';
import 'field_spec.dart';

/// Aranabilir seçici — docs/UX-V2.md §4.2 R5.
///
/// `< 600`: tam sayfa · `>= 600`: 480×560 dialog.
/// Klavye seçicide **açılmaz**; alan asla yazılabilir değildir (R6).
Future<FormOption?> showOptionPicker(
  BuildContext context, {
  required String title,
  required List<FormOption> options,
  FormOption? selected,
  String? footerNote,
  String? emptyMessage,
}) {
  final compact = layoutOf(context) == LayoutClass.compact;
  final body = _OptionPickerBody(
    title: title,
    options: options,
    selected: selected,
    footerNote: footerNote,
    emptyMessage: emptyMessage,
    fullPage: compact,
  );
  if (compact) {
    return Navigator.of(context).push<FormOption>(
      MaterialPageRoute(builder: (_) => body, fullscreenDialog: true),
    );
  }
  return showDialog<FormOption>(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(width: 480, height: 560, child: body),
    ),
  );
}

class _OptionPickerBody extends StatefulWidget {
  const _OptionPickerBody({
    required this.title,
    required this.options,
    required this.fullPage,
    this.selected,
    this.footerNote,
    this.emptyMessage,
  });

  final String title;
  final List<FormOption> options;
  final FormOption? selected;
  final String? footerNote;
  final String? emptyMessage;
  final bool fullPage;

  @override
  State<_OptionPickerBody> createState() => _OptionPickerBodyState();
}

class _OptionPickerBodyState extends State<_OptionPickerBody> {
  String _query = '';

  List<FormOption> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    return widget.options
        .where((o) => Formats.trContains(o.label, _query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _filtered;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.fullPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(s16, s16, s8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(s16),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '${widget.title} ara...',
              prefixIcon: const Icon(Icons.search, color: kTextSecondary),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(s24),
                    child: Text(
                      _query.trim().isEmpty
                          ? (widget.emptyMessage ?? S2.aramaBos)
                          : S2.aramaBos,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: kTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final o = list[i];
                    final isSelected = widget.selected?.value == o.value;
                    return ListTile(
                      title: Text(o.label, style: theme.textTheme.titleMedium),
                      subtitle: o.subtitle == null
                          ? null
                          : Text(o.subtitle!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: kTextSecondary)),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: kPrimary)
                          : null,
                      onTap: () => Navigator.of(context).pop(o),
                    );
                  },
                ),
        ),
        if (widget.footerNote != null)
          Padding(
            padding: const EdgeInsets.all(s16),
            child: Text(
              widget.footerNote!,
              style: theme.textTheme.bodySmall?.copyWith(color: kTextSecondary),
            ),
          ),
      ],
    );

    if (!widget.fullPage) return content;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(child: content),
    );
  }
}
