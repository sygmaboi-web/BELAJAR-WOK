import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../main.dart';
import '../models/budget_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future<dynamic> _loadBudgetData() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    final budgetRaw = await db.queryAll('budget_config', where: 'id = 1');
    final BudgetConfig config = budgetRaw.isNotEmpty
        ? BudgetConfig.fromMap(budgetRaw.first)
        : BudgetConfig(
            periodName: 'Mingguan',
            totalBudget: 210000,
            startDate: DateFormat('yyyy-MM-dd').format(now),
            endDate: DateFormat('yyyy-MM-dd')
                .format(now.add(const Duration(days: 6))),
          );

    final txRaw = await db.queryAll(
      'transactions',
      where: 'date >= ?',
      whereArgs: ['${config.startDate} 00:00'],
      orderBy: 'id DESC',
    );
    final transactions =
        txRaw.map((e) => TransactionItem.fromMap(e)).toList();

    final double totalSpent =
        transactions.fold(0.0, (sum, item) => sum + item.amount);
    final double remainingBudget = config.totalBudget - totalSpent;

    final DateTime endDate = DateTime.parse(config.endDate);
    final DateTime todayOnly = DateTime(now.year, now.month, now.day);
    final int remainingDays =
        (endDate.difference(todayOnly).inDays + 1).clamp(1, 365);
    final double safeToday =
        remainingBudget > 0 ? remainingBudget / remainingDays : 0.0;

    final envRaw = await db.queryAll('envelopes', orderBy: 'id ASC');
    final envelopes = envRaw.map((e) => EnvelopeItem.fromMap(e)).toList();

    return {
      'config': config,
      'transactions': transactions,
      'remainingBudget': remainingBudget,
      'safeToday': safeToday,
      'envelopes': envelopes,
    };
  }

  void _showConfigureBudgetDialog(BuildContext context, BudgetConfig current) {
    final amountCtrl =
        TextEditingController(text: current.totalBudget.toInt().toString());
    String period = current.periodName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Atur Uang Saku Periode Ini'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: period,
                decoration: const InputDecoration(labelText: 'Periode'),
                items: ['Mingguan', 'Bulanan']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => period = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Uang Saku (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (total <= 0) return;

                final now = DateTime.now();
                final fmt = DateFormat('yyyy-MM-dd');
                final end = period == 'Mingguan'
                    ? now.add(const Duration(days: 6))
                    : DateTime(now.year, now.month + 1, 0);

                final updated = BudgetConfig(
                  id: 1,
                  periodName: period,
                  totalBudget: total,
                  startDate: fmt.format(now),
                  endDate: fmt.format(end),
                );
                await DatabaseHelper.instance.updateRow(
                  'budget_config',
                  updated.toMap(),
                  'id = 1',
                  [],
                );
                if (context.mounted) {
                  Provider.of<AppStateProvider>(context, listen: false)
                      .notifyAllScreens();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEnvelopeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final currentCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Amplop Target Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Target',
                hintText: 'Contoh: Servis Motor / Upgrade Gear',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Nominal (Rp)',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: currentCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo Awal (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final target = double.tryParse(targetCtrl.text.trim()) ?? 0;
              final curr = double.tryParse(currentCtrl.text.trim()) ?? 0;
              if (nameCtrl.text.trim().isEmpty || target <= 0) return;

              final env = EnvelopeItem(
                name: nameCtrl.text.trim(),
                targetAmount: target,
                currentAmount: curr,
                iconName: 'savings',
              );
              await DatabaseHelper.instance
                  .insertRow('envelopes', env.toMap());
              if (context.mounted) {
                Provider.of<AppStateProvider>(context, listen: false)
                    .notifyAllScreens();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  void _showSweepDialog(
    BuildContext context,
    double safeToday,
    List<EnvelopeItem> envelopes,
  ) {
    if (safeToday <= 0 || envelopes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tidak ada sisa jatah hari ini atau belum ada Amplop Target.'),
        ),
      );
      return;
    }

    EnvelopeItem selectedEnv = envelopes.first;
    final sweepAmountCtrl =
        TextEditingController(text: safeToday.floor().toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tutup Buku Harian (Sweep)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pindahkan sisa jatah jajan hari ini ke dalam Amplop Target tabunganmu:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sweepAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Disimpan (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EnvelopeItem>(
                value: selectedEnv,
                decoration: const InputDecoration(labelText: 'Pilih Amplop'),
                items: envelopes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedEnv = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amount =
                    double.tryParse(sweepAmountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;

                final db = DatabaseHelper.instance;
                await db.updateRow(
                  'envelopes',
                  {'current_amount': selectedEnv.currentAmount + amount},
                  'id = ?',
                  [selectedEnv.id],
                );

                final tx = TransactionItem(
                  title: 'Sweep ke Amplop: ${selectedEnv.name}',
                  amount: amount,
                  category: 'Sweep Tabungan',
                  date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                );
                await db.insertRow('transactions', tx.toMap());

                if (context.mounted) {
                  Provider.of<AppStateProvider>(context, listen: false)
                      .notifyAllScreens();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Pindahkan Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final unpaidCtrl = TextEditingController();
    String category = 'Makan/Minum';
    bool isSettled = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Catat Pengeluaran / Patungan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Keperluan'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Tag Kategori'),
                  items: [
                    'Makan/Minum',
                    'Bensin/Transport',
                    'Print/Fotokopi',
                    'Patungan/Kas Kelas',
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unpaidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Patungan (Opsional)',
                    hintText: 'Contoh: Azi & Zuhair belum bayar Rp10rb',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sudah Lunas Semua'),
                  value: isSettled,
                  onChanged: (val) => setDialogState(() => isSettled = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (titleCtrl.text.trim().isEmpty || amount <= 0) return;

                final tx = TransactionItem(
                  title: titleCtrl.text.trim(),
                  amount: amount,
                  category: category,
                  date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  unpaidNotes: unpaidCtrl.text.trim(),
                  isSettled: isSettled,
                );
                await DatabaseHelper.instance
                    .insertRow('transactions', tx.toMap());
                if (context.mounted) {
                  Provider.of<AppStateProvider>(context, listen: false)
                      .notifyAllScreens();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Micro-Budgeting & Amplop',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddTransactionDialog(context),
            icon: const Icon(Icons.add_card),
            tooltip: 'Catat Transaksi',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadBudgetData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data as Map<String, dynamic>;
          final BudgetConfig config = data['config'] as BudgetConfig;
          final double remainingBudget = data['remainingBudget'] as double;
          final double safeToday = data['safeToday'] as double;
          final List<EnvelopeItem> envelopes =
              data['envelopes'] as List<EnvelopeItem>;
          final List<TransactionItem> transactions =
              data['transactions'] as List<TransactionItem>;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget ${config.periodName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 20),
                            onPressed: () =>
                                _showConfigureBudgetDialog(context, config),
                          ),
                        ],
                      ),
                      Text(
                        'Sisa Saldo: ${_currencyFmt.format(remainingBudget)}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Jatah Aman Hari Ini: ${_currencyFmt.format(safeToday)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            _showSweepDialog(context, safeToday, envelopes),
                        icon: const Icon(Icons.savings),
                        label: const Text('Tutup Buku Harian (Sweep Sisa)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amplop Target (Sinking Funds)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddEnvelopeDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Amplop'),
                  ),
                ],
              ),
              ...envelopes.map(
                (env) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              env.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(env.progress * 100).toInt()}%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: env.progress,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currencyFmt.format(env.currentAmount)} / ${_currencyFmt.format(env.targetAmount)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log Pengeluaran & Catatan Patungan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...transactions.map(
                (tx) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      tx.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tx.category} • ${tx.date}'),
                        if (tx.unpaidNotes.isNotEmpty)
                          Text(
                            tx.isSettled
                                ? 'Lunas: ${tx.unpaidNotes}'
                                : 'Belum Lunas: ${tx.unpaidNotes}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: tx.isSettled ? Colors.green : Colors.red,
                            ),
                          ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFmt.format(tx.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!tx.isSettled)
                          InkWell(
                            onTap: () async {
                              await DatabaseHelper.instance.updateRow(
                                'transactions',
                                {'is_settled': 1},
                                'id = ?',
                                [tx.id],
                              );
                              if (context.mounted) {
                                Provider.of<AppStateProvider>(context,
                                        listen: false)
                                    .notifyAllScreens();
                              }
                            },
                            child: const Text(
                              'Tandai Lunas',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
