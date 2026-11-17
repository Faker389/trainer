import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'codec.dart';
import 'store.dart';

enum SyncState { idle, syncing, offline, error }

/// Cloud backup in Firestore:
/// `users/{uid}` holds profile, split, custom exercises and a `months` map of bucket versions;
/// `users/{uid}/months/{yyyy-MM}` holds one packed month of sets (see codec.dart).
/// Listening to the single user document means an app start costs one read, and only months whose
/// version changed are downloaded.
class SyncService extends ChangeNotifier {
  SyncService(this.store, this.user, {FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final AppStore store;
  final User user;
  final FirebaseFirestore _db;

  SyncState state = SyncState.idle;
  String? lastError;
  DateTime? lastSynced;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _debounce, _retry;
  bool _busy = false, _disposed = false, _remoteLoaded = false;
  var _remoteMonths = <String, int>{};

  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(user.uid);
  DocumentReference<Map<String, dynamic>> _monthDoc(String m) => _userDoc.collection('months').doc(m);

  void start() {
    store.addListener(_onLocalChange);
    _sub = _userDoc.snapshots().listen(_onRemote, onError: _fail);
  }

  void _onLocalChange() {
    if (!store.hasPendingSync || _disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  void _onRemote(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    _remoteMonths = {
      for (final e in (data['months'] as Map? ?? const {}).entries) e.key as String: (e.value as num).toInt(),
    };
    _remoteLoaded = true;
    final meta = data['meta'];
    if (meta is Map && !store.metaDirty) {
      final u = (meta['u'] as num?)?.toInt() ?? 0;
      if (u > store.metaUpdatedAt) store.applyRemoteMeta(Map<String, dynamic>.from(meta));
    }
    syncNow();
  }

  Future<void> syncNow() async {
    if (_busy || _disposed || !_remoteLoaded) return;
    _busy = true;
    _setState(SyncState.syncing);
    try {
      final dirty = store.dirtyMonths.toSet();
      for (final e in _remoteMonths.entries) {
        if (e.value > store.syncedVersion(e.key) && !dirty.contains(e.key)) await _pull(e.key);
      }
      for (final m in dirty) {
        await _push(m);
      }
      if (store.metaDirty) await _pushMeta();
      lastSynced = DateTime.now();
      lastError = null;
      _retry?.cancel();
      _setState(SyncState.idle);
    } catch (e) {
      _fail(e);
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 30), syncNow);
    } finally {
      _busy = false;
    }
    if (state == SyncState.idle && store.hasPendingSync) _onLocalChange();
  }

  Future<void> _pull(String m) async {
    final snap = await _monthDoc(m).get();
    final data = snap.data();
    final version = _remoteMonths[m] ?? 0;
    if (data == null) {
      store.applyMerged(m, const [], const {}, version);
      return;
    }
    final (sets, tomb) = decodeMonth(m, data);
    store.applyMerged(m, sets, tomb, (data['u'] as num?)?.toInt() ?? version);
  }

  Future<void> _push(String m) async {
    final seq = store.editSeq(m);
    final local = store.monthSets(m);
    final localTomb = store.monthTombstones(m);
    final result = await _db.runTransaction((tx) async {
      final ref = _monthDoc(m);
      final snap = await tx.get(ref);
      var sets = local, tomb = localTomb;
      var version = DateTime.now().millisecondsSinceEpoch;
      final data = snap.data();
      if (data != null) {
        final (rs, rt) = decodeMonth(m, data);
        (sets, tomb) = mergeMonth(local, localTomb, rs, rt);
        version = math.max(version, ((data['u'] as num?)?.toInt() ?? 0) + 1);
      }
      final encoded = encodeMonth(sets, tomb);
      if (encoded['d']!.isEmpty && encoded['x']!.isEmpty) {
        tx.delete(ref);
      } else {
        tx.set(ref, {...encoded, 'u': version});
      }
      tx.set(_userDoc, {
        'months': {m: version},
      }, SetOptions(merge: true));
      return (sets, tomb, version);
    });
    _remoteMonths[m] = result.$3;
    store.applyMerged(m, result.$1, result.$2, result.$3, pushedSeq: seq);
  }

  Future<void> _pushMeta() async {
    final version = store.metaUpdatedAt;
    await _userDoc.set({
      'meta': store.metaJson,
      'profile': {'email': user.email, 'name': user.displayName},
    }, SetOptions(merge: true));
    store.markMetaSynced(version);
  }

  /// Removes every cloud document of this account (used before deleting the account).
  Future<void> deleteCloudData() async {
    final batch = _db.batch();
    for (final m in {..._remoteMonths.keys, ...store.months}) {
      batch.delete(_monthDoc(m));
    }
    batch.delete(_userDoc);
    await batch.commit();
  }

  void _fail(Object e) {
    lastError = e is FirebaseException ? (e.message ?? e.code) : '$e';
    final offline = e is FirebaseException && (e.code == 'unavailable' || e.code == 'deadline-exceeded');
    _setState(offline ? SyncState.offline : SyncState.error);
  }

  void _setState(SyncState s) {
    if (_disposed) return;
    state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_onLocalChange);
    _sub?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    super.dispose();
  }
}

class SyncScope extends InheritedNotifier<SyncService> {
  const SyncScope({super.key, required SyncService? sync, required super.child}) : super(notifier: sync);

  static SyncService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
