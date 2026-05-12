import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/models /user_model.dart';
import '../services/auth_service.dart';

class ManageWorkersScreen extends StatefulWidget {
  const ManageWorkersScreen({super.key});

  @override
  State<ManageWorkersScreen> createState() => _ManageWorkersScreenState();
}

class _ManageWorkersScreenState extends State<ManageWorkersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String? _error;
  List<UserModel> _workers = [];
  String? _ownerUid;
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _workers = [];
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in.');

      _ownerUid = user.uid;

      // Try to load owner's storeId from their user doc (if you store it there)
      final ownerDoc = await _firestore
          .collection('users')
          .doc(_ownerUid)
          .get();
      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data();
        if (ownerData != null && ownerData['storeId'] != null) {
          _storeId = ownerData['storeId'] as String;
        }
      }

      // Attempt 1: If you keep workers as subcollection under stores/{storeId}/workers
      if (_storeId != null) {
        try {
          print(
            'Querying stores/$_storeId/workers subcollection for owner $_ownerUid',
          );
          final snap = await _firestore
              .collection('stores')
              .doc(_storeId)
              .collection('workers')
              .get();

          if (snap.docs.isNotEmpty) {
            _workers = snap.docs.map((d) {
              final data = d.data();
              // If your worker docs are full user objects, adapt accordingly
              return UserModel.fromMap(data);
            }).toList();

            setState(() {
              _isLoading = false;
            });
            return;
          } else {
            print(
              'No docs in stores/$_storeId/workers — falling back to users collection query.',
            );
          }
        } on FirebaseException catch (e) {
          // Permission denied or other Firestore error — surface it
          print('Error querying stores subcollection: $e');
          if (e.code == 'permission-denied') {
            throw Exception(
              'Permission denied reading store workers. Check Firestore rules.',
            );
          } else {
            // rethrow to outer catch
            rethrow;
          }
        }
      } else {
        print(
          'Owner has no storeId in their user doc; skipping stores subcollection query.',
        );
      }

      // Attempt 2: Query top-level users collection where ownerUid == ownerUid and role == 'worker'
      try {
        print('Querying users where ownerUid == $_ownerUid and role == worker');
        final q = _firestore
            .collection('users')
            .where('role', isEqualTo: 'worker')
            .where('ownerUid', isEqualTo: _ownerUid);

        final snap = await q.get();

        if (snap.docs.isEmpty) {
          // No workers found — could be data mismatch or missing fields
          setState(() {
            _isLoading = false;
            _workers = [];
            _error = null; // no error, just empty
          });
          print(
            'No worker documents found in users collection for owner $_ownerUid.',
          );
          return;
        }

        _workers = snap.docs.map((d) {
          final data = d.data();
          return UserModel.fromMap(data);
        }).toList();

        setState(() {
          _isLoading = false;
        });
        return;
      } on FirebaseException catch (e) {
        print('Error querying users collection for workers: $e');
        if (e.code == 'permission-denied') {
          throw Exception(
            'Permission denied reading users collection. Check Firestore rules.',
          );
        } else {
          rethrow;
        }
      }
    } on Exception catch (e) {
      print('ManageWorkersScreen error: $e');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _initAndLoad();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'No workers found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Either no workers have been added yet, or the worker documents are missing the expected fields (role, ownerUid, storeId).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _refresh, child: const Text('Refresh')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _workers.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final w = _workers[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(w.name.isNotEmpty ? w.name[0].toUpperCase() : '?'),
            ),
            title: Text(w.name),
            subtitle: Text(w.email),
            trailing: Text(w.isActive ? 'Active' : 'Inactive'),
            onTap: () {
              // navigate to worker detail or edit screen
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Tapped ${w.name}')));
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Workers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add worker screen if you have one
          Navigator.pushNamed(context, '/add-worker');
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
