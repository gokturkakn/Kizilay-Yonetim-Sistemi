import 'package:flutter/material.dart';

import '../../../core/api_v2.dart';
import '../../../core/strings_v2.dart';
import '../../../models/models_v2.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../shared.dart';

/// E-6A · İçerik Yönetimi — docs/UX-V2.md §6.5.
class ContentBlockListScreen extends StatefulWidget {
  const ContentBlockListScreen({super.key});

  @override
  State<ContentBlockListScreen> createState() => _ContentBlockListScreenState();
}

class _ContentBlockListScreenState extends State<ContentBlockListScreen> {
  bool _loading = true;
  Object? _error;
  List<ContentBlock> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.api2.contentBlocks();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('İçerik Yönetimi')),
      body: AsyncListBody<ContentBlock>(
        loading: _loading,
        error: _error,
        items: _items,
        onRetry: _load,
        emptyIcon: Icons.article_outlined,
        emptyMessage: S2.bosIcerik,
        itemBuilder: (context, b) => Card(
          child: ListTile(
            title: Text(b.title, style: theme.textTheme.titleMedium),
            subtitle: Text(
              b.body.split('\n').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, color: kTextSecondary),
            onTap: () async {
              final saved =
                  await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => ContentBlockFormScreen(block: b),
              ));
              if (saved == true) _load();
            },
          ),
        ),
      ),
    );
  }
}

/// İçerik düzenleme ekranı — canlı önizleme kartıyla.
class ContentBlockFormScreen extends StatefulWidget {
  const ContentBlockFormScreen({super.key, required this.block});

  final ContentBlock block;

  @override
  State<ContentBlockFormScreen> createState() => _ContentBlockFormScreenState();
}

class _ContentBlockFormScreenState extends State<ContentBlockFormScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.block.title);
  late final TextEditingController _body =
      TextEditingController(text: widget.block.body);
  String? _titleError;
  String? _bodyError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _titleError = _title.text.trim().isEmpty ? S2.vBaslik : null;
      _bodyError = _body.text.trim().isEmpty ? S2.vMetin : null;
    });
    if (_titleError != null || _bodyError != null) return;
    setState(() => _saving = true);
    try {
      await context.api2.saveContentBlock(
          widget.block.key, _title.text.trim(), _body.text.trim());
      if (!mounted) return;
      showAppSnackBar(context, S2.basariIcerik);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, v2ErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('İçerik Yönetimi')),
      body: SingleChildScrollView(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.all(s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Başlık',
                      errorText: _titleError,
                      isDense: true),
                ),
                const SizedBox(height: s16),
                TextField(
                  controller: _body,
                  maxLines: 8,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Metin',
                      errorText: _bodyError,
                      alignLabelWithHint: true),
                ),
                const SizedBox(height: s16),
                Text('Önizleme', style: theme.textTheme.titleSmall),
                const SizedBox(height: s8),
                // §6.1.1 görünümüyle birebir önizleme kartı.
                Container(
                  decoration: BoxDecoration(
                    color: kPrimaryContainer,
                    borderRadius: BorderRadius.circular(r12),
                    border:
                        const Border(left: BorderSide(color: kPrimary, width: 3)),
                  ),
                  padding: const EdgeInsets.all(s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: kPrimary, size: 20),
                          const SizedBox(width: s8),
                          Expanded(
                            child: Text(_title.text,
                                style: theme.textTheme.titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: s4),
                      Text(_body.text, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: s24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
