import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/audit_summary.dart';
import '../../utils/custom_dialogs.dart';

class AuditSummaryScreen extends StatefulWidget {
  const AuditSummaryScreen({super.key});

  @override
  State<AuditSummaryScreen> createState() => _AuditSummaryScreenState();
}

class _AuditSummaryScreenState extends State<AuditSummaryScreen> {
  late Future<List<AuditSummary>> _auditSummaryFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadAuditSummary();
  }

  void _loadAuditSummary() {
    setState(() {
      _auditSummaryFuture = _apiService.fetchAuditSummary() as Future<List<AuditSummary>>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Summary'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<AuditSummary>>(
        future: _auditSummaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Audit summary load လုပ်ရာတွင် အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Audit summary မရှိသေးပါ။'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final summary = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'အဖွဲ့အမည်: ${summary.groupName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 10),
                        _buildSummaryRow(
                          'စုစုပေါင်း ရရန်:',
                          NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(summary.totalReceivable),
                          Colors.green,
                        ),
                        _buildSummaryRow(
                          'စုစုပေါင်း ပေးရန်:',
                          NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(summary.totalPayable),
                          Colors.red,
                        ),
                        _buildSummaryRow(
                          'အသားတင် လက်ကျန်:',
                          NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(summary.netBalance),
                          summary.netBalance >= 0 ? Colors.blue : Colors.redAccent,
                        ),
                        if (summary.lastAuditDate != null)
                          _buildSummaryRow(
                            'နောက်ဆုံး Audit နေ့စွဲ:',
                            DateFormat('yyyy-MM-dd').format(summary.lastAuditDate!),
                            null,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
