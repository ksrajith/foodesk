import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Why login cannot continue after Firebase Auth succeeded.
enum LoginBlockReason {
  deactivated,
  registrationPending,
  registrationRejected,
}

/// Outcome of loading / creating the Firestore user profile after sign-in.
class LoginProfileResult {
  const LoginProfileResult._({
    this.profile,
    this.blockReason,
    this.rejectedAdminComment,
    this.approvedRole,
    this.approvedAdminComment,
  });

  /// Login can continue; navigate using [profile].
  const LoginProfileResult.success(Map<String, dynamic> profile)
      : this._(profile: profile);

  /// Login must stop; show UI based on [blockReason].
  const LoginProfileResult.blocked(
    LoginBlockReason reason, {
    String? rejectedAdminComment,
  }) : this._(blockReason: reason, rejectedAdminComment: rejectedAdminComment);

  /// Admin approved registration; [profile] was created — show approval dialog first.
  const LoginProfileResult.approvedRegistration({
    required Map<String, dynamic> profile,
    required String approvedRole,
    String? approvedAdminComment,
  }) : this._(
          profile: profile,
          approvedRole: approvedRole,
          approvedAdminComment: approvedAdminComment,
        );

  final Map<String, dynamic>? profile;
  final LoginBlockReason? blockReason;
  final String? rejectedAdminComment;
  final String? approvedRole;
  final String? approvedAdminComment;

  bool get canContinue => profile != null && blockReason == null;
  bool get showApprovedDialog => approvedRole != null;
}

/// Loads `users/{uid}` and `registration_requests/{uid}` after Firebase Auth sign-in.
class LoginProfileService {
  LoginProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Resolves profile for [uid]. Creates `users` doc when needed (approved / legacy accounts).
  Future<LoginProfileResult> resolveAfterSignIn({
    required String uid,
    required String email,
    required String? displayName,
  }) async {
    final usersRef = _firestore.collection('users').doc(uid);
    final userDoc = await usersRef.get();
    final requestDoc = await _firestore.collection('registration_requests').doc(uid).get();

    if (userDoc.exists) {
      final profile = userDoc.data()!;
      final status = (profile['accountStatus'] as String?)?.toLowerCase();
      if (status == 'deactivated') {
        await _auth.signOut();
        return const LoginProfileResult.blocked(LoginBlockReason.deactivated);
      }
      return LoginProfileResult.success(profile);
    }

    return _resolveWithoutUserDoc(
      uid: uid,
      email: email,
      displayName: displayName,
      requestDoc: requestDoc,
      usersRef: usersRef,
    );
  }

  Future<LoginProfileResult> _resolveWithoutUserDoc({
    required String uid,
    required String email,
    required String? displayName,
    required DocumentSnapshot<Map<String, dynamic>> requestDoc,
    required DocumentReference<Map<String, dynamic>> usersRef,
  }) async {
    if (!requestDoc.exists) {
      final profile = _defaultProfile(uid: uid, email: email, displayName: displayName);
      await usersRef.set(profile);
      return LoginProfileResult.success(profile);
    }

    final req = requestDoc.data()!;
    final status = req['status'] as String? ?? 'pending';

    switch (status) {
      case 'pending':
        return const LoginProfileResult.blocked(LoginBlockReason.registrationPending);
      case 'rejected':
        return LoginProfileResult.blocked(
          LoginBlockReason.registrationRejected,
          rejectedAdminComment: req['adminComment'] as String?,
        );
      case 'approved':
        final approvedRole = req['approvedRole'] as String? ?? 'Customer';
        final profile = {
          'id': uid,
          'name': req['name'] ?? displayName ?? _nameFromEmail(email),
          'email': req['email'] ?? email,
          'role': approvedRole,
          'accountStatus': 'Active',
          'approvedAt': FieldValue.serverTimestamp(),
        };
        await usersRef.set(profile);
        return LoginProfileResult.approvedRegistration(
          profile: profile,
          approvedRole: approvedRole,
          approvedAdminComment: req['adminComment'] as String?,
        );
      default:
        final profile = _defaultProfile(uid: uid, email: email, displayName: displayName);
        await usersRef.set(profile);
        return LoginProfileResult.success(profile);
    }
  }

  Map<String, dynamic> _defaultProfile({
    required String uid,
    required String email,
    required String? displayName,
  }) {
    return {
      'id': uid,
      'name': displayName ?? _nameFromEmail(email),
      'email': email,
      'role': 'Customer',
      'accountStatus': 'Active',
    };
  }

  static String _nameFromEmail(String email) => email.split('@').first;
}
