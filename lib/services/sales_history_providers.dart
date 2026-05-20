// lib/providers/sales_history_providers.dart
//
// Riverpod 3 — MANUAL (non-code-gen) provider architecture.
// No riverpod_annotation / @riverpod dependency required.
//
// ══════════════════════════════════════════════════════════════════════════════
// ARCHITECTURE CORRECTION NOTES
// ══════════════════════════════════════════════════════════════════════════════
//
// ORIGINAL ERRORS — all caused by a single wrong assumption:
//
//   • FamilyNotifier<S, Arg>   — is NOT a public flutter_riverpod symbol.
//   • NotifierProviderFamily   — is NOT a public flutter_riverpod symbol.
//   • `arg` getter             — does NOT exist outside code-gen.
//
//   Those three identifiers exist only inside Riverpod's internal code-gen
//   machinery (riverpod_generator package). When you import only
//   flutter_riverpod and write notifiers by hand, the compiler cannot resolve
//   them, which cascades into every other error:
//
//     • "Classes can only extend other classes"  → FamilyNotifier not in scope
//     • "Undefined name 'state'"                 → no Notifier base inherited
//     • "Undefined name 'ref'"                   → same
//     • "Undefined name 'arg'"                   → code-gen-only getter
//     • "NotifierProviderFamily isn't defined"   → code-gen-only class
//     • override_on_non_overriding_member        → build(arg) wrong signature
//
// CORRECT MANUAL-PATH PATTERN for a parameterised notifier:
//
//   1. Extend  Notifier<S>  (the standard, always-exported base).
//   2. Store the family arg as a constructor field on the notifier class.
//   3. Declare the provider with:
//
//        NotifierProvider.family<MyNotifier, S, Arg>(
//          (arg) => MyNotifier(arg),
//        );
//
//      flutter_riverpod exports this `.family` constructor and injects `ref`
//      and `state` through the Notifier base — exactly as with non-family
//      notifiers, with no special subclass needed.
//
// PAGINATION FIX (kept from previous refactor):
//   lastDoc (Firestore cursor) lives inside SalesHistoryState, not as a
//   notifier instance field. Riverpod calls build() on every invalidation,
//   which resets instance fields. Embedding the cursor in state preserves it.
//
// ── Worker providers ──
//   workerSalesHistoryProvider  — paginated POS history for one worker
//   workerDailyTotalProvider    — derived daily total from the current page
//
// ── Owner providers ──
//   ownerSalesFilterProvider    — mutable filter state (no family)
//   ownerSalesHistoryProvider   — paginated, filtered history (family on storeId)
//
// ══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared constants
// ─────────────────────────────────────────────────────────────────────────────

const _kPageSize = 20;

/// Sentinel object used in copyWith() to distinguish "not supplied" from null.
/// This lets callers explicitly clear a nullable field by passing null,
/// while omitting the parameter preserves the current value.
const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// Owner filter state
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable filter state for the owner sales history view.
/// Every field is optional — null means "no filter applied".
class SalesHistoryFilter {
  /// Filter to a specific worker's POS sales only.
  final String? workerUid;

  /// 'pos' | 'online' | null (all sources)
  final String? orderSource;

  /// Any valid order status string: 'processing' | 'completed' | etc.
  final String? status;

  /// Inclusive lower bound on createdAt.
  final DateTime? fromDate;

  /// Inclusive upper bound on createdAt.
  final DateTime? toDate;

  const SalesHistoryFilter({
    this.workerUid,
    this.orderSource,
    this.status,
    this.fromDate,
    this.toDate,
  });

  SalesHistoryFilter copyWith({
    Object? workerUid = _sentinel,
    Object? orderSource = _sentinel,
    Object? status = _sentinel,
    Object? fromDate = _sentinel,
    Object? toDate = _sentinel,
  }) {
    return SalesHistoryFilter(
      workerUid: workerUid == _sentinel ? this.workerUid : workerUid as String?,
      orderSource: orderSource == _sentinel
          ? this.orderSource
          : orderSource as String?,
      status: status == _sentinel ? this.status : status as String?,
      fromDate: fromDate == _sentinel ? this.fromDate : fromDate as DateTime?,
      toDate: toDate == _sentinel ? this.toDate : toDate as DateTime?,
    );
  }

  bool get hasActiveFilters =>
      workerUid != null ||
      orderSource != null ||
      status != null ||
      fromDate != null ||
      toDate != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner filter provider
//
// Plain Notifier<SalesHistoryFilter> — no family, no arg.
// This is exactly correct: filter state is global to the owner session.
// ─────────────────────────────────────────────────────────────────────────────

class OwnerSalesFilterNotifier extends Notifier<SalesHistoryFilter> {
  // build() is called once on first access and again after invalidation.
  // ref and state are injected by the Notifier base — no boilerplate needed.
  @override
  SalesHistoryFilter build() => const SalesHistoryFilter();

  void setWorker(String? uid) => state = state.copyWith(workerUid: uid);

  void setOrderSource(String? source) =>
      state = state.copyWith(orderSource: source);

  void setStatus(String? s) => state = state.copyWith(status: s);

  void setFromDate(DateTime? date) => state = state.copyWith(fromDate: date);

  void setToDate(DateTime? date) => state = state.copyWith(toDate: date);

  void clearAll() => state = const SalesHistoryFilter();
}

/// Global owner filter provider.
/// Widgets call: ref.watch(ownerSalesFilterProvider)
/// Widgets mutate: ref.read(ownerSalesFilterProvider.notifier).setWorker(uid)
final ownerSalesFilterProvider =
    NotifierProvider<OwnerSalesFilterNotifier, SalesHistoryFilter>(
      OwnerSalesFilterNotifier.new,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Pagination state — shared shape for worker and owner
//
// FIX: lastDoc lives inside SalesHistoryState, not as a notifier instance
// field. Riverpod rebuilds the notifier (calls build()) on every invalidation,
// wiping all instance fields. Storing the cursor in state preserves it across
// build() calls so pagination continues from the correct document.
// ─────────────────────────────────────────────────────────────────────────────

class SalesHistoryState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// Firestore pagination cursor — the last DocumentSnapshot of the most
  /// recently loaded page. Stored in state (not a notifier field) so it
  /// survives build() rebuilds. Passed as `startAfter` to the next query.
  final DocumentSnapshot? lastDoc;

  const SalesHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.lastDoc,
  });

  SalesHistoryState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel, // sentinel lets callers explicitly null-clear
    Object? lastDoc = _sentinel,
  }) {
    return SalesHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      lastDoc: lastDoc == _sentinel
          ? this.lastDoc
          : lastDoc as DocumentSnapshot?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker history params
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable parameter object used as the family key for worker history.
/// Correct == and hashCode ensure Riverpod caches one provider per unique
/// (workerUid, storeId) pair and doesn't create duplicates.
class WorkerHistoryParams {
  final String workerUid;
  final String storeId;

  const WorkerHistoryParams({required this.workerUid, required this.storeId});

  @override
  bool operator ==(Object other) =>
      other is WorkerHistoryParams &&
      other.workerUid == workerUid &&
      other.storeId == storeId;

  @override
  int get hashCode => Object.hash(workerUid, storeId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker sales history — Notifier + family provider
//
// PATTERN: extend Notifier<S>, store the family arg as a constructor field,
// declare the provider with NotifierProvider.family((arg) => MyNotifier(arg)).
//
// WHY this works:
//   • Notifier<S> is always exported by flutter_riverpod.
//   • Its base class injects `ref` and `state` automatically.
//   • build() takes NO parameters (unlike the code-gen FamilyNotifier).
//   • The arg is captured in the constructor — no magic `arg` getter needed.
//   • NotifierProvider.family is the correct public factory for this pattern.
// ─────────────────────────────────────────────────────────────────────────────

class WorkerSalesHistoryNotifier extends Notifier<SalesHistoryState> {
  // ── Constructor stores the family parameter ────────────────────────────────
  WorkerSalesHistoryNotifier(this._params);
  final WorkerHistoryParams _params;

  final _service = OrderService();

  // ── build() — no parameters, called by Riverpod on creation/invalidation ──
  @override
  SalesHistoryState build() {
    // Schedule the initial fetch after build() returns synchronously.
    // Using Future.microtask keeps build() synchronous (required by Notifier).
    Future.microtask(_loadFirstPage);
    return const SalesHistoryState(isLoading: true);
  }

  // ── First page (also used by refresh) ─────────────────────────────────────
  Future<void> _loadFirstPage() async {
    // Reset cursor explicitly via sentinel null — clears lastDoc in state.
    state = state.copyWith(isLoading: true, error: null, lastDoc: null);
    try {
      final snap = await _service.getWorkerSalesHistoryRaw(
        workerUid: _params.workerUid,
        storeId: _params.storeId,
        limit: _kPageSize,
      );
      final orders = snap.docs
          .map(
            (d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();

      state = SalesHistoryState(
        orders: orders,
        isLoading: false,
        hasMore: snap.docs.length == _kPageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      state = SalesHistoryState(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  /// Appends the next page of results. No-op when already loading or exhausted.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final snap = await _service.getWorkerSalesHistoryRaw(
        workerUid: _params.workerUid,
        storeId: _params.storeId,
        limit: _kPageSize,
        startAfter: state.lastDoc, // cursor from state, survives rebuilds
      );
      final newOrders = snap.docs
          .map(
            (d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();

      state = state.copyWith(
        orders: [...state.orders, ...newOrders],
        isLoadingMore: false,
        hasMore: snap.docs.length == _kPageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : state.lastDoc,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  /// Resets pagination cursor and reloads from the first page.
  Future<void> refresh() => _loadFirstPage();
}

// ── Provider declaration ───────────────────────────────────────────────────
//
// NotifierProvider.family is the correct public API.
// The factory lambda receives the arg and passes it to the notifier constructor.
// Riverpod then calls build() with no parameters and injects ref + state.
//
// Usage in widgets:
//   final params = WorkerHistoryParams(workerUid: uid, storeId: sid);
//   final historyState = ref.watch(workerSalesHistoryProvider(params));
//   ref.read(workerSalesHistoryProvider(params).notifier).loadMore();

final workerSalesHistoryProvider =
    NotifierProvider.family<
      WorkerSalesHistoryNotifier,
      SalesHistoryState,
      WorkerHistoryParams
    >((arg) => WorkerSalesHistoryNotifier(arg));

// ─────────────────────────────────────────────────────────────────────────────
// Worker daily total — pure computed provider
//
// Derived from the current page of workerSalesHistoryProvider.
// No Firestore call — purely a fold over the in-memory orders list.
// Only counts orders whose createdAt falls on today (local device date).
// ─────────────────────────────────────────────────────────────────────────────

/// Public return type (was private _DailyTotals — renamed for external access).
class DailyTotals {
  final double total;
  final int count;
  const DailyTotals({required this.total, required this.count});
}

final workerDailyTotalProvider =
    Provider.family<DailyTotals, WorkerHistoryParams>((ref, params) {
      final historyState = ref.watch(workerSalesHistoryProvider(params));
      final now = DateTime.now();

      final todayOrders = historyState.orders.where((o) {
        final d = o.createdAt;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final total = todayOrders.fold(0.0, (acc, o) => acc + o.totalPrice);
      return DailyTotals(total: total, count: todayOrders.length);
    });

// ─────────────────────────────────────────────────────────────────────────────
// Owner sales history — Notifier + family provider
//
// Family key: storeId (String) — one provider instance per store.
//
// Filter integration:
//   build() calls ref.watch(ownerSalesFilterProvider).
//   When any filter changes, Riverpod automatically re-runs build(), which
//   resets pagination and re-fetches from page 1 with the new filters.
//   This is correct Riverpod 3 reactive behaviour — no manual subscription.
// ─────────────────────────────────────────────────────────────────────────────

class OwnerSalesHistoryNotifier extends Notifier<SalesHistoryState> {
  // ── Constructor stores the family parameter ────────────────────────────────
  OwnerSalesHistoryNotifier(this._storeId);
  final String _storeId;

  final _service = OrderService();

  // ── build() ────────────────────────────────────────────────────────────────
  @override
  SalesHistoryState build() {
    // ref.watch() inside build() is fully supported in Riverpod 3 Notifiers.
    // Watching the filter provider here means: whenever any filter changes,
    // Riverpod invalidates this notifier and calls build() again, which
    // resets state to isLoading:true and kicks off a fresh first-page fetch.
    ref.watch(ownerSalesFilterProvider);

    Future.microtask(_loadFirstPage);
    return const SalesHistoryState(isLoading: true);
  }

  // ── First page ─────────────────────────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    // Read current filter snapshot — ref.read (not watch) avoids re-triggering.
    final filter = ref.read(ownerSalesFilterProvider);
    state = state.copyWith(isLoading: true, error: null, lastDoc: null);
    try {
      final snap = await _service.getOwnerSalesHistoryRaw(
        storeId: _storeId,
        orderSource: filter.orderSource,
        workerUid: filter.workerUid,
        status: filter.status,
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        limit: _kPageSize,
      );
      final orders = snap.docs
          .map(
            (d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();

      state = SalesHistoryState(
        orders: orders,
        isLoading: false,
        hasMore: snap.docs.length == _kPageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      state = SalesHistoryState(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    final filter = ref.read(ownerSalesFilterProvider);
    state = state.copyWith(isLoadingMore: true);
    try {
      final snap = await _service.getOwnerSalesHistoryRaw(
        storeId: _storeId,
        orderSource: filter.orderSource,
        workerUid: filter.workerUid,
        status: filter.status,
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        limit: _kPageSize,
        startAfter: state.lastDoc, // cursor from state
      );
      final newOrders = snap.docs
          .map(
            (d) => OrderModel.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();

      state = state.copyWith(
        orders: [...state.orders, ...newOrders],
        isLoadingMore: false,
        hasMore: snap.docs.length == _kPageSize,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : state.lastDoc,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  Future<void> refresh() => _loadFirstPage();
}

// ── Provider declaration ───────────────────────────────────────────────────
//
// Usage in widgets:
//   final historyState = ref.watch(ownerSalesHistoryProvider(storeId));
//   ref.read(ownerSalesHistoryProvider(storeId).notifier).loadMore();
//
// Changing filters via ownerSalesFilterProvider automatically invalidates
// this provider and resets to page 1 — no manual refresh needed.

final ownerSalesHistoryProvider =
    NotifierProvider.family<
      OwnerSalesHistoryNotifier,
      SalesHistoryState,
      String
    >((arg) => OwnerSalesHistoryNotifier(arg));
