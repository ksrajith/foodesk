import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../utils/registration_stats.dart';
import '../utils/registration_report_pdf.dart';
import 'admin_registration_details_screen.dart';

/// Summary of users and registration requests; opens **Registration Details** when a count is tapped.
class AdminRegistrationHistoryScreen extends StatefulWidget {
  const AdminRegistrationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AdminRegistrationHistoryScreen> createState() => _AdminRegistrationHistoryScreenState();
}

class _AdminRegistrationHistoryScreenState extends State<AdminRegistrationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetails({
    required String status,
    String? role,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AdminRegistrationDetailsScreen(
          args: RegistrationDetailsArgs(
            initialStatus: status,
            initialRole: role,
          ),
        ),
      ),
    );
  }

  Map<String, int> _emptyRoleMap() => {for (final r in kRegistrationRoleLabels) r: 0};

  void _accumulate(Map<String, int> target, String? role) {
    final k = normalizeRegistrationRole(role);
    target[k] = (target[k] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration History'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Print summary PDF',
            onPressed: () async {
              final reg = await FirebaseFirestore.instance.collection(AppConstants.collectionRegistrationRequests).get();
              final users = await FirebaseFirestore.instance.collection(AppConstants.collectionUsers).get();
              final pending = _emptyRoleMap();
              final approved = _emptyRoleMap();
              final rejected = _emptyRoleMap();
              final usersByRole = _emptyRoleMap();
              for (final d in reg.docs) {
                if (d.id == '_init') continue;
                final data = d.data();
                final s = (data['status'] as String? ?? '').toLowerCase();
                if (s == 'pending') {
                  _accumulate(pending, data['requestedRole'] as String?);
                } else if (s == 'approved') {
                  _accumulate(approved, data['approvedRole'] as String? ?? data['requestedRole'] as String?);
                } else if (s == 'rejected') {
                  _accumulate(rejected, data['requestedRole'] as String?);
                }
              }
              int totalUsers = 0;
              for (final d in users.docs) {
                if (d.id == '_init') continue;
                totalUsers++;
                _accumulate(usersByRole, d.data()['role'] as String?);
              }
              if (!context.mounted) return;
              await printRegistrationSummaryPdf(
                totalUsers: totalUsers,
                usersByRole: usersByRole,
                pendingByRole: pending,
                approvedByRole: approved,
                rejectedByRole: rejected,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(AppConstants.collectionRegistrationRequests).snapshots(),
        builder: (context, regSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(AppConstants.collectionUsers).snapshots(),
            builder: (context, userSnap) {
              if (!regSnap.hasData || !userSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pending = _emptyRoleMap();
              final approved = _emptyRoleMap();
              final rejected = _emptyRoleMap();
              for (final d in regSnap.data!.docs) {
                if (d.id == '_init') continue;
                final data = d.data();
                final s = (data['status'] as String? ?? '').toLowerCase();
                if (s == 'pending') {
                  _accumulate(pending, data['requestedRole'] as String?);
                } else if (s == 'approved') {
                  _accumulate(approved, data['approvedRole'] as String? ?? data['requestedRole'] as String?);
                } else if (s == 'rejected') {
                  _accumulate(rejected, data['requestedRole'] as String?);
                }
              }

              final usersByRole = _emptyRoleMap();
              int totalUsers = 0;
              for (final d in userSnap.data!.docs) {
                if (d.id == '_init') continue;
                totalUsers++;
                _accumulate(usersByRole, d.data()['role'] as String?);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Card(
                      elevation: 2,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(Icons.people, color: Colors.teal.shade800),
                        ),
                        title: Text(
                          'Total users: $totalUsers',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: const Text('Tap to expand counts by role'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: kRegistrationRoleLabels
                                  .map(
                                    (r) => ListTile(
                                      dense: true,
                                      title: Text(r),
                                      trailing: Text(
                                        '${usersByRole[r] ?? 0}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Registration requests by role — tap a count to open Registration Details',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRoleCountTab(
                          title: 'Pending',
                          counts: pending,
                          statusKey: 'pending',
                          color: Colors.orange.shade700,
                        ),
                        _buildRoleCountTab(
                          title: 'Approved',
                          counts: approved,
                          statusKey: 'approved',
                          color: Colors.green.shade700,
                        ),
                        _buildRoleCountTab(
                          title: 'Rejected',
                          counts: rejected,
                          statusKey: 'rejected',
                          color: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoleCountTab({
    required String title,
    required Map<String, int> counts,
    required String statusKey,
    required Color color,
  }) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: color.withOpacity(0.08),
          child: ListTile(
            title: Text('Total $title', style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text(
              '$total',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            onTap: total > 0 ? () => _openDetails(status: statusKey) : null,
          ),
        ),
        const SizedBox(height: 12),
        ...kRegistrationRoleLabels.map((role) {
          final n = counts[role] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: n > 0 ? () => _openDetails(status: statusKey, role: role) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(role, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(
                              n > 0 ? 'Tap to view details' : 'No requests',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: n > 0 ? color : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
