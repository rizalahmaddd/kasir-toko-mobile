import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base class for family async notifiers implementing Stale-While-Revalidate (SWR):
/// 1. Immediately returns cached data if available (instant 0 ms render, no skeleton/spinner).
/// 2. Silently fetches fresh data from the server in the background.
/// 3. Updates state smoothly with fresh data when the server responds.
/// 4. If offline or network error occurs, preserves the cached data without error dialogs.
/// 5. If no cache exists, waits for remote fetch (showing normal loading state).
abstract class CachedFamilyNotifier<T, Arg> extends AsyncNotifier<T> {
  CachedFamilyNotifier(this.arg);

  final Arg arg;

  /// Load cached data from local offline storage or memory.
  Future<T?> loadCache(Arg arg);

  /// Fetch latest data from the remote server.
  Future<T> fetchRemote(Arg arg);

  @override
  Future<T> build() async {
    final cached = await loadCache(arg);
    if (cached != null) {
      unawaited(_silentFetch(arg));
      return cached;
    }
    return fetchRemote(arg);
  }

  Future<void> _silentFetch(Arg arg) async {
    try {
      final fresh = await fetchRemote(arg);
      if (ref.mounted && state.hasValue) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Silent error: preserve cached data when offline or network fails
    }
  }

  /// Explicit refresh (e.g. pull-to-refresh) that awaits the remote fetch.
  Future<T> refresh() async {
    state = const AsyncLoading();
    final fresh = await fetchRemote(arg);
    state = AsyncData(fresh);
    return fresh;
  }
}

/// Base class for non-family async notifiers implementing Stale-While-Revalidate (SWR).
abstract class CachedNotifier<T> extends AsyncNotifier<T> {
  /// Load cached data from local offline storage or memory.
  Future<T?> loadCache();

  /// Fetch latest data from the remote server.
  Future<T> fetchRemote();

  @override
  Future<T> build() async {
    final cached = await loadCache();
    if (cached != null) {
      unawaited(_silentFetch());
      return cached;
    }
    return fetchRemote();
  }

  Future<void> _silentFetch() async {
    try {
      final fresh = await fetchRemote();
      if (ref.mounted && state.hasValue) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Silent error: preserve cached data when offline or network fails
    }
  }

  /// Explicit refresh (e.g. pull-to-refresh) that awaits the remote fetch.
  Future<T> refresh() async {
    state = const AsyncLoading();
    final fresh = await fetchRemote();
    state = AsyncData(fresh);
    return fresh;
  }
}
