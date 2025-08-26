import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/group.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'group_form_screen.dart';

class GroupListScreen extends StatefulWidget {
  @override
  _GroupListScreenState createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  late Future<List<Group>> _groupsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    setState(() {
      _groupsFuture = _apiService.fetchGroups();
    });
  }

  Future<void> _deleteGroup(int id) async {
    final confirmed = await CustomDialogs.showConfirmationDialog( // Corrected method name
      context,
      'ဖျက်မည်လား?',
      'ဤအဖွဲ့ကို ဖျက်ရန် သေချာပါသလား?',
    );
    if (confirmed == true) {
      try {
        await _apiService.deleteGroup(id);
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Success', 'အဖွဲ့ကို ဖျက်လိုက်ပါပြီ။', MessageType.success); // Added MessageType
          _loadGroups(); // Reload after deletion
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'အဖွဲ့ကို ဖျက်ရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error); // Added MessageType
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('အဖွဲ့များ'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('အမှားအယွင်းရှိပါသည်။: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('အဖွဲ့များ မရှိသေးပါ။'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final group = snapshot.data![index];
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
                                group.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text('Title: ${group.groupTitle}'),
                              Text('Type: ${group.groupType}'),
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
                                    builder: (context) => GroupFormScreen(group: group),
                                  ),
                                );
                                _loadGroups(); // Reload after edit
                              },
                              tooltip: 'ပြင်ဆင်မည်',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteGroup(group.id!),
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
            MaterialPageRoute(builder: (context) => GroupFormScreen()),
          );
          _loadGroups(); // Reload after creation
        },
        label: const Text('အဖွဲ့အသစ် ဖန်တီးမည်'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
