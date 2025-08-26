import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/audit_entry.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'audit_entry_form_screen.dart';
import 'package:intl/intl.dart';

class AuditEntryListScreen extends StatefulWidget {
  const AuditEntryListScreen({super.key});

  @override
  _AuditEntryListScreenState createState() => _AuditEntryListScreenState();
}

class _AuditEntryListScreenState extends State<AuditEntryListScreen> {
  late Future<List<AuditEntry>> _auditEntriesFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadAuditEntries();
  }

  void _loadAuditEntries() {
    setState(() {
      _auditEntriesFuture = _apiService.fetchAuditEntries();
    });
  }

  Future<void> _deleteAuditEntry(int id) async {
    final confirmed = await CustomDialogs.showConfirmationDialog(
      context,
      'ဖျက်မည်လား?',
      'ဤစာရင်းစစ်မှတ်တမ်းကို ဖျက်ရန် သေချာပါသလား?',
    );
    if (confirmed == true) {
      try {
        await _apiService.deleteAuditEntry(id);
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Success', 'စာရင်းစစ်မှတ်တမ်းကို ဖျက်လိုက်ပါပြီ။', MessageType.success);
          _loadAuditEntries(); // Reload after deletion
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'စာရင်းစစ်မှတ်တမ်းကို ဖျက်ရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit မှတ်တမ်းများ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<AuditEntry>>(
        future: _auditEntriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Audit မှတ်တမ်းများ မရှိသေးပါ။'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final entry = snapshot.data![index];
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
                          'အဖွဲ့: ${entry.groupName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'စစ်ဆေးသူ: ${entry.auditorUsername}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text('ရရန်ပမာဏ: ${NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(entry.receivableAmount)}'),
                        Text('ပေးရန်ပမာဏ: ${NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(entry.payableAmount)}'),
                        if (entry.remarks != null && entry.remarks!.isNotEmpty)
                          Text('မှတ်ချက်: ${entry.remarks}'),
                        Text(
                          'ဖန်တီးသည့်နေ့စွဲ: ${entry.createdAt != null ? DateFormat('yyyy-MM-dd').format(entry.createdAt!) : 'N/A'}', // Null check added
                        ),
                        Text(
                          'နောက်ဆုံးပြင်ဆင်သည့်နေ့စွဲ: ${entry.lastUpdated != null ? DateFormat('yyyy-MM-dd').format(entry.lastUpdated!) : 'N/A'}', // Null check added
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AuditEntryFormScreen(auditEntry: entry),
                                  ),
                                );
                                _loadAuditEntries(); // Reload after edit
                              },
                              tooltip: 'ပြင်ဆင်မည်',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteAuditEntry(entry.id!),
                              tooltip: 'ဖျက်မည်',
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
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AuditEntryFormScreen()),
          );
          _loadAuditEntries(); // Reload after creation
        },
        label: const Text('Audit မှတ်တမ်းအသစ် ထည့်မည်'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
