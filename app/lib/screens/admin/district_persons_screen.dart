import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/person_list_tile.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

/// İlçe Kişileri — UX §3.8. Sonsuz kaydırma (limit 50).
class DistrictPersonsScreen extends StatefulWidget {
  const DistrictPersonsScreen(
      {super.key, required this.province, required this.district});

  final Province province;
  final District district;

  @override
  State<DistrictPersonsScreen> createState() =>
      _DistrictPersonsScreenState();
}

class _DistrictPersonsScreenState extends State<DistrictPersonsScreen> {
  static const _limit = 50;

  final _scrollController = ScrollController();
  Timer? _debounce;

  bool? _isActive = true;
  String _query = '';

  final List<Person> _persons = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _query = v.trim();
      _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _persons.clear();
      _page = 1;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    final api = context.read<Api>();
    try {
      final result = await api.persons(
        districtId: widget.district.id,
        isActive: _isActive,
        q: _query.isEmpty ? null : _query,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _persons.addAll(result.data);
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _persons.length >= _total) return;
    setState(() {
      _loadingMore = true;
      _page += 1;
    });
    await _fetch();
  }

  Future<void> _addPerson() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PersonFormScreen(
        initialProvinceId: widget.province.id,
        initialDistrictId: widget.district.id,
        initialUnitType: 'ilce_teskilati',
      ),
    ));
    if (saved == true && mounted) _reload();
  }

  Future<void> _openPerson(Person p) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonDetailScreen(personId: p.id),
    ));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<Session>().isAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(widget.district.name)),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addPerson,
              icon: const Icon(Icons.person_add),
              label: const Text('Kişi Ekle'),
            )
          : null,
      body: Column(
        children: [
          SearchField(hint: 'Kişi ara...', onChanged: _onSearchChanged),
          Align(
            alignment: Alignment.centerLeft,
            child: ActiveFilterChips(
              value: _isActive,
              onChanged: (v) {
                setState(() => _isActive = v);
                _reload();
              },
            ),
          ),
          const SizedBox(height: s4),
          Expanded(child: _buildBody(isAdmin)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isAdmin) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(onRetry: _reload);
    }
    if (_persons.isEmpty) {
      if (_query.isNotEmpty) {
        return const EmptyState(
          icon: Icons.search_off_outlined,
          message: 'Aramanızla eşleşen kişi bulunamadı.',
        );
      }
      return EmptyState(
        icon: Icons.person_off_outlined,
        message: 'Bu ilçede kayıtlı kişi bulunmuyor.',
        actionLabel: isAdmin ? 'Kişi Ekle' : null,
        onAction: isAdmin ? _addPerson : null,
      );
    }
    final hasMore = _persons.length < _total;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(s16, s4, s16, 88),
        itemCount: _persons.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: s8),
        itemBuilder: (context, i) {
          if (i >= _persons.length) {
            return const Padding(
              padding: EdgeInsets.all(s16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final p = _persons[i];
          return PersonListTile(
            person: p,
            locationLabel:
                '${widget.province.name} / ${widget.district.name}',
            onTap: () => _openPerson(p),
          );
        },
      ),
    );
  }
}
