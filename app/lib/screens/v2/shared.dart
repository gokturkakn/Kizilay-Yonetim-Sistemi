import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_v2.dart';
import '../../core/layout.dart';
import '../../core/lookup_cache.dart';
import '../../core/session.dart';
import '../../core/strings.dart';
import '../../core/strings_v2.dart';
import '../../forms/dynamic_form.dart';
import '../../forms/field_spec.dart';
import '../../forms/form_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/attachments.dart';
import '../../widgets/common.dart';

/// Ekranlarda tekrar eden bağımlılık okuması.
extension V2Context on BuildContext {
  ApiV2 get api2 => read<ApiV2>();
  LookupCache get lookups => read<LookupCache>();
  Session get session => read<Session>();
  bool get isAdmin => read<Session>().isAdmin;
  bool get isSaha => !read<Session>().isAdmin;
}

/// §4.2 R4 — tanım kaynağını `DynamicForm` motoruna bağlar.
LookupResolver lookupResolverFor(LookupCache cache) {
  return (category, parentValue) async {
    final parentId = parentValue is int
        ? parentValue
        : int.tryParse(parentValue?.toString() ?? '');
    final items = await cache.items(category, parentId: parentId);
    return items
        .map((e) => FormOption(
              value: e.id,
              label: e.name,
              code: e.code,
              parentId: e.parentId,
            ))
        .toList();
  };
}

/// §4.3(a) — Bölge listesi `GET /regions`'tan gelir (§10/2 kararı).
Future<List<FormOption>> regionOptions(LookupCache cache) async {
  final regions = await cache.regions();
  return regions
      .map((r) => FormOption(value: r.id, label: r.name, code: r.code))
      .toList();
}

/// İl listesi; bölge seçiliyse o bölgeye daralır, boşsa 81 il.
Future<List<FormOption>> provinceOptions(
    LookupCache cache, Map<String, Object?> values) async {
  final regionId = values['region_id'] is int
      ? values['region_id'] as int
      : int.tryParse(values['region_id']?.toString() ?? '');
  final list = await cache.provinces(regionId: regionId);
  return list.map((p) => FormOption(value: p.id, label: p.name)).toList();
}

/// İlçe listesi (il seçilene kadar boş).
Future<List<FormOption>> districtOptions(
    LookupCache cache, Map<String, Object?> values) async {
  final provinceId = values['province_id'] is int
      ? values['province_id'] as int
      : int.tryParse(values['province_id']?.toString() ?? '');
  if (provinceId == null) return const [];
  final list = await cache.districts(provinceId);
  return list.map((d) => FormOption(value: d.id, label: d.name)).toList();
}

/// Teşkilat birimi seçenekleri (orgPicker) — arama + tür filtresi.
Future<List<FormOption>> orgUnitOptions(
  ApiV2 api, {
  String? type,
  int? provinceId,
  int? districtId,
}) async {
  final page = await api.orgUnits(
    type: type,
    provinceId: provinceId,
    districtId: districtId,
    limit: 300,
  );
  return page.data
      .map((u) => FormOption(
            value: u.id,
            label: u.name,
            subtitle: u.locationLabel.isEmpty ? null : u.locationLabel,
          ))
      .toList();
}

/// §2.2 — form ve detay panelleri `kContentMaxWidth` ile sınırlanır, ortalanır.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? kContentMaxWidth),
        child: child,
      ),
    );
  }
}

/// `>= 840` iki panelli düzen: solda `kListPaneWidth` liste, sağda detay/form.
/// `< 840`'ta klasik "listeye dokun → yeni sayfa aç" davranışı.
class TwoPaneLayout extends StatelessWidget {
  const TwoPaneLayout({
    super.key,
    required this.list,
    required this.detail,
    this.placeholder,
  });

  final Widget list;
  final Widget? detail;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (!layoutOf(context).isTwoPane) return list;
    return Row(
      children: [
        SizedBox(width: kListPaneWidth, child: list),
        const VerticalDivider(width: 1, color: kBorder),
        Expanded(
          child: detail ??
              placeholder ??
              const Center(
                child: Text('Listeden bir kayıt seçin.',
                    style: TextStyle(color: kTextSecondary)),
              ),
        ),
      ],
    );
  }
}

/// Yönetim Paneli tarzı giriş satırı (ikon + başlık + alt yazı + chevron).
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.note,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: kPrimary),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              if (note != null)
                Text(note!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kTextSecondary)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?trailing,
              const Icon(Icons.chevron_right, color: kTextSecondary),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Modül ana ekranlarındaki gezinme kartı ızgarası.
class NavCardGrid extends StatelessWidget {
  const NavCardGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final columns = layoutOf(context).navCardColumns;
    if (columns == 1) {
      return Column(
        children: [
          for (final c in cards)
            Padding(padding: const EdgeInsets.only(bottom: s12), child: c),
        ],
      );
    }
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: s12,
      mainAxisSpacing: s12,
      childAspectRatio: 3.2,
      children: cards,
    );
  }
}

/// Ortak form ekranı iskeleti — §4.2 R9/R10 ve §7.6 akışını uygular.
class FormScaffold extends StatefulWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.onSave,
    this.attachments,
    this.customFieldBuilder,
    this.footer,
    this.header,
  });

  final String title;
  final FormController controller;

  /// Kaydeder ve oluşan/güncellenen kaydın id'sini döndürür.
  final Future<int?> Function() onSave;

  final AttachmentController? attachments;
  final FieldBuilder? customFieldBuilder;
  final Widget? footer;
  final Widget? header;

  @override
  State<FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<FormScaffold> {
  final GlobalKey<DynamicFormState> _formKey = GlobalKey<DynamicFormState>();
  bool _saving = false;
  String? _partialUploadNote;

  Future<bool> _confirmExit() async {
    final att = widget.attachments;
    if (att != null && att.isUploading) {
      return showConfirmDialog(
        context,
        title: S2.ekCikisBaslik,
        body: S2.ekCikisGovde,
        confirmText: S2.cik,
      );
    }
    if (!widget.controller.isDirty) return true;
    return showConfirmDialog(
      context,
      title: S2.kirliBaslik,
      body: S2.kirliGovde,
      confirmText: S2.cik,
    );
  }

  Future<void> _save() async {
    final firstError = widget.controller.validateAll();
    if (firstError != null) {
      _formKey.currentState?.scrollToField(firstError);
      return;
    }
    setState(() => _saving = true);
    widget.controller.setSaving(true);
    try {
      final id = await widget.onSave();
      // §7.6 — (a) kayıt · (b) kuyruktaki dosyalar · (c) çıkış
      final att = widget.attachments;
      if (id != null && att != null && att.queue.isNotEmpty) {
        final failed = await att.uploadQueue(id);
        if (failed > 0) {
          setState(() {
            _saving = false;
            _partialUploadNote = S2.ekKismiHata(failed);
          });
          widget.controller.setSaving(false);
          return; // kayıt geri alınmaz, ekran kapanmaz
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      widget.controller.setSaving(false);
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachments;
    final uploading = att?.isUploading ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_partialUploadNote != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(s16, s16, s16, 0),
                          child: Container(
                            padding: const EdgeInsets.all(s12),
                            decoration: BoxDecoration(
                              color: kWarningContainer,
                              borderRadius: BorderRadius.circular(r8),
                            ),
                            child: Text(_partialUploadNote!),
                          ),
                        ),
                      ?widget.header,
                      DynamicForm(
                        key: _formKey,
                        controller: widget.controller,
                        customFieldBuilder: widget.customFieldBuilder,
                      ),
                      ?widget.footer,
                    ],
                  ),
                ),
              ),
            ),
            FormActionBar(
              onSave: _save,
              onCancel: () async {
                if (await _confirmExit() && context.mounted) {
                  if (!context.mounted) return;
                  Navigator.of(context).pop(false);
                }
              },
              saving: _saving,
              savingLabel: uploading ? 'Dosyalar yükleniyor...' : null,
              disabledNote: uploading ? S2.ekYukleniyorUyari : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste ekranlarında tekrar eden "yükleniyor / hata / boş" sarmalayıcısı.
class AsyncListBody<T> extends StatelessWidget {
  const AsyncListBody({
    super.key,
    required this.loading,
    required this.error,
    required this.items,
    required this.itemBuilder,
    required this.onRetry,
    required this.emptyMessage,
    this.emptySubMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.header,
    this.padding,
  });

  final bool loading;
  final Object? error;
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final VoidCallback onRetry;
  final String emptyMessage;
  final String? emptySubMessage;
  final IconData emptyIcon;
  final Widget? header;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ErrorState(
          onRetry: onRetry, message: v2ErrorMessage(error!));
    }
    if (items.isEmpty) {
      return Column(
        children: [
          ?header,
          Expanded(
            child: EmptyState(
              icon: emptyIcon,
              message: emptyMessage,
              subMessage: emptySubMessage,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(s16),
      itemCount: items.length + (header != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: s12),
      itemBuilder: (context, i) {
        if (header != null) {
          if (i == 0) return header!;
          return itemBuilder(context, items[i - 1]);
        }
        return itemBuilder(context, items[i]);
      },
    );
  }
}

/// Basit satır kartı (liste kayıtları için ortak desen).
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.title,
    required this.lines,
    this.trailing,
    this.trailingText,
    this.leading,
    this.onTap,
    this.actions,
    this.onAction,
    this.footer,
  });

  final String title;
  final List<String> lines;
  final Widget? trailing;
  final String? trailingText;
  final Widget? leading;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>>? actions;
  final ValueChanged<String>? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r12),
        child: Padding(
          padding: const EdgeInsets.all(s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: s12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(title,
                                style: theme.textTheme.titleMedium)),
                        if (trailingText != null)
                          Text(trailingText!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: kTextSecondary)),
                        if (trailing != null) ...[
                          const SizedBox(width: s8),
                          trailing!,
                        ],
                      ],
                    ),
                    for (final line in lines)
                      if (line.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: s4),
                          child: Text(line,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: kTextSecondary)),
                        ),
                    ?footer,
                  ],
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kTextSecondary),
                  itemBuilder: (_) => actions!,
                  onSelected: (v) => onAction?.call(v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sil onayı — §9.9 ortak kalıbı.
Future<bool> confirmDelete(BuildContext context, String title) =>
    showConfirmDialog(
      context,
      title: title,
      body: S2.dlgGeriAlinamaz,
      confirmText: Str.sil,
      destructive: true,
    );
