import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout_plan.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── Profile Data ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    final doc = _userDoc;
    if (doc == null) return {};
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 5));
      if (snap.exists && snap.data() != null) {
        return snap.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting profile: $e');
    }
    return {};
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      await doc.set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  // ── Workout Plans ──────────────────────────────────────────────────────────

  Future<List<WorkoutPlan>> getPlans() async {
    final doc = _userDoc;
    if (doc == null) return [];
    final snapshot = await doc.collection('plans').orderBy('updated_at', descending: true).get();
    final plans = <WorkoutPlan>[];
    for (final docSnap in snapshot.docs) {
      try {
        final planData = jsonDecode(docSnap.data()['data_json'] as String) as Map<String, dynamic>;
        plans.add(WorkoutPlan.fromJson(planData));
      } catch (_) {}
    }
    return plans;
  }

  Future<void> savePlan(WorkoutPlan plan) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.collection('plans').doc(plan.id).set({
      'data_json': jsonEncode(plan.toJson()),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePlan(String planId) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.collection('plans').doc(planId).delete();
  }

  // ── Performance Logs ───────────────────────────────────────────────────────

  Future<void> logPerformance(Map<String, dynamic> log) async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.collection('logs').add({
      ...log,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getPerformanceLogs() async {
    final doc = _userDoc;
    if (doc == null) return [];
    final snapshot = await doc.collection('logs').orderBy('date_time', descending: true).get();
    return snapshot.docs.map((e) => e.data()).toList();
  }
}
