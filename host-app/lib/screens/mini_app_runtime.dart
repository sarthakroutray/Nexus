import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'secure_session_manager.dart';

/// MiniAppRuntimeScreen wraps an InAppWebView and provides a JavaScript
/// bridge so that Mini-Apps can request native operations (e.g. payment).
class MiniAppRuntimeScreen extends StatefulWidget {
  final String title;
  final String url;

  const MiniAppRuntimeScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<MiniAppRuntimeScreen> createState() => _MiniAppRuntimeScreenState();
}

class _MiniAppRuntimeScreenState extends State<MiniAppRuntimeScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isPageLoaded = false;

  /// Handles payments by presenting confirmation modals, authenticating user via mock biometrics,
  /// and firing the transaction request to the Spring Boot wallet balance endpoints.
  Future<Map<String, dynamic>> _handlePaymentRequest(dynamic request) async {
    debugPrint('JSBridge: received requestPayment => $request');

    // Ensure the widget is still mounted in the tree
    if (!mounted) {
      return <String, dynamic>{
        'success': false,
        'message': 'WebView container is no longer active.',
      };
    }

    // 1. Parse payload from the JS bridge
    late Map<String, dynamic> payload;
    try {
      payload = json.decode(request is String ? request : json.encode(request));
    } catch (_) {
      payload = <String, dynamic>{};
    }

    final amount = (payload['amount'] as num? ?? 0.0).toDouble();
    final currency = payload['currency'] as String? ?? 'USD';
    final miniAppId = payload['miniAppId'] as String? ?? 'unknown';
    final description = payload['description'] as String? ?? payload['item'] as String? ?? 'Payment Request';

    // 2. Trigger native confirmation sheet
    final bool? confirmed = await _showPaymentConfirmationSheet(
      context: context,
      item: description,
      amount: amount,
      currency: currency,
    );

    if (confirmed != true) {
      debugPrint('JSBridge: transaction cancelled by the user.');
      return <String, dynamic>{
        'success': false,
        'message': 'User canceled authorization',
      };
    }

    // 3. Perform hardware biometric authentication
    final bool didAuthenticate = await _authenticateWithBiometrics();

    if (!didAuthenticate) {
      debugPrint('JSBridge: biometric authentication failed');
      return <String, dynamic>{
        'success': false,
        'message': 'Biometric authentication cancelled or failed.',
      };
    }

    // 4. Call the backend ledger to deduct funds
    try {
      const String backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: 'http://localhost:8080');
      final String token = SecureSessionManager.token ?? '';
      final String username = SecureSessionManager.username ?? 'user-001';
      
      final response = await http.post(
        Uri.parse('$backendHost/api/v1/wallet/$username/deduct'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: json.encode(<String, dynamic>{
          'amount': amount,
          'currency': currency,
          'miniAppId': miniAppId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('JSBridge: backend response => $body');

        final bool success = body['success'] == true;

        // Propagate transaction result back to the web view
        return <String, dynamic>{
          'success': success,
          'txnId': body['txnId'] ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
          'miniAppId': miniAppId,
          'amount': amount,
          'currency': currency,
          'message': body['message'] ?? (success ? 'Transaction success' : 'Deduction rejected'),
          'remainingBalance': body['remainingBalance'],
        };
      } else {
        final errorMsg = 'Backend returned error status (${response.statusCode})';
        debugPrint('JSBridge: $errorMsg');
        return <String, dynamic>{
          'success': false,
          'message': errorMsg,
        };
      }
    } on TimeoutException catch (te) {
      const errorMsg = 'Transaction timed out. The ledger server is taking too long to respond.';
      debugPrint('JSBridge: $errorMsg => $te');
      return <String, dynamic>{
        'success': false,
        'message': errorMsg,
      };
    } catch (e) {
      const errorMsg = 'Network connection failed. Make sure the backend server is running.';
      debugPrint('JSBridge: $errorMsg => $e');
      return <String, dynamic>{
        'success': false,
        'message': errorMsg,
      };
    }
  }

  /// Displays a Material 3 sheet details cards, gradient action buttons, and slide confirmation
  Future<bool?> _showPaymentConfirmationSheet({
    required BuildContext context,
    required String item,
    required double amount,
    required String currency,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E293B), // Slate 800
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Handle Indicator bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF10B981), // Emerald Accent
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Authorize Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8), // Slate 400
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Premium display container for the transaction amount
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), // Slate 900
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency == 'USD' ? '\$' : '$currency ',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        amount.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Button Row for confirmation/cancellation
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Emerald Accent
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        child: const Text(
                          'Confirm Pay',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _authenticateWithBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        debugPrint('Biometrics not supported or device passcode/fingerprint not configured. Falling back to automatic authorization.');
        return true; // Graceful fallback for environments/emulators without biometrics configured
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to authorize payment request',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Fallback to PIN/passcode/pattern
        ),
      );
      return didAuthenticate;
    } catch (e) {
      debugPrint('Biometric authentication error: $e. Falling back to automatic authorization.');
      return true; // Graceful fallback under development/PoC mode
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: _progress < 1.0
              ? LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2.0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)), // Emerald Accent
                )
              : Divider(color: const Color(0xFF334155).withValues(alpha: 0.4), height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          // 1. The micro-frontend WebView
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              transparentBackground: true,
              allowFileAccess: false,
              allowContentAccess: false,
              safeBrowsingEnabled: true,
              javaScriptCanOpenWindowsAutomatically: false,
              supportMultipleWindows: false,
            ),
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri != null) {
                final allowedUri = WebUri(widget.url);
                // Enforce strict sandbox: only navigate within the authorized origin
                if (uri.host == allowedUri.host &&
                    uri.port == allowedUri.port &&
                    uri.scheme == allowedUri.scheme) {
                  return NavigationActionPolicy.ALLOW;
                }
              }
              debugPrint('Security Sandbox: blocked navigation to non-app origin ${uri?.toString()}');
              return NavigationActionPolicy.CANCEL;
            },
            onWebViewCreated: (InAppWebViewController controller) {
              _webViewController = controller;

              // Register the JSBridge handler for 'requestPayment'
              _webViewController?.addJavaScriptHandler(
                handlerName: 'requestPayment',
                callback: (args) async {
                  // Origin verification check for security (CSP / sandboxing)
                  final currentUri = await _webViewController?.getUrl();
                  final allowedUri = WebUri(widget.url);
                  if (currentUri == null ||
                      currentUri.host != allowedUri.host ||
                      currentUri.port != allowedUri.port ||
                      currentUri.scheme != allowedUri.scheme) {
                    debugPrint('Security Violation: Unauthorized origin ${currentUri?.toString()} tried to invoke requestPayment.');
                    return {
                      'success': false,
                      'message': 'Security error: Unauthorized origin.',
                    };
                  }

                  final requestPayload = args.isNotEmpty ? args.first : null;
                  if (requestPayload == null) return null;

                  final result = await _handlePaymentRequest(requestPayload);
                  return result;
                },
              );

              // Register the JSBridge handler for 'getAuthSession'
              _webViewController?.addJavaScriptHandler(
                handlerName: 'getAuthSession',
                callback: (args) async {
                  debugPrint('JSBridge: received getAuthSession request');
                  
                  // Origin verification check for security (CSP / sandboxing)
                  final currentUri = await _webViewController?.getUrl();
                  final allowedUri = WebUri(widget.url);
                  if (currentUri == null ||
                      currentUri.host != allowedUri.host ||
                      currentUri.port != allowedUri.port ||
                      currentUri.scheme != allowedUri.scheme) {
                    debugPrint('Security Violation: Unauthorized origin ${currentUri?.toString()} tried to retrieve session credentials.');
                    return {
                      'success': false,
                      'error': 'Unauthorized Session Origin',
                    };
                  }

                  final token = SecureSessionManager.token;
                  final username = SecureSessionManager.username;

                  if (token == null || username == null) {
                    debugPrint('JSBridge: getAuthSession failed - Session is unauthorized/missing');
                    return {
                      'success': false,
                      'error': 'Unauthorized Session',
                    };
                  }

                  return {
                    'success': true,
                    'token': token,
                    'username': username,
                  };
                },
              );

              // Register the JSBridge handler for 'pickContact'
              _webViewController?.addJavaScriptHandler(
                handlerName: 'pickContact',
                callback: (args) async {
                  debugPrint('JSBridge: received pickContact request');
                  
                  // Origin verification check for security (CSP / sandboxing)
                  final currentUri = await _webViewController?.getUrl();
                  final allowedUri = WebUri(widget.url);
                  if (currentUri == null ||
                      currentUri.host != allowedUri.host ||
                      currentUri.port != allowedUri.port ||
                      currentUri.scheme != allowedUri.scheme) {
                    debugPrint('Security Violation: Unauthorized origin ${currentUri?.toString()} tried to invoke pickContact.');
                    return {
                      'success': false,
                      'error': 'Unauthorized Session Origin',
                    };
                  }

                  try {
                    if (!await FlutterContacts.requestPermission(readonly: true)) {
                      return {
                        'success': false,
                        'error': 'Contacts permission denied',
                      };
                    }

                    final Contact? contact = await FlutterContacts.openExternalPick();
                    if (contact != null) {
                      final fullContact = await FlutterContacts.getContact(contact.id);
                      final actualContact = fullContact ?? contact;
                      
                      final String name = actualContact.displayName;
                      final String phone = actualContact.phones.isNotEmpty 
                          ? actualContact.phones.first.number 
                          : '';

                      return {
                        'success': true,
                        'name': name,
                        'phone': phone,
                      };
                    } else {
                      return {
                        'success': false,
                        'error': 'User cancelled contact selection',
                      };
                    }
                  } catch (e) {
                    debugPrint('JSBridge pickContact error: $e');
                    return {
                      'success': false,
                      'error': e.toString(),
                    };
                  }
                },
              );

              debugPrint('JSBridge: requestPayment, getAuthSession and pickContact handlers registered with origin verification.');
            },
            onProgressChanged: (InAppWebViewController controller, int progress) {
              setState(() {
                _progress = progress / 100;
                if (progress >= 100) {
                  _isPageLoaded = true;
                }
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('MiniApp Console [${consoleMessage.message}]');
            },
          ),
          
          // 2. Sleek Dark loading screen masking page paint lag
          AnimatedOpacity(
            opacity: _isPageLoaded ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: _isPageLoaded,
              child: Container(
                color: const Color(0xFF0F172A),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'ESTABLISHING BRIDGE',
                      style: TextStyle(
                        color: Color(0xFF475569), // Slate 600
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
