import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      fetchCurrentUserModel();
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        await fetchCurrentUserModel();
      } else {
        _currentUserModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> fetchCurrentUserModel() async {
    if (_user == null) {
      _currentUserModel = null;
      notifyListeners();
      return;
    }
    try {
      final doc = await _firestoreService.getUser(_user!.uid);
      if (doc.exists && doc.data() != null) {
        _currentUserModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        // Fallback placeholder model
        _currentUserModel = UserModel(
          id: _user!.uid,
          name: _user!.displayName ?? 'Student',
          email: _user!.email ?? '',
          createdAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user model: $e');
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String course = '',
    String semester = '',
    String department = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );

      _user = credential.user;

      if (_user != null) {
        // Create user document in Firestore
        await _firestoreService.saveUser(
          uid: _user!.uid,
          name: name,
          email: email,
          course: course,
          semester: semester,
          department: department,
        );

        // Send email verification
        await _user!.sendEmailVerification();
      }

      await fetchCurrentUserModel();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.login(
        email: email,
        password: password,
      );

      _user = credential.user;
      await fetchCurrentUserModel();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _currentUserModel = null;
    notifyListeners();
  }

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.sendPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendVerificationEmail() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUserAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final uid = _user?.uid;
      await _authService.deleteAccount();
      if (uid != null) {
        await FirebaseFirestore.instance.collection("users").doc(uid).delete();
      }
      _user = null;
      _currentUserModel = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String course,
    required String semester,
    required String department,
    String? profileImage,
  }) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = {
        'name': name,
        'course': course,
        'semester': semester,
        'department': department,
      };
      if (profileImage != null) {
        data['profileImage'] = profileImage;
      }
      await _firestoreService.updateUser(_user!.uid, data);
      await fetchCurrentUserModel();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update specific setting map in user document
  Future<void> updateSettings(Map<String, dynamic> settingsData) async {
    if (_user == null) return;
    try {
      await _firestoreService.updateUser(_user!.uid, {'settings': settingsData});
      await fetchCurrentUserModel();
    } catch (e) {
      debugPrint('Error updating settings in Firestore: $e');
    }
  }

  // Update Pomodoro preferences in user document
  Future<void> updatePomodoroPreferences(Map<String, dynamic> pomodoroPrefs) async {
    if (_user == null) return;
    try {
      await _firestoreService.updateUser(_user!.uid, {'pomodoroPreferences': pomodoroPrefs});
      await fetchCurrentUserModel();
    } catch (e) {
      debugPrint('Error updating pomodoro preferences: $e');
    }
  }
}