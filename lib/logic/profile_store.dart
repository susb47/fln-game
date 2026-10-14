import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// All children who play on this device, and who is playing now.
///
/// "Sign in" here means picking your own picture: no passwords for 6 to 9
/// year olds, no internet, nothing leaves the phone. Guests play without saving.
class ProfileStore extends ChangeNotifier {
  static const _key = 'profiles_v2';

  final SharedPreferences? _prefs;
  final List<Profile> profiles;
  Profile? current;

  ProfileStore._(this._prefs, this.profiles);

  /// In-memory store for tests.
  factory ProfileStore.memory([List<Profile>? profiles]) => ProfileStore._(null, profiles ?? []);

  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = <Profile>[];
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          profiles.add(Profile.fromJson(j as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Could not read saved profiles: $e');
      }
    }
    return ProfileStore._(prefs, profiles);
  }

  Profile create(String name, String avatar, {String? trainer}) {
    final p = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      avatar: avatar,
      trainer: trainer,
      createdAt: DateTime.now(),
    );
    profiles.add(p);
    current = p;
    save();
    return p;
  }

  void signIn(Profile p) {
    current = p;
    notifyListeners();
  }

  void playAsGuest() {
    current = Profile.guest();
    notifyListeners();
  }

  /// Keeps the guest's progress by turning it into a saved profile.
  Profile saveGuest(String name, String avatar, {String? trainer}) {
    final guest = current!;
    final p = guest.savedAs(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      avatar: avatar,
    )..trainer = trainer ?? guest.trainer;
    profiles.add(p);
    current = p;
    save();
    return p;
  }

  /// Changes the current player's trainer.
  void setTrainer(String id) {
    final p = current;
    if (p == null) return;
    p.trainer = id;
    if (p.isGuest) {
      notifyListeners();
    } else {
      save();
    }
  }

  void signOut() {
    current = null;
    notifyListeners();
  }

  void delete(Profile p) {
    profiles.remove(p);
    if (current == p) current = null;
    save();
  }

  /// Writes saved profiles to the device. Guests are never written.
  void save() {
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }
}
