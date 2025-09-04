import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../transactions/transaction_form_screen.dart';

class AuditorRejectedOnlyScreen extends StatefulWidget {
  final double? height; // optional fixed height wrapper
  const AuditorRejectedOnlyScreen({super.key, this.height});

  @override
  State<AuditorRejectedOnlyScreen> createState() =>
      _AuditorRejectedOnlyScreenState();
}

class _AuditorRejectedOnlyScreenState extends State<AuditorRejectedOnlyScreen> {
  bool _loading = false;
  List<Transaction> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService().fetchTransactionsFiltered(
        status: 'rejected',
      );
      setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty)
      return const Center(child: Text('Reject ဖြစ်ထားသော မှတ်တမ်း မရှိသေးပါ'));

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = _items[i];
        return ListTile(
          leading: const Icon(Icons.error, color: Colors.orange),
          title: Text(
            '${t.transferIdLast6Digits} • ${t.amount.toStringAsFixed(2)}',
          ),
          subtitle: Text('Rejected • ${_fmtDate(t.transactionDate)}'),
          trailing: const Text(
            'ပြင်ပြီး ပြန်တင်',
            style: TextStyle(color: Colors.blue),
          ),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionFormScreen(transaction: t),
              ),
            );
            if (!mounted) return;
            _load(); // refresh after edit (perform_update → pending)
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _buildList();
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: list);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected (ပြင်ပြီး ပြန်တင်ရန်)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(8), child: list),
    );
  }
}
