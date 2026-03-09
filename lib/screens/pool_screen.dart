import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_settings.dart';
import '../utils/pool_utils.dart';
import '../utils/pool_report_pdf.dart';

/// Food Pool: date filter (Yearly, Monthly, Weekly, Daily), summary/detail views, print.
class PoolScreen extends StatefulWidget {
  const PoolScreen({Key? key}) : super(key: key);

  @override
  State<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends State<PoolScreen> {
  static const List<String> _dateRangeOptions = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  /// Default to current date on load.
  late DateTime _selectedDate;
  String _dateRangeMode = 'Daily';
  bool _isSummaryView = true;
  String _detailBreakdown = 'Food category'; // Food category | Food type | User

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  MapEntry<String, String> get _dateRange {
    return poolDateRangeForMode(_selectedDate, _dateRangeMode);
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRange;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Pool'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: () => _printCurrentView(range),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilter(range),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: appSettingsStream(),
              builder: (context, settingsSnap) {
                final showPrices = settingsSnap.data?.data()?['showMealPricesToCustomers'] as bool? ?? false;
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: poolStreamForDateRange(range.key, range.value),
                  builder: (context, poolSnap) {
                    if (poolSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (poolSnap.hasError) {
                      return Center(child: Text('Error: ${poolSnap.error}'));
                    }
                    final docs = poolSnap.data?.docs ?? [];
                    final items = docs.map((d) => {'id': d.id, ...d.data()}).toList();
                    final withQty = items.where((d) {
                      final q = d['quantity'];
                      final n = q is int ? q : (q is num ? q.toInt() : 0);
                      return n > 0;
                    }).toList();
                    final totalCount = withQty.fold<int>(
                      0,
                      (sum, d) => sum + ((d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt()),
                    );
                    final rangeIncludesToday = _rangeIncludesToday(range);
                    if (_isSummaryView) {
                      return _buildSummaryWithOptionalAllocate(
                        context,
                        totalCount,
                        range,
                        showPrices,
                        rangeIncludesToday,
                      );
                    }
                    return _buildDetailView(
                      context,
                      withQty,
                      range,
                      totalCount,
                      showPrices,
                      rangeIncludesToday,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _rangeIncludesToday(MapEntry<String, String> range) {
    final today = dateToDateString(DateTime.now());
    return today.compareTo(range.key) >= 0 && today.compareTo(range.value) <= 0;
  }

  Widget _buildDateFilter(MapEntry<String, String> range) {
    final rangeLabel = _rangeLabel(range);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Date filter:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _dateRangeMode,
                items: _dateRangeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _dateRangeMode = v ?? 'Daily'),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _dateRangeMode == 'Daily'
                      ? (_selectedDate.day == DateTime.now().day &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.year == DateTime.now().year
                          ? 'Today'
                          : '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}')
                      : rangeLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Summary'), icon: Icon(Icons.summarize)),
                  ButtonSegment(value: false, label: Text('Detail'), icon: Icon(Icons.list)),
                ],
                selected: {_isSummaryView},
                onSelectionChanged: (s) => setState(() => _isSummaryView = s.first),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rangeLabel(MapEntry<String, String> range) {
    if (range.key == range.value) return range.key;
    return '${range.key} – ${range.value}';
  }

  Widget _buildSummaryWithOptionalAllocate(
    BuildContext context,
    int totalCount,
    MapEntry<String, String> range,
    bool showPrices,
    bool rangeIncludesToday,
  ) {
    final rangeLabel = _rangeLabel(range);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.inventory_2, size: 80, color: Colors.teal.shade300),
          const SizedBox(height: 16),
          Text(
            'Food Pool total count',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalCount',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            rangeLabel,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          if (rangeIncludesToday) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              "Today's pool items (allocate)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade800),
            ),
            const SizedBox(height: 12),
            _TodayPoolAllocateList(showPrices: showPrices, onAllocate: _showAllocateDialog),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailView(
    BuildContext context,
    List<Map<String, dynamic>> withQty,
    MapEntry<String, String> range,
    int totalCount,
    bool showPrices,
    bool rangeIncludesToday,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Breakdown by:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _detailBreakdown,
                items: const [
                  DropdownMenuItem(value: 'Food category', child: Text('Food category')),
                  DropdownMenuItem(value: 'Food type', child: Text('Food type')),
                  DropdownMenuItem(value: 'User', child: Text('User')),
                ],
                onChanged: (v) => setState(() => _detailBreakdown = v ?? 'Food category'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _detailBreakdown == 'User'
              ? _buildUserBreakdown(range, totalCount)
              : _buildPoolBreakdownList(withQty, range, totalCount, showPrices, context),
        ),
        if (rangeIncludesToday) ...[
          const Divider(height: 1),
          SizedBox(
            height: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    "Today's pool items (allocate)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.teal.shade800),
                  ),
                ),
                Expanded(child: _TodayPoolAllocateList(showPrices: showPrices, onAllocate: _showAllocateDialog)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPoolBreakdownList(
    List<Map<String, dynamic>> withQty,
    MapEntry<String, String> range,
    int totalCount,
    bool showPrices,
    BuildContext context,
  ) {
    Map<String, int> byKey;
    if (_detailBreakdown == 'Food category') {
      byKey = {};
      for (final d in withQty) {
        final k = (d['mealType'] as String?) ?? 'Other';
        final q = (d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt();
        byKey[k] = (byKey[k] ?? 0) + q;
      }
    } else {
      byKey = {};
      for (final d in withQty) {
        final k = (d['productName'] as String?) ?? 'Unknown';
        final q = (d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt();
        byKey[k] = (byKey[k] ?? 0) + q;
      }
    }
    final entries = byKey.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No pool data for selected range',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: $totalCount', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                  Text(_rangeLabel(range), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          );
        }
        final e = entries[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(e.key),
            trailing: Text('${e.value}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
          ),
        );
      },
    );
  }

  Widget _buildUserBreakdown(MapEntry<String, String> range, int totalCount) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, orderSnap) {
        if (!orderSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = orderSnap.data?.docs ?? [];
        final fromPoolInRange = docs.where((d) {
          final data = d.data();
          if (data['fromPool'] != true) return false;
          final dt = _parseDate(data['deliveryDate']) ?? _parseDate(data['orderDate']);
          if (dt == null) return false;
          final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          return dateStr.compareTo(range.key) >= 0 && dateStr.compareTo(range.value) <= 0;
        }).toList();
        final byUser = <String, int>{};
        for (final d in fromPoolInRange) {
          final name = (d.data()['customerName'] as String?) ?? 'Unknown';
          final q = (d.data()['quantity'] is int) ? d.data()['quantity'] as int : (d.data()['quantity'] as num?)?.toInt() ?? 0;
          byUser[name] = (byUser[name] ?? 0) + q;
        }
        final entries = byUser.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No allocations by user in this range', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Total pool count: $totalCount', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: $totalCount', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                      Text(_rangeLabel(range), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              );
            }
            final e = entries[index - 1];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.key),
                trailing: Text('${e.value}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
              ),
            );
          },
        );
      },
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  Future<void> _printCurrentView(MapEntry<String, String> range) async {
    final rangeLabel = _rangeLabel(range);
    final poolSnap = await FirebaseFirestore.instance
        .collection('pool')
        .where('date', isGreaterThanOrEqualTo: range.key)
        .where('date', isLessThanOrEqualTo: range.value)
        .get();
    final items = poolSnap.docs.map((d) => d.data()).toList();
    final withQty = items.where((d) {
      final q = d['quantity'];
      final n = q is int ? q : (q is num ? q.toInt() : 0);
      return n > 0;
    }).toList();
    final totalCount = withQty.fold<int>(
      0,
      (sum, d) => sum + ((d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt()),
    );
    Map<String, int>? byCategory;
    Map<String, int>? byType;
    Map<String, int>? byUser;
    if (!_isSummaryView) {
      if (_detailBreakdown == 'Food category') {
        byCategory = {};
        for (final d in withQty) {
          final k = (d['mealType'] as String?) ?? 'Other';
          final q = (d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt();
          byCategory[k] = (byCategory[k] ?? 0) + q;
        }
      } else if (_detailBreakdown == 'Food type') {
        byType = {};
        for (final d in withQty) {
          final k = (d['productName'] as String?) ?? 'Unknown';
          final q = (d['quantity'] is int) ? d['quantity'] as int : (d['quantity'] as num).toInt();
          byType[k] = (byType[k] ?? 0) + q;
        }
      } else {
        final ordersSnap = await FirebaseFirestore.instance.collection('orders').get();
        final fromPoolInRange = ordersSnap.docs.where((d) {
          final data = d.data();
          if (data['fromPool'] != true) return false;
          final dt = _parseDate(data['deliveryDate']) ?? _parseDate(data['orderDate']);
          if (dt == null) return false;
          final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          return dateStr.compareTo(range.key) >= 0 && dateStr.compareTo(range.value) <= 0;
        }).toList();
        byUser = {};
        for (final d in fromPoolInRange) {
          final name = (d.data()['customerName'] as String?) ?? 'Unknown';
          final q = (d.data()['quantity'] is int) ? d.data()['quantity'] as int : (d.data()['quantity'] as num?)?.toInt() ?? 0;
          byUser[name] = (byUser[name] ?? 0) + q;
        }
      }
    }
    await printFoodPoolPdf(
      startDate: range.key,
      endDate: range.value,
      rangeLabel: rangeLabel,
      totalCount: totalCount,
      isDetailView: !_isSummaryView,
      detailBreakdown: _isSummaryView ? null : _detailBreakdown,
      byCategory: byCategory,
      byType: byType,
      byUser: byUser?.isEmpty == true ? null : byUser,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF ready to print or share')),
      );
    }
  }

  void _showAllocateDialog(
    BuildContext context, {
    required String poolDocId,
    required Map<String, dynamic> poolData,
    required int maxQty,
  }) {
    int selected = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Allocate from pool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${poolData['productName'] ?? 'Item'} · max $maxQty'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Quantity: '),
                  DropdownButton<int>(
                    value: selected.clamp(1, maxQty),
                    items: List.generate(maxQty, (i) => i + 1)
                        .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                        .toList(),
                    onChanged: (v) => setState(() => selected = v ?? 1),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = selected.clamp(1, maxQty);
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please sign in again.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }
                try {
                  await allocateFromPool(
                    poolDocId: poolDocId,
                    poolData: poolData,
                    quantity: qty,
                    customerId: user.uid,
                    customerName: user.displayName ?? user.email ?? 'Customer',
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Allocated from pool.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Allocate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPoolAllocateList extends StatelessWidget {
  const _TodayPoolAllocateList({required this.showPrices, required this.onAllocate});

  final bool showPrices;
  final void Function(BuildContext context, {required String poolDocId, required Map<String, dynamic> poolData, required int maxQty}) onAllocate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: poolStreamForDate(todayDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        final withQty = docs.where((d) {
          final q = d.data()['quantity'];
          final n = q is int ? q : (q is num ? q.toInt() : 0);
          return n > 0;
        }).toList();
        if (withQty.isEmpty) return Text('No items in pool for today', style: TextStyle(fontSize: 12, color: Colors.grey.shade600));
        return ListView.builder(
          shrinkWrap: true,
          itemCount: withQty.length,
          itemBuilder: (context, index) {
            final doc = withQty[index];
            final data = doc.data();
            final id = doc.id;
            final qty = (data['quantity'] is int) ? data['quantity'] as int : (data['quantity'] as num).toInt();
            final productName = data['productName'] ?? 'N/A';
            final mealType = data['mealType'] ?? '—';
            final vendorName = data['vendorName'] ?? '';
            final pricePerUnit = (data['pricePerUnit'] is num) ? (data['pricePerUnit'] as num).toDouble() : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(productName, style: const TextStyle(fontSize: 14)),
                subtitle: Text('$mealType · $vendorName · Qty: $qty', style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPrices && pricePerUnit > 0)
                      Text('Rs.${pricePerUnit.toStringAsFixed(2)}/unit', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => onAllocate(context, poolDocId: id, poolData: data, maxQty: qty),
                      child: const Text('Allocate'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
