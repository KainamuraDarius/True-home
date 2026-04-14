import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/auth/reset_password_from_link_screen.dart';

class AuthActionLinkService {
  AuthActionLinkService({
    required GlobalKey<NavigatorState> navigatorKey,
  }) : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSub;
  String? _lastHandledToken;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingUri(initialUri);
      }
    } catch (_) {
      // Ignore startup link parsing errors.
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingUri(uri);
      },
      onError: (Object error, StackTrace stackTrace) {
        // During hot restart, plugin channels can be briefly unavailable.
        if (error is MissingPluginException) {
          return;
        }
      },
    );
  }

  Future<void> dispose() async {
    await _linkSub?.cancel();
  }

  Uri? _extractActionUri(Uri incoming) {
    // Direct app/universal link case.
    final isDirectAction =
        incoming.host == 'truehome.com.ug' && incoming.path.startsWith('/action');
    if (isDirectAction) return incoming;

    // Some providers wrap target URL in query params.
    final nestedCandidates = [
      incoming.queryParameters['link'],
      incoming.queryParameters['continueUrl'],
      incoming.queryParameters['url'],
    ];

    for (final raw in nestedCandidates) {
      if (raw == null || raw.isEmpty) continue;
      final nested = Uri.tryParse(raw);
      if (nested != null &&
          nested.host == 'truehome.com.ug' &&
          nested.path.startsWith('/action')) {
        return nested;
      }
    }

    // Fallback: allow handling if mode/oobCode is already present.
    if (incoming.queryParameters.containsKey('mode') &&
        incoming.queryParameters.containsKey('oobCode')) {
      return incoming;
    }

    return null;
  }

  Future<void> _handleIncomingUri(Uri incoming) async {
    final actionUri = _extractActionUri(incoming);
    if (actionUri == null) return;

    final mode = actionUri.queryParameters['mode'];
    final oobCode = actionUri.queryParameters['oobCode'];
    if (mode == null || oobCode == null || oobCode.isEmpty) return;

    final token = '$mode:$oobCode';
    if (_lastHandledToken == token) return;
    _lastHandledToken = token;

    switch (mode) {
      case 'resetPassword':
        _openResetPasswordScreen(oobCode);
        break;
      case 'verifyEmail':
      case 'recoverEmail':
        await _applyEmailActionCode(oobCode, mode);
        break;
      default:
        _showSnackBar('Received unsupported auth action: $mode');
        break;
    }
  }

  void _openResetPasswordScreen(String oobCode) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordFromLinkScreen(oobCode: oobCode),
      ),
    );
  }

  Future<void> _applyEmailActionCode(String oobCode, String mode) async {
    try {
      await FirebaseAuth.instance.applyActionCode(oobCode);
      await FirebaseAuth.instance.currentUser?.reload();
      if (mode == 'verifyEmail') {
        _showSnackBar('Email verified successfully.');
      } else {
        _showSnackBar('Email recovery completed successfully.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'expired-action-code') {
        _showSnackBar('This email action link has expired.');
      } else if (e.code == 'invalid-action-code') {
        _showSnackBar('This email action link is invalid.');
      } else {
        _showSnackBar('Could not complete email action: ${e.message ?? e.code}');
      }
    } catch (_) {
      _showSnackBar('Could not complete email action. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
