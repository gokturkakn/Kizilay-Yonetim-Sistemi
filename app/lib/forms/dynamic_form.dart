import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../core/layout.dart';
import '../core/strings.dart';
import '../core/strings_v2.dart';
import '../theme/tokens.dart';
import 'field_spec.dart';
import 'form_controller.dart';
import 'pickers.dart';

/// Özel alan çizici (orgPicker / personPicker / attachment gibi ekrana özgü
/// alanlar için). `null` dönerse motor kendi varsayılanını çizer.
typedef FieldBuilder = Widget? Function(
  BuildContext context,
  FieldSpec spec,
  FormController controller,
);

/// Tek form motoru — docs/UX-V2.md §4.
///
/// Uygulamadaki **bütün** formlar bu motorla kurulur; ekranlar yalnız
/// `List<FieldSpec>` yazar.
class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.controller,
    this.customFieldBuilder,
    this.padding = const EdgeInsets.all(s16),
  });

  final FormController controller;
  final FieldBuilder? customFieldBuilder;
  final EdgeInsets padding;

  @override
  State<DynamicForm> createState() => DynamicFormState();
}

class DynamicFormState extends State<DynamicForm> {
  final Map<String, GlobalKey> _fieldKeys = {};
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAllOptions();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Kademeli alanların listeleri üst değer değişince yeniden yüklenir (R1.2).
    for (final f in widget.controller.fields) {
      if (!widget.controller.isVisible(f)) continue;
      if (!f.type.needsOptions && f.optionsBuilder == null) continue;
      final state = widget.controller.optionsFor(f.key);
      if (state.loading || state.loaded) continue;
      if (!widget.controller.isEnabled(f) && f.isCascaded) continue;
      widget.controller.loadOptions(f);
    }
    setState(() {});
  }

  /// §4.2 R8 — ilk hatalı alana kaydır ve odaklan.
  void scrollToField(String key) {
    final ctx = _fieldKeys[key]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.1,
        curve: Curves.easeOut);
  }

  TextEditingController _textControllerFor(FieldSpec spec) {
    final existing = _textControllers[spec.key];
    final value = widget.controller.value(spec.key);
    final text = spec.type == FieldType.decimal && value is num
        ? FormController.formatDecimal(value)
        : (value?.toString() ?? '');
    if (existing != null) {
      if (existing.text != text &&
          !existing.selection.isValid == false &&
          existing.text.trim() != text.trim()) {
        // Değer dışarıdan değiştiyse (kademeli temizleme) senkronla.
        if (widget.controller.value(spec.key) == null && existing.text.isNotEmpty) {
          existing.text = '';
        }
      }
      return existing;
    }
    final c = TextEditingController(text: text);
    _textControllers[spec.key] = c;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final children = <Widget>[];

    if (c.submitted && !c.isValid) {
      children.add(const _RequiredBanner());
      children.add(const SizedBox(height: s16));
    }

    String? lastSection;
    final sectioned = c.fields.where((f) => f.section != null).isNotEmpty;
    for (final spec in c.fields) {
      final visible = c.isVisible(spec);
      if (visible && sectioned && spec.section != lastSection) {
        lastSection = spec.section;
        if (spec.section != null) {
          children.add(Padding(
            padding: EdgeInsets.only(
                top: children.isEmpty ? 0 : s24, bottom: s8),
            child: Text(spec.section!,
                style: Theme.of(context).textTheme.titleSmall),
          ));
        }
      }
      children.add(_buildAnimatedField(spec, visible));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: widget.padding, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        )),
      ],
    );
  }

  /// §4.2 R2.1/R2.4 — gizli alan DOM'dan kaldırılır; geçiş 150 ms easeOut.
  Widget _buildAnimatedField(FieldSpec spec, bool visible) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: visible
          ? AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Padding(
                key: _fieldKeys.putIfAbsent(spec.key, () => GlobalKey()),
                padding: const EdgeInsets.only(bottom: s16),
                child: _buildField(spec),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildField(FieldSpec spec) {
    final custom = widget.customFieldBuilder?.call(context, spec, widget.controller);
    if (custom != null) return custom;

    switch (spec.type) {
      case FieldType.text:
      case FieldType.email:
      case FieldType.password:
      case FieldType.multiline:
      case FieldType.number:
      case FieldType.decimal:
        return _TextInputField(
          spec: spec,
          controller: widget.controller,
          textController: _textControllerFor(spec),
        );
      case FieldType.date:
        return _DateField(spec: spec, controller: widget.controller);
      case FieldType.segment:
        return _SegmentField(spec: spec, controller: widget.controller);
      case FieldType.lookup:
      case FieldType.picker:
      // §4.6 — birim seçici de aranabilir seçici desenini kullanır.
      case FieldType.orgPicker:
        return _ChoiceField(spec: spec, controller: widget.controller);
      case FieldType.switchField:
        return _SwitchField(spec: spec, controller: widget.controller);
      case FieldType.readOnly:
        return _ReadOnlyField(spec: spec, controller: widget.controller);
      case FieldType.personPicker:
      case FieldType.attachment:
      case FieldType.matrix:
      case FieldType.dateRange:
        // Ekran tarafından `customFieldBuilder` ile sağlanır.
        return const SizedBox.shrink();
    }
  }
}

class _RequiredBanner extends StatelessWidget {
  const _RequiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(s12),
      decoration: BoxDecoration(
        color: kErrorContainer,
        borderRadius: BorderRadius.circular(r8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kError, size: 20),
          const SizedBox(width: s8),
          Expanded(
            child: Text(S2.zorunluBanner,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: kError)),
          ),
        ],
      ),
    );
  }
}

/// Ortak alan sarmalayıcısı: etiket + alan + yardımcı/hata metni.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.spec,
    required this.controller,
    required this.child,
  });

  final FieldSpec spec;
  final FormController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = controller.displayError(spec);
    final helper = controller.helperFor(spec);
    final disabledHint = controller.isEnabled(spec) ? null : controller.disabledHint(spec);
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
            // §4.2 R11 — bağlamdan kilitli alan.
            if (spec.locked)
              const Icon(Icons.lock_outline, size: 14, color: kTextDisabled),
          ],
        ),
        const SizedBox(height: s4),
        child,
        if (error != null) ...[
          const SizedBox(height: s4),
          Text(error,
              style: theme.textTheme.bodySmall?.copyWith(color: kError)),
        ] else if (disabledHint != null) ...[
          const SizedBox(height: s4),
          Text(disabledHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kTextSecondary)),
        ] else if (helper != null) ...[
          const SizedBox(height: s4),
          Text(helper,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kTextSecondary)),
        ],
      ],
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.spec,
    required this.controller,
    required this.textController,
  });

  final FieldSpec spec;
  final FormController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.isEnabled(spec);
    TextInputType keyboard;
    List<TextInputFormatter> formatters = const [];
    switch (spec.type) {
      case FieldType.number:
        keyboard = TextInputType.number;
        formatters = [FilteringTextInputFormatter.digitsOnly];
      case FieldType.decimal:
        keyboard = const TextInputType.numberWithOptions(decimal: true);
        formatters = [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
        ];
      case FieldType.email:
        keyboard = TextInputType.emailAddress;
      case FieldType.multiline:
        keyboard = TextInputType.multiline;
      default:
        keyboard = TextInputType.text;
    }
    return _FieldShell(
      spec: spec,
      controller: controller,
      child: TextField(
        controller: textController,
        enabled: enabled,
        obscureText: spec.type == FieldType.password,
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLength: spec.maxLength,
        maxLines: spec.type == FieldType.multiline ? 4 : 1,
        decoration: InputDecoration(
          hintText: spec.hint,
          isDense: true,
          counterText: '',
          errorText: null,
        ),
        onChanged: (v) {
          controller.markTouched(spec.key);
          controller.setValue(spec.key, v.isEmpty ? null : v, silent: true);
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.spec, required this.controller});

  final FieldSpec spec;
  final FormController controller;

  @override
  Widget build(BuildContext context) {
    final raw = controller.stringValue(spec.key);
    final parsed = Formats.parseApiDate(raw);
    final enabled = controller.isEnabled(spec);
    return _FieldShell(
      spec: spec,
      controller: controller,
      child: InkWell(
        onTap: !enabled
            ? null
            : () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed ?? now,
                  firstDate: DateTime(2000),
                  lastDate: spec.noFutureDates ? now : DateTime(now.year + 10),
                  locale: const Locale('tr'),
                );
                if (picked != null) {
                  controller.markTouched(spec.key);
                  controller.setValue(spec.key, Formats.apiDate(picked));
                }
              },
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            enabled: enabled,
            suffixIcon: const Icon(Icons.calendar_today_outlined,
                size: 18, color: kTextSecondary),
          ),
          child: Text(
            parsed == null ? (spec.hint ?? Str.secilmedi) : Formats.date(parsed),
            style: TextStyle(
              color: parsed == null ? kTextDisabled : kTextPrimary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentField extends StatelessWidget {
  const _SegmentField({required this.spec, required this.controller});

  final FieldSpec spec;
  final FormController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.optionsFor(spec.key);
    final options = state.options;
    // §4.3(d) — 3'ten fazla seçenek varsa dropdown'a düşülür.
    if (options.length > 3) {
      return _ChoiceField(spec: spec, controller: controller);
    }
    if (options.isEmpty) {
      return _FieldShell(
        spec: spec,
        controller: controller,
        child: const SizedBox(height: 4),
      );
    }
    final selected = controller.value(spec.key);
    return _FieldShell(
      spec: spec,
      controller: controller,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<Object>(
          segments: [
            for (final o in options)
              ButtonSegment<Object>(value: o.value, label: Text(o.label)),
          ],
          selected: selected == null ? <Object>{} : {selected},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: controller.isEnabled(spec)
              ? (sel) {
                  controller.markTouched(spec.key);
                  controller.setValue(
                      spec.key, sel.isEmpty ? null : sel.first);
                }
              : null,
        ),
      ),
    );
  }
}

/// `lookup` / `picker` alanı — §4.2 R5 (15 kuralı) ve R6 (serbest metin yasağı).
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({required this.spec, required this.controller});

  final FieldSpec spec;
  final FormController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.optionsFor(spec.key);
    final enabled = controller.isEnabled(spec) && !state.isEmptyList;
    final selected = controller.selectedOption(spec.key);

    // Yükleme sırasında alan kilitli + sağda 16 px spinner (R1.2).
    final suffix = state.loading
        ? const Padding(
            padding: EdgeInsets.all(s12),
            child: SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : null;

    // > 15 seçenek veya `picker`/`orgPicker` → aranabilir seçici (klavye açılmaz).
    final useSearch = spec.type == FieldType.picker ||
        spec.type == FieldType.orgPicker ||
        state.useSearchPicker;

    if (!useSearch) {
      final value = controller.value(spec.key);
      final hasValue = state.options.any((o) => o.value == value);
      return _FieldShell(
        spec: spec,
        controller: controller,
        child: DropdownButtonFormField<Object?>(
          initialValue: hasValue ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            enabled: enabled,
            suffixIcon: suffix,
          ),
          hint: Text(spec.hint ?? Str.secilmedi,
              style: const TextStyle(color: kTextDisabled)),
          items: [
            if (spec.emptyOptionLabel != null)
              DropdownMenuItem<Object?>(
                  value: null, child: Text(spec.emptyOptionLabel!)),
            for (final o in state.options)
              DropdownMenuItem<Object?>(value: o.value, child: Text(o.label)),
          ],
          onChanged: enabled && !state.loading
              ? (v) {
                  controller.markTouched(spec.key);
                  controller.setValue(spec.key, v);
                }
              : null,
        ),
      );
    }

    return _FieldShell(
      spec: spec,
      controller: controller,
      child: InkWell(
        onTap: enabled && !state.loading
            ? () async {
                final picked = await showOptionPicker(
                  context,
                  title: spec.label,
                  options: [
                    if (spec.emptyOptionLabel != null)
                      FormOption(
                          value: _emptySentinel, label: spec.emptyOptionLabel!),
                    ...state.options,
                  ],
                  selected: selected,
                  footerNote: S2.tanimEkleUyari,
                );
                if (picked != null) {
                  controller.markTouched(spec.key);
                  controller.setValue(spec.key,
                      picked.value == _emptySentinel ? null : picked.value);
                }
              }
            : null,
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            enabled: enabled,
            suffixIcon: suffix ??
                const Icon(Icons.chevron_right, color: kTextSecondary),
          ),
          child: Text(
            selected?.label ??
                spec.emptyOptionLabel ??
                spec.hint ??
                Str.secilmedi,
            style: TextStyle(
              color: selected == null ? kTextDisabled : kTextPrimary,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

const Object _emptySentinel = '__empty__';

class _SwitchField extends StatelessWidget {
  const _SwitchField({required this.spec, required this.controller});

  final FieldSpec spec;
  final FormController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value(spec.key) == true;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(spec.label),
      subtitle: spec.helper == null ? null : Text(spec.helper!),
      value: value,
      onChanged: controller.isEnabled(spec)
          ? (v) => controller.setValue(spec.key, v)
          : null,
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.spec, required this.controller});

  final FieldSpec spec;
  final FormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helper = spec.helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(spec.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: kTextSecondary)),
            ),
            Expanded(
              flex: 3,
              child: Text(controller.stringValue(spec.key) ?? Str.bos,
                  style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
        // Salt okunur alanın gerekçesi (ör. "Rolünüzü yalnızca genel merkez
        // değiştirebilir.") alanın hemen altında durur.
        if (helper != null) ...[
          const SizedBox(height: s4),
          Text(helper,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: kTextSecondary)),
        ],
      ],
    );
  }
}

/// §4.2 R10 — Kaydet çubuğu.
///
/// `< 840`: tam genişlik `FilledButton`.
/// `>= 840`: sağa yaslı sabit eylem çubuğu (`Vazgeç` + `Kaydet`), üstünde
/// 1 px `kBorder` ayraç.
class FormActionBar extends StatelessWidget {
  const FormActionBar({
    super.key,
    required this.onSave,
    this.onCancel,
    this.saving = false,
    this.savingLabel,
    this.disabledNote,
  });

  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final bool saving;
  final String? savingLabel;
  final String? disabledNote;

  @override
  Widget build(BuildContext context) {
    final twoPane = layoutOf(context).isTwoPane;
    final label = saving ? (savingLabel ?? 'Kaydediliyor...') : Str.kaydet;
    final button = FilledButton(
      onPressed: saving || disabledNote != null ? null : onSave,
      child: saving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kOnPrimary)),
                const SizedBox(width: s8),
                Text(label),
              ],
            )
          : Text(label),
    );

    final note = disabledNote == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: s8),
            child: Text(disabledNote!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary)),
          );

    if (!twoPane) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(s16, 0, s16, s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [?note, button],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder)),
        color: kSurface,
      ),
      padding: const EdgeInsets.all(s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ?note,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null)
                OutlinedButton(
                    onPressed: saving ? null : onCancel,
                    child: const Text(Str.vazgec)),
              const SizedBox(width: s12),
              button,
            ],
          ),
        ],
      ),
    );
  }
}
