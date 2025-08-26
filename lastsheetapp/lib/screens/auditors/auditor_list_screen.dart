import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'auditor_form_screen.dart';

class AuditorUserListScreen extends StatefulWidget {
  @override
  _AuditorUserListScreenState createState() => _AuditorUserListScreenState();
}

class _AuditorUserListScreenState extends State<AuditorUserListScreen> {
  late Future<List<User>> _auditorsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadAuditors();
  }

  void _loadAuditors() {
    setState(() {
      _auditorsFuture = _apiService.fetchAuditors();
    });
  }

  Future<void> _deleteAuditor(int id) async {
    final confirmed = await CustomDialogs.showConfirmationDialog( // Corrected method name
      context,
      'ဖျက်မည်လား?',
      'ဤစစ်ဆေးသူအကောင့်ကို ဖျက်ရန် သေချာပါသလား?',
    );
    if (confirmed == true) {
      try {
        await _apiService.deleteAuditor(id);
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Success', 'စစ်ဆေးသူအကောင့်ကို ဖျက်လိုက်ပါပြီ။', MessageType.success); // Added MessageType
          _loadAuditors(); // Reload after deletion
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'ဖျက်ရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error); // Added MessageType
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('စစ်ဆေးသူများ'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<User>>(
        future: _auditorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('စစ်ဆေးသူများ မရှိသေးပါ။'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final auditor = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auditor.username,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(auditor.email),
                              if (auditor.phoneNumber != null && auditor.phoneNumber!.isNotEmpty)
                                Text('ဖုန်း: ${auditor.phoneNumber}'),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AuditorUserFormScreen(auditor: auditor),
                                  ),
                                );
                                _loadAuditors(); // Reload after edit
                              },
                              tooltip: 'ပြင်ဆင်မည်',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteAuditor(auditor.id!),
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
            MaterialPageRoute(builder: (context) => AuditorUserFormScreen()),
          );
          _loadAuditors(); // Reload after creation
        },
        label: const Text('စစ်ဆေးသူအသစ် ဖန်တီးမည်'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
