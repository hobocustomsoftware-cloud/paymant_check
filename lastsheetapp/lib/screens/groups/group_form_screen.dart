import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../services/api_service.dart';
import '../../models/group.dart';
import '../../models/user.dart'; // Import User model for owner ID
import '../../providers/auth_provider.dart'; // Import AuthProvider
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported

class GroupFormScreen extends StatefulWidget {
  final Group? group; // For editing existing group

  GroupFormScreen({this.group});

  @override
  _GroupFormScreenState createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(); // Changed from _groupNameController
  final _groupTitleController = TextEditingController(); // New
  final _groupTypeController = TextEditingController();   // New
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameController.text = widget.group!.name; // Changed to group.name
      _groupTitleController.text = widget.group!.groupTitle;
      _groupTypeController.text = widget.group!.groupType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupTitleController.dispose();
    _groupTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveGroup() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null || currentUser.id == null) {
        if (mounted) {
          CustomDialogs.showAlertDialog(context, 'အမှား', 'အသုံးပြုသူ အချက်အလက် မရှိပါ။');
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final groupToSave = Group(
        id: widget.group?.id,
        name: _nameController.text, // Changed to name
        groupTitle: _groupTitleController.text,
        groupType: _groupTypeController.text,
        owner: currentUser.id!, // Assign current user's ID as owner
      );

      try {
        if (widget.group == null) {
          // Create new group
          await _apiService.createGroup(groupToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'အဖွဲ့အသစ် ဖန်တီးပြီးပါပြီ။', // Message
              MessageType.success, // Type
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        } else {
          // Update existing group
          await _apiService.updateGroup(groupToSave);
          if (mounted) {
            CustomDialogs.showFlushbar(
              context,
              'Success', // Title
              'အဖွဲ့ကို ပြင်ဆင်ပြီးပါပြီ။', // Message
              MessageType.success, // Type
              onDismissed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          }
        }
      } catch (e) {
        if (mounted) {
          CustomDialogs.showFlushbar(context, 'Error', 'အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error); // Added MessageType
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'အဖွဲ့အသစ် ဖန်တီးမည်' : 'အဖွဲ့ ပြင်ဆင်မည်'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nameController, // Changed to _nameController
                decoration: InputDecoration(
                  labelText: 'အဖွဲ့အမည်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အဖွဲ့အမည် ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _groupTitleController,
                decoration: InputDecoration(
                  labelText: 'အဖွဲ့ခေါင်းစဉ်',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အဖွဲ့ခေါင်းစဉ် ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _groupTypeController,
                decoration: InputDecoration(
                  labelText: 'အဖွဲ့အမျိုးအစား',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'အဖွဲ့အမျိုးအစား ဖြည့်သွင်းပါ။';
                  }
                  return null;
                },
              ),
              // Removed description field
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveGroup,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        elevation: 5,
                      ),
                      child: Text(
                        widget.group == null ? 'အဖွဲ့ ဖန်တီးမည်' : 'အဖွဲ့ ပြင်ဆင်မည်',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
