import 'dart:async';
import 'package:flutter/material.dart';
import '../models/survey_submission.dart';
import '../services/survey_service.dart';
import '../theme/app_theme.dart';
import 'survey_screen.dart';

/// The logged-in surveyor's submitted records, newest first, with search
/// and paginated loading. Tapping a record opens it for editing.
class HistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HistoryScreen({super.key, required this.user});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  final List<SurveySubmission> _records = [];
  int _page = 0;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;

  // Incremented on every fresh load so late responses of an older
  // search can't mix into the current list.
  int _generation = 0;

  bool get _hasMore => _page < _totalPages;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 300) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _generation++;
    setState(() {
      _records.clear();
      _page = 0;
      _totalPages = 1;
      _total = 0;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await SurveyService.fetchHistory(
        submittedBy: widget.user['id'],
        page: _page + 1,
        limit: _pageSize,
        search: _searchController.text,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _records.addAll(result.records);
        _page++;
        _totalPages = result.totalPages;
        _total = result.total;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Could not load surveys. Check your connection.');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
    setState(() {}); // toggles the clear button
  }

  Future<void> _openRecord(SurveySubmission record) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SurveyScreen(user: widget.user, initial: record),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey updated successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Surveys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            Text('Tap a survey to view or edit', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search house no, owner, property ID, mohalla…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
              ),
            ),
          ),
          if (_page > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _total == 1 ? '1 survey' : '$_total surveys',
                  style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_records.isEmpty) {
      final Widget content;
      if (_loading) {
        content = const CircularProgressIndicator();
      } else if (_error != null) {
        content = _Message(
          icon: Icons.cloud_off_outlined,
          text: _error!,
          action: TextButton(onPressed: _refresh, child: const Text('Retry')),
        );
      } else {
        content = _Message(
          icon: Icons.inbox_outlined,
          text:
              _searchController.text.trim().isEmpty
                  ? 'No surveys submitted yet.'
                  : 'No surveys match your search.',
        );
      }
      // Scrollable so pull-to-refresh still works on an empty list.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 160, child: Center(child: content)),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _records.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i < _records.length) {
          return _RecordCard(record: _records[i], onTap: () => _openRecord(_records[i]));
        }
        // Footer: loader, retry, or end-of-list marker.
        if (_loading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_error != null) {
          return Center(child: TextButton(onPressed: _loadMore, child: const Text('Failed to load more. Retry')));
        }
        if (_hasMore) {
          return Center(child: TextButton(onPressed: _loadMore, child: const Text('Load more')));
        }
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: Text('— End of list —', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  final SurveySubmission record;
  final VoidCallback onTap;

  const _RecordCard({required this.record, required this.onTap});

  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final owner = record.ownerName?.trim();
    final place = [
      if (record.wardNoOrName?.isNotEmpty ?? false) 'Ward ${record.wardNoOrName}',
      if (record.mohallaName?.isNotEmpty ?? false) record.mohallaName!,
    ].join(' · ');
    final photoCount =
        [record.frontPhotoUrl, record.rightSidePhotoUrl, record.leftSidePhotoUrl]
            .where((u) => u?.isNotEmpty ?? false)
            .length;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3EEEC)),
          ),
          child: Row(
            children: [
              // No photo thumbnails here: photos are only fetched on "View"
              // inside the edit form, to avoid blob egress cost.
              _Thumb(photoCount: photoCount),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner == null || owner.isEmpty ? 'Unnamed owner' : owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'House ${record.houseNo ?? '—'}'
                      '${record.propertyId?.isNotEmpty ?? false ? ' · ID ${record.propertyId}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '#${record.id} · ${_date(record.submittedAt)}'
                      '${record.updatedAt != null ? ' · edited' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final int photoCount;

  const _Thumb({required this.photoCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_work_outlined, color: AppColors.primary, size: 22),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 2),
              Text(
                '$photoCount/3',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
        if (action != null) action!,
      ],
    );
  }
}
