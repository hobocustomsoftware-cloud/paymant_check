import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AuditEntriesSummaryWidget extends StatefulWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  final double? height; // optional fixed height

  const AuditEntriesSummaryWidget({
    super.key,
    this.title = 'Audit Entries Summary',
    this.padding = const EdgeInsets.all(12),
    this.height,
  });

  @override
  State<AuditEntriesSummaryWidget> createState() =>
      _AuditEntriesSummaryWidgetState();
}

class _AuditEntriesSummaryWidgetState extends State<AuditEntriesSummaryWidget> {
  String _period = 'daily'; // daily|weekly|monthly|yearly
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  String _d(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _end = now;
    _start = now.subtract(const Duration(days: 7)); // default: past 7 days
    _load();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d != null) setState(() => _end = d);
  }

  void _quick(Duration dur) {
    final now = DateTime.now();
    setState(() {
      _end = now;
      _start = now.subtract(dur);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().fetchAuditEntrySummary(
        period: _period,
        start: _start,
        end: _end,
      );
      setState(() => _rows = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Summary error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        DropdownButton<String>(
          value: _period,
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _period = v);
            _load();
          },
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_start == null ? 'Start' : _d(_start!)),
          onPressed: _pickStart,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_end == null ? 'End' : _d(_end!)),
          onPressed: _pickEnd,
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _load,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
        const Spacer(),
        Wrap(
          spacing: 6,
          children: [
            ActionChip(
              label: const Text('Today'),
              onPressed: () => _quick(const Duration(days: 0)),
            ),
            ActionChip(
              label: const Text('7 days'),
              onPressed: () => _quick(const Duration(days: 7)),
            ),
            ActionChip(
              label: const Text('30 days'),
              onPressed: () => _quick(const Duration(days: 30)),
            ),
            ActionChip(
              label: const Text('1 year'),
              onPressed: () => _quick(const Duration(days: 365)),
            ),
          ],
        ),
      ],
    );

    final list = _loading
        ? const Center(child: CircularProgressIndicator())
        : _rows.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No data'),
            ),
          )
        : ListView.separated(
            itemCount: _rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = _rows[i];
              final dt = r['period_start'];
              final label = dt is String
                  ? dt
                  : DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.parse(dt.toString()));
              return ListTile(
                dense: true,
                title: Text(label),
                subtitle: Text('count: ${r['total_count']}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total: ${r['total_amount']}'),
                    Text(
                      'Receive: ${r['total_receive']} • Pay: ${r['total_pay']}',
                    ),
                  ],
                ),
              );
            },
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        header,
        const SizedBox(height: 10),
        Expanded(child: list),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: widget.padding,
        child: widget.height == null
            ? SizedBox(height: 320, child: content)
            : SizedBox(height: widget.height!, child: content),
      ),
    );
  }
}
