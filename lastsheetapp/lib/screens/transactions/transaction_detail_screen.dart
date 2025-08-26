import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../services/api_service.dart';
import '../../utils/custom_dialogs.dart'; // Make sure CustomDialogs is imported
import 'package:intl/intl.dart';
import '../../utils/constants.dart'; // For Constants.baseUrl

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;

  TransactionDetailScreen({required this.transaction});

  @override
  _TransactionDetailScreenState createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _ownerNotesController = TextEditingController();
  bool _isLoading = false;
  late Transaction _currentTransaction;

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
    _ownerNotesController.text = _currentTransaction.ownerNotes ?? '';
  }

  @override
  void dispose() {
    _ownerNotesController.dispose();
    super.dispose();
  }

  Future<void> _approveTransaction() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedTransaction = await _apiService.approveTransaction(
        _currentTransaction.id!,
        ownerNotes: _ownerNotesController.text.isEmpty ? null : _ownerNotesController.text,
      );
      if (mounted) {
        setState(() {
          _currentTransaction = updatedTransaction;
        });
        CustomDialogs.showFlushbar(
          context,
          'Success',
          'ငွေပေးချေမှုကို အတည်ပြုလိုက်ပါပြီ။',
          MessageType.success,
          onDismissed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        CustomDialogs.showFlushbar(context, 'Error', 'အတည်ပြုရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rejectTransaction() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final updatedTransaction = await _apiService.rejectTransaction(
        _currentTransaction.id!,
        ownerNotes: _ownerNotesController.text.isEmpty ? null : _ownerNotesController.text,
      );
      if (mounted) {
        setState(() {
          _currentTransaction = updatedTransaction;
        });
        CustomDialogs.showFlushbar(
          context,
          'Success',
          'ငွေပေးချေမှုကို ပယ်ချလိုက်ပါပြီ။',
          MessageType.success,
          onDismissed: () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        CustomDialogs.showFlushbar(context, 'Error', 'ပယ်ချရာတွင် အမှားအယွင်းရှိခဲ့ပါသည်။: $e', MessageType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper to build the correct image URL
  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    // Check if the imageUrl is already an absolute URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    // Otherwise, prepend the base URL
    return '${Constants.baseUrl}$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = _currentTransaction.imageUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ငွေပေးချေမှု အသေးစိတ်'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('ငွေပမာဏ:', NumberFormat.currency(locale: 'en_US', symbol: 'MMK ').format(_currentTransaction.amount)),
                          _buildDetailRow('အမျိုးအစား:', _currentTransaction.transactionType == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ',
                              color: _currentTransaction.transactionType == 'income' ? Colors.green : Colors.red),
                          _buildDetailRow('နေ့စွဲ:', DateFormat('yyyy-MM-dd').format(_currentTransaction.transactionDate)),
                          _buildDetailRow('အဖွဲ့:', _currentTransaction.groupName ?? 'N/A'),
                          _buildDetailRow('ငွေစာရင်း:', _currentTransaction.paymentAccountName ?? 'N/A'),
                          _buildDetailRow('လွှဲပြောင်း ID (နောက်ဆုံး ၆ လုံး):', _currentTransaction.transferIdLast6Digits),
                          _buildDetailRow('တင်ပြသူ:', _currentTransaction.submittedByUsername ?? 'N/A'),
                          _buildDetailRow('တင်ပြသည့်အချိန်:', _currentTransaction.submittedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(_currentTransaction.submittedAt!) : 'N/A'),
                          _buildDetailRow('အခြေအနေ:', _currentTransaction.status == 'pending' ? 'စောင့်ဆိုင်းဆဲ' : (_currentTransaction.status == 'approved' ? 'အတည်ပြုပြီး' : 'ပယ်ချပြီး'),
                              color: _currentTransaction.status == 'pending' ? Colors.orange : (_currentTransaction.status == 'approved' ? Colors.green : Colors.red)),
                          if (_currentTransaction.approvedByOwnerAt != null)
                            _buildDetailRow('အတည်ပြု/ပယ်ချသည့်အချိန်:', DateFormat('yyyy-MM-dd HH:mm').format(_currentTransaction.approvedByOwnerAt!)),
                          if (_currentTransaction.ownerNotes != null && _currentTransaction.ownerNotes!.isNotEmpty)
                            _buildDetailRow('ပိုင်ရှင်၏ မှတ်ချက်:', _currentTransaction.ownerNotes!),
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ပုံ:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Image.network(
                                      _buildImageUrl(imageUrl),
                                      height: 200,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Image loading error: $error');
                                        print('Image URL: ${_buildImageUrl(imageUrl)}'); // Log full URL for debugging
                                        return Container(
                                          height: 200,
                                          width: double.infinity,
                                          color: Colors.grey[200],
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
                                              SizedBox(height: 10),
                                              Text(
                                                'ပုံကို ပြသ၍ မရပါ။',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                              Text(
                                                'Error: ${error.toString().split(':')[0]}',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              Text(
                                                'URL: ${_buildImageUrl(imageUrl)}', // Show full URL in error message
                                                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_currentTransaction.status == 'pending')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ပိုင်ရှင်၏ မှတ်ချက် (ရှိလျှင်)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ownerNotesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'မှတ်ချက် ထည့်သွင်းပါ...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _approveTransaction,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('အတည်ပြုမည်'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _rejectTransaction,
                                icon: const Icon(Icons.cancel),
                                label: const Text('ပယ်ချမည်'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
