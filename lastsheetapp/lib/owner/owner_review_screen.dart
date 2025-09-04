import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lastsheetapp/screens/transactions/transaction_form_screen.dart';

import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../utils/custom_dialogs.dart';
import '../../utils/constants.dart';

class OwnerReviewScreen extends StatefulWidget {
  const OwnerReviewScreen({super.key});

  @override
  State<OwnerReviewScreen> createState() => _OwnerReviewScreenState();
}

class _OwnerReviewScreenState extends State<OwnerReviewScreen> {
  final _last6Controller = TextEditingController();
  DateTime? _from;
  DateTime? _to;

  bool _loading = false;
  final Set<int> _workingIds = {}; // approve/reject in-progress
  List<Transaction> _items = [];

  @override
  void initState() {
    super.initState();
    _search(); // initial: pending only
  }

  @override
  void dispose() {
    _last6Controller.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------
  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${Constants.baseUrl}$imageUrl';
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _to = picked);
  }

  void _applyQuickRange(Duration d) {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = now.subtract(d);
    });
    _search();
  }

  void _clearFilters() {
    setState(() {
      _last6Controller.clear();
      _from = null;
      _to = null;
    });
    _search();
  }

  // ---------------- actions ----------------
  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final last6 = _last6Controller.text.trim();
      final results = await ApiService().fetchTransactionsFiltered(
        last6: last6.length == 6 ? last6 : null,
        dateFrom: _from,
        dateTo: _to,
        status: 'pending', // review only pending
      );
      setState(() => _items = results);
    } catch (e) {
      if (!mounted) return;
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Transaction t) async {
    if (t.id == null) return;
    setState(() => _workingIds.add(t.id!));
    try {
      await ApiService().approveTransaction(t.id!, ownerNotes: null);
      setState(() => _items.removeWhere((x) => x.id == t.id));
      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'Approve ပြီးပါပြီ',
        MessageType.success,
      );
    } catch (e) {
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    } finally {
      setState(() => _workingIds.remove(t.id!));
    }
  }

  Future<void> _reject(Transaction t) async {
    if (t.id == null) return;
    final note = await _askRejectNote();
    if (note == null) return;
    setState(() => _workingIds.add(t.id!));
    try {
      await ApiService().rejectTransaction(t.id!, ownerNotes: note);
      setState(() => _items.removeWhere((x) => x.id == t.id));
      if (!mounted) return;
      CustomDialogs.showFlushbar(
        context,
        'Success',
        'Reject ပြီးပါပြီ',
        MessageType.success,
      );
    } catch (e) {
      CustomDialogs.showFlushbar(context, 'Error', '$e', MessageType.error);
    } finally {
      setState(() => _workingIds.remove(t.id!));
    }
  }

  Future<String?> _askRejectNote() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject မှတ်ချက် ထည့်ပါ'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'မှတ်ချက်...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('မလုပ်တော့'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('သဘောတူ'),
          ),
        ],
      ),
    );
  }

  void _openDetails(Transaction t) {
    final img = _buildImageUrl(t.imageUrl);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('အသေးစိတ်', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (img.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(img, height: 180, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              _kv('Date', _fmtDate(t.transactionDate)),
              _kv('Group', t.groupName),
              _kv('Account', t.paymentAccountName),
              _kv(
                'Type',
                t.transactionTypeDisplay ??
                    (t.transactionType == 'income' ? 'ဝင်ငွေ' : 'ထွက်ငွေ'),
              ),
              _kv('Amount', t.amount.toStringAsFixed(2)),
              _kv('Last 6', t.transferIdLast6Digits),
              if ((t.ownerNotes ?? '').isNotEmpty)
                _kv('Owner Notes', t.ownerNotes!),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit (open form)'),
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TransactionFormScreen(transaction: t),
                          ),
                        );
                        if (!mounted) return;
                        _search();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      onPressed: _workingIds.contains(t.id!)
                          ? null
                          : () => _approve(t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cancel),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  label: const Text('Reject with note'),
                  onPressed: _workingIds.contains(t.id!)
                      ? null
                      : () => _reject(t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final dateLbl = (DateTime? d) => d == null ? 'ရွေးရန်' : _fmtDate(d);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner/Admin Review'),
        actions: [
          IconButton(
            onPressed: _clearFilters,
            tooltip: 'Clear filters',
            icon: const Icon(Icons.filter_alt_off),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Filter row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _last6Controller,
                    decoration: const InputDecoration(
                      labelText: 'Transfer ID နောက်ဆုံး ၆ လုံး',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (s) {
                      if (s.trim().length == 6) _search();
                    },
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text('From: ${dateLbl(_from)}'),
                  onPressed: _pickFrom,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text('To: ${dateLbl(_to)}'),
                  onPressed: _pickTo,
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quick ranges
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    text: 'Today',
                    onTap: () => _applyQuickRange(const Duration(days: 0)),
                  ),
                  _QuickChip(
                    text: 'Last 7 days',
                    onTap: () => _applyQuickRange(const Duration(days: 7)),
                  ),
                  _QuickChip(
                    text: 'Last 30 days',
                    onTap: () => _applyQuickRange(const Duration(days: 30)),
                  ),
                  _QuickChip(text: 'Clear', onTap: _clearFilters),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pending: ${_items.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('မှတ်တမ်းမရှိပါ'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = _items[i];
                        final busy =
                            t.id != null && _workingIds.contains(t.id!);
                        return ListTile(
                          title: Text(
                            '${t.transferIdLast6Digits} • ${t.transactionType} • ${t.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            '${_fmtDate(t.transactionDate)} • ${t.groupName} • ${t.paymentAccountName}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Approve',
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: busy ? null : () => _approve(t),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: busy ? null : () => _reject(t),
                              ),
                            ],
                          ),
                          onTap: () => _openDetails(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _QuickChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(label: Text(text), onPressed: onTap),
    );
  }
}
