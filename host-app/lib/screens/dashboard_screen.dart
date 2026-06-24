import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'mini_app_runtime.dart';
import 'secure_session_manager.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'login_screen.dart';

/// DashboardScreen is the core Platform Shell of Nexus Finance.
/// Overhauled with a minimalist Slate dark-mode design system, custom pulsing loading skeletons,
/// and tactile control cards.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String registryHost = String.fromEnvironment('REGISTRY_HOST', defaultValue: 'http://localhost:8080');
  static const String backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: 'http://localhost:8080');

  List<dynamic> _miniApps = [];
  String _balance = '---';
  String _currency = 'USD';
  Map<String, dynamic> _balances = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Concurrently fetches balance and registry catalog
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _fetchWalletBalance(),
        _fetchRegistry(),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Quietly refreshes balance without showing full-page loader
  Future<void> _refreshWalletBalanceOnly() async {
    try {
      await _fetchWalletBalance();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Dashboard: Quiet balance refresh failed => $e');
    }
  }

  Future<void> _fetchWalletBalance() async {
    final String userId = SecureSessionManager.username ?? 'user-001';
    final response = await http
        .get(Uri.parse('$backendHost/api/v1/wallet/$userId/balance'))
        .timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      _balance = (data['balance'] ?? 0.00).toString();
      _currency = data['currency'] as String? ?? 'USD';
      _balances = data['balances'] as Map<String, dynamic>? ?? {};
    } else {
      throw Exception('Server returned status ${response.statusCode}');
    }
  }

  Future<void> _fetchRegistry() async {
    final response = await http
        .get(Uri.parse('$registryHost/api/v1/registry/mini-apps'))
        .timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      _miniApps = json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Server returned status ${response.statusCode}');
    }
  }

  void _openMiniApp(Map<String, dynamic> appMeta) async {
    final entryUrl = appMeta['entryUrl'] as String? ?? '';
    final displayName = appMeta['displayName'] as String? ?? 'Mini-App';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MiniAppRuntimeScreen(
          title: displayName,
          url: entryUrl,
        ),
      ),
    );

    await _refreshWalletBalanceOnly();
  }

  void _showAddCashDialog() {
    final TextEditingController amountController = TextEditingController();
    bool isSubmitting = false;
    String selectedCurrency = 'USD';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B), // Slate 800
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
              title: const Text('Add Cash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Currency', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    initialValue: selectedCurrency,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP (£)', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedCurrency = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Enter amount to add into your wallet ledger.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: selectedCurrency == 'USD' ? '\$ ' : selectedCurrency == 'EUR' ? '€ ' : '£ ',
                      prefixStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold), // Emerald Accent
                      filled: true,
                      fillColor: const Color(0xFF0F172A), // Slate 900
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // Emerald Accent
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amountText = amountController.text.trim();
                          final amount = double.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount.')),
                            );
                            return;
                          }

                          final navigator = Navigator.of(dialogContext);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final String userId = SecureSessionManager.username ?? 'user-001';
                            final response = await http.post(
                              Uri.parse('$backendHost/api/v1/wallet/$userId/credit'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'amount': amount,
                                'currency': selectedCurrency,
                              }),
                            ).timeout(const Duration(seconds: 4));

                            if (response.statusCode == 200) {
                              final body = json.decode(response.body) as Map<String, dynamic>;
                              if (body['success'] == true) {
                                if (mounted) {
                                  await _fetchWalletBalance();
                                  setState(() {});
                                }
                                
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Credited $selectedCurrency ${amount.toStringAsFixed(2)} successfully.'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              } else {
                                throw Exception(body['message'] ?? 'Failed to credit wallet');
                              }
                            } else {
                              throw Exception('Server Error: ${response.statusCode}');
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                            );
                          } finally {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Add Cash', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSendCashDialog() {
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    bool isSubmitting = false;
    String selectedCurrency = 'USD';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
              title: const Text('Send Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Currency', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    initialValue: selectedCurrency,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'GBP', child: Text('GBP (£)', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedCurrency = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Recipient User ID', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: recipientController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'e.g. user-002',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.contact_phone_rounded, color: Color(0xFF10B981)),
                        onPressed: () async {
                          try {
                            if (await FlutterContacts.requestPermission(readonly: true)) {
                              final Contact? contact = await FlutterContacts.openExternalPick();
                              if (contact != null) {
                                final full = await FlutterContacts.getContact(contact.id);
                                final cleanUsername = (full ?? contact).displayName
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9]'), '');
                                recipientController.text = cleanUsername;
                              }
                            }
                          } catch (e) {
                            debugPrint('Contacts error: $e');
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Amount to send', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: selectedCurrency == 'USD' ? '\$ ' : selectedCurrency == 'EUR' ? '€ ' : '£ ',
                      prefixStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final recipient = recipientController.text.trim();
                          final amountText = amountController.text.trim();
                          final amount = double.tryParse(amountText);
                          
                          if (recipient.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a recipient ID.')),
                            );
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount.')),
                            );
                            return;
                          }

                          final navigator = Navigator.of(dialogContext);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            final String userId = SecureSessionManager.username ?? 'user-001';
                            final response = await http.post(
                              Uri.parse('$backendHost/api/v1/wallet/$userId/transfer'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'amount': amount,
                                'recipientId': recipient,
                                'currency': selectedCurrency,
                              }),
                            ).timeout(const Duration(seconds: 4));

                            if (response.statusCode == 200) {
                              final body = json.decode(response.body) as Map<String, dynamic>;
                              if (body['success'] == true) {
                                if (mounted) {
                                  await _fetchWalletBalance();
                                  setState(() {});
                                }
                                
                                navigator.pop();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Sent $selectedCurrency ${amount.toStringAsFixed(2)} to $recipient successfully.'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              } else {
                                throw Exception(body['message'] ?? 'Failed to transfer cash');
                              }
                            } else {
                              throw Exception('Server Error: ${response.statusCode}');
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent),
                            );
                          } finally {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Money', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showActivityDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity logs are safely synced with the Spring Boot server.'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Slate 900 canvas
      appBar: AppBar(
        title: const Text(
          'NEXUS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            tooltip: 'Log Out',
            onPressed: () async {
              final navigator = Navigator.of(context);
              await SecureSessionManager.clearSession();
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(color: const Color(0xFF334155).withValues(alpha: 0.4), height: 1.0),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF10B981), // Emerald Accent
        backgroundColor: const Color(0xFF1E293B),
        child: _error != null && _miniApps.isEmpty
            ? _buildErrorScreen()
            : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                const Text(
                  'Connection Failed',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unable to connect to the backend server.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _loadDashboardData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      children: [
        // 1. Premium Wallet Balance Header Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate 800
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6), width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL BALANCE (${(SecureSessionManager.username ?? "user-001").toUpperCase()})',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981), // Active status indicator
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LEDGER OK',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: _PulsingSkeleton(width: 140, height: 36, borderRadius: 6),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _currency == 'USD' ? '\$' : '$_currency ',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                _balance,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          if (_balances.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: _balances.entries
                                  .where((entry) => entry.key != 'USD')
                                  .map((entry) {
                                    final String cur = entry.key;
                                    final double val = (entry.value is num) ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString()) ?? 0.0;
                                    String symbol = cur;
                                    if (cur == 'EUR') symbol = '€';
                                    if (cur == 'GBP') symbol = '£';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$symbol ',
                                            style: const TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            val.toStringAsFixed(2),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ],
                      ),
                const SizedBox(height: 24),
                Divider(color: const Color(0xFF334155).withValues(alpha: 0.6), height: 1.0),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BalanceActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Cash',
                      onTap: _showAddCashDialog,
                    ),
                    _BalanceActionButton(
                      icon: Icons.arrow_outward_rounded,
                      label: 'Send',
                      onTap: _showSendCashDialog,
                    ),
                    _BalanceActionButton(
                      icon: Icons.history_toggle_off_rounded,
                      label: 'Activity',
                      onTap: _showActivityDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 2. Section Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'FEATURED SERVICES',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Mini-Apps Loader / Grid
        _isLoading && _miniApps.isEmpty
            ? _buildGridSkeleton()
            : _miniApps.isEmpty
                ? _buildEmptyState()
                : _buildGridCatalog(),
      ],
    );
  }

  Widget _buildGridCatalog() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.98,
      ),
      itemCount: _miniApps.length,
      itemBuilder: (context, index) {
        final app = _miniApps[index] as Map<String, dynamic>;
        return InkWell(
          onTap: () => _openMiniApp(app),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0F172A),
                    backgroundImage: app['iconUrl'] != null && (app['iconUrl'] as String).startsWith('http')
                        ? NetworkImage(app['iconUrl'] as String)
                        : null,
                    child: app['iconUrl'] == null || !(app['iconUrl'] as String).startsWith('http')
                        ? const Icon(Icons.apps_rounded, size: 22, color: Color(0xFF94A3B8))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    app['displayName'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app['description'] ?? '',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.98,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.4)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingSkeleton(width: 44, height: 44, borderRadius: 22),
                SizedBox(height: 14),
                _PulsingSkeleton(width: 90, height: 12, borderRadius: 4),
                SizedBox(height: 8),
                _PulsingSkeleton(width: 120, height: 10, borderRadius: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.4)),
      ),
      child: const Column(
        children: [
          Icon(Icons.widgets_outlined, color: Color(0xFF475569), size: 36),
          SizedBox(height: 12),
          Text(
            'No Services Available',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Check back later for active services.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BalanceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BalanceActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Dark circular button icon backing
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.8)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pure native pulsing loader skeleton widget to provide premium layout feedback during API loading gaps
class _PulsingSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _PulsingSkeleton({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<_PulsingSkeleton> createState() => _PulsingSkeletonState();
}

class _PulsingSkeletonState extends State<_PulsingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF334155), // Slate 700 skeleton filler
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
