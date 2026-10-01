import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../widgets/state_views.dart';

class PagedState<T> {
  const PagedState({required this.items, required this.page, required this.hasMore, this.meta = const {}, this.loadingMore = false});

  final List<T> items;
  final int page;
  final bool hasMore;
  final Map<String, dynamic> meta;
  final bool loadingMore;

  PagedState<T> copyWith({List<T>? items, int? page, bool? hasMore, Map<String, dynamic>? meta, bool? loadingMore}) => PagedState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        meta: meta ?? this.meta,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Infinite-scroll list backed by a Laravel paginated endpoint. Subclasses watch their filter
/// provider inside [fetch] so a filter change rebuilds from page 1.
abstract class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  Future<Paginated<T>> fetch(int page);

  @override
  Future<PagedState<T>> build() async => _toState(await fetch(1));

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await fetch(current.page + 1);
      state = AsyncData(current.copyWith(items: [...current.items, ...next.items], page: next.currentPage, hasMore: next.hasMore, meta: next.meta, loadingMore: false));
    } on Object {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  void replace(bool Function(T item) test, T updated) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(items: [for (final item in current.items) test(item) ? updated : item]));
    }
  }

  void remove(bool Function(T item) test) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(items: current.items.where((item) => !test(item)).toList()));
    }
  }

  PagedState<T> _toState(Paginated<T> result) =>
      PagedState(items: result.items, page: result.currentPage, hasMore: result.hasMore, meta: result.meta);
}

class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.empty,
    this.header,
    this.separated = true,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final AsyncValue<PagedState<T>> value;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final Widget? header;
  final bool separated;
  final EdgeInsets padding;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        widget.onLoadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: widget.value,
      onRetry: widget.onRefresh,
      data: (state) {
        final header = widget.header;
        final headerCount = header == null ? 0 : 1;

        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [?header, SizedBox(height: 320, child: widget.empty)],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: headerCount + state.items.length + (state.loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < headerCount) {
                return header;
              }
              final i = index - headerCount;
              if (i >= state.items.length) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              final tile = widget.itemBuilder(context, state.items[i]);
              return widget.separated && i > 0 ? Column(mainAxisSize: MainAxisSize.min, children: [const Divider(indent: 16, endIndent: 16), tile]) : tile;
            },
          ),
        );
      },
    );
  }
}

/// Holds a list's filter; use a Dart record as [T] so equality comes for free.
class QueryNotifier<T> extends Notifier<T> {
  QueryNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}
