import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'secure_session_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────────────

/// Strongly-typed representation of a single ledger entry returned by
/// {@code GET /api/v1/wallet/{userId}/transactions}.
class LedgerTransaction {
  final String txnId;
  final TxnType type;
  final String currency;
  final double amount;
  final double? balanceAfter;
  final String? counterparty;
  final String description;
  final DateTime timestamp;

  const LedgerTransaction({
    required this.txnId,
    required this.type,
    required this.currency,
    required this.amount,
    this.balanceAfter,
    this.counterparty,
    required this.description,
    required this.timestamp,
  });

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      txnId:        json['txnId'] as String? ?? '',
      type:         TxnType.values.firstWhere(
                      (e) => e.name == (json['type'] as String? ?? 'DEBIT'),
                      orElse: () => TxnType.DEBIT,
                    ),
      currency:     json['currency'] as String? ?? 'USD',
      amount:       (json['amount'] as num? ?? 0).toDouble(),
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble(),
      counterparty: json['counterparty'] as String?,
      description:  json['description'] as String? ?? '',
      timestamp:    DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

enum TxnType { CREDIT, DEBIT, TRANSFER_OUT, TRANSFER_IN }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page Activity Screen showing the user's paginated transaction history,
/// fetched from the Spring Boot ledger and rendered with a premium dark-mode UI.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  static const String _backendHost =
      String.fromEnvironment('BACKEND_HOST', defaultValue: 'http://localhost:8080');

  List<LedgerTransaction> _transactions = [];
  bool _isLoading = true;
  String? _error;

  // Filter state
  TxnType? _selectedFilter; // null → show all
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fetchTransactions();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fadeController.reset();

    try {
      final String userId = SecureSessionManager.username ?? 'user-001';
      final response = await http
          .get(Uri.parse('$_backendHost/api/v1/wallet/$userId/transactions?limit=100'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(response.body) as List<dynamic>;
        final parsed = raw
            .map((e) => LedgerTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _transactions = parsed;
            _isLoading = false;
          });
          _fadeController.forward();
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── Filtered list ──────────────────────────────────────────────────────────

  List<LedgerTransaction> get _filtered {
    if (_selectedFilter == null) return _transactions;
    return _transactions.where((t) => t.type == _selectedFilter).toList();
  }

  // ── Summary totals ─────────────────────────────────────────────────────────

  double _totalIn() => _transactions
      .where((t) => t.type == TxnType.CREDIT || t.type == TxnType.TRANSFER_IN)
      .fold(0.0, (sum, t) => sum + t.amount);

  double _totalOut() => _transactions
      .where((t) => t.type == TxnType.DEBIT || t.type == TxnType.TRANSFER_OUT)
      .fold(0.0, (sum, t) => sum + t.amount);

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1E293B),
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white70, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'ACTIVITY',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
          fontSize: 14,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Divider(
          color: const Color(0xFF334155).withValues(alpha: 0.4),
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_transactions.isEmpty) return _buildEmptyState();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Summary Card ──────────────────────────────────────────────────
          _buildSummaryCard(),
          const SizedBox(height: 24),

          // ── Filter Chips ──────────────────────────────────────────────────
          _buildFilterRow(),
          const SizedBox(height: 20),

          // ── Transaction count label ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14),
            child: Text(
              '${_filtered.length} TRANSACTION${_filtered.length == 1 ? '' : 'S'}',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // ── Transaction Rows ──────────────────────────────────────────────
          ..._filtered.map((t) => _TransactionRow(txn: t)),

          const SizedBox(height: 32),
          // ── Pull-to-refresh hint ──────────────────────────────────────────
          const Center(
            child: Text(
              'Pull down to refresh',
              style: TextStyle(color: Color(0xFF334155), fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Summary Card ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'MONEY IN',
              amount: _totalIn(),
              color: const Color(0xFF10B981),
              icon: Icons.arrow_downward_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: const Color(0xFF334155).withValues(alpha: 0.5),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'MONEY OUT',
              amount: _totalOut(),
              color: const Color(0xFFEF4444),
              icon: Icons.arrow_upward_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: const Color(0xFF334155).withValues(alpha: 0.5),
          ),
          Expanded(
            child: _SummaryTile(
              label: 'TOTAL TXN',
              amount: _transactions.length.toDouble(),
              isCount: true,
              color: const Color(0xFF818CF8),
              icon: Icons.receipt_long_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = <TxnType?, String>{
      null:                    'All',
      TxnType.CREDIT:          'Top-up',
      TxnType.DEBIT:           'Payments',
      TxnType.TRANSFER_OUT:    'Sent',
      TxnType.TRANSFER_IN:     'Received',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final bool selected = _selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Loading / Error / Empty states ────────────────────────────────────────

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: 7,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF334155).withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const _Shimmer(width: 40, height: 40, radius: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Shimmer(
                          width: 120 + (i % 3) * 20.0, height: 12, radius: 4),
                      const SizedBox(height: 8),
                      const _Shimmer(width: 80, height: 10, radius: 4),
                    ],
                  ),
                ),
                const _Shimmer(width: 60, height: 14, radius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFEF4444)),
        const SizedBox(height: 16),
        const Text(
          'Could Not Load Activity',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Unknown error.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF334155)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _fetchTransactions,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 100),
        Icon(Icons.receipt_long_outlined, size: 52, color: Color(0xFF334155)),
        SizedBox(height: 16),
        Text(
          'No Transactions Yet',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Your ledger is empty. Add cash or make a payment\nthrough one of the featured services.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final bool isCount;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(
          isCount ? amount.toInt().toString() : '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

/// A single transaction row card rendered in the list.
class _TransactionRow extends StatelessWidget {
  final LedgerTransaction txn;

  const _TransactionRow({required this.txn});

  // ── Visual configuration by type ──────────────────────────────────────────

  IconData get _icon {
    switch (txn.type) {
      case TxnType.CREDIT:       return Icons.add_circle_outline_rounded;
      case TxnType.DEBIT:        return Icons.remove_circle_outline_rounded;
      case TxnType.TRANSFER_OUT: return Icons.arrow_outward_rounded;
      case TxnType.TRANSFER_IN:  return Icons.call_received_rounded;
    }
  }

  Color get _color {
    switch (txn.type) {
      case TxnType.CREDIT:       return const Color(0xFF10B981);
      case TxnType.DEBIT:        return const Color(0xFFEF4444);
      case TxnType.TRANSFER_OUT: return const Color(0xFFF59E0B);
      case TxnType.TRANSFER_IN:  return const Color(0xFF10B981);
    }
  }

  String get _sign {
    switch (txn.type) {
      case TxnType.CREDIT:       return '+';
      case TxnType.DEBIT:        return '-';
      case TxnType.TRANSFER_OUT: return '-';
      case TxnType.TRANSFER_IN:  return '+';
    }
  }

  String get _typeLabel {
    switch (txn.type) {
      case TxnType.CREDIT:       return 'Top-up';
      case TxnType.DEBIT:        return 'Payment';
      case TxnType.TRANSFER_OUT: return 'Sent';
      case TxnType.TRANSFER_IN:  return 'Received';
    }
  }

  String get _formattedDate {
    final dt = txn.timestamp.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour   = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$minute';
  }

  String get _currencySymbol {
    switch (txn.currency) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      default:    return '\$';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          // Copy transaction ID to clipboard
          Clipboard.setData(ClipboardData(text: txn.txnId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied: ${txn.txnId}'),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF334155).withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Icon bubble ──────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _color.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(_icon, color: _color, size: 18),
              ),
              const SizedBox(width: 14),

              // ── Description + date ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          txn.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              color: _color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedDate,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11,
                      ),
                    ),
                    if (txn.balanceAfter != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Balance after: $_currencySymbol${txn.balanceAfter!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Amount ───────────────────────────────────────────────────
              Text(
                '$_sign$_currencySymbol${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated shimmer placeholder used while loading transaction records.
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _Shimmer({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
