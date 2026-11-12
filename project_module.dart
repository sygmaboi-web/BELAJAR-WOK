class BudgetConfig {
  final int id;
  final String periodName; // 'Mingguan' atau 'Bulanan'
  final double totalBudget;
  final String startDate; // Format: yyyy-MM-dd
  final String endDate; // Format: yyyy-MM-dd

  BudgetConfig({
    this.id = 1,
    required this.periodName,
    required this.totalBudget,
    required this.startDate,
    required this.endDate,
  });

  factory BudgetConfig.fromMap(Map<String, dynamic> map) {
    return BudgetConfig(
      id: map['id'] as int,
      periodName: map['period_name'] as String,
      totalBudget: (map['total_budget'] as num).toDouble(),
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'period_name': periodName,
      'total_budget': totalBudget,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

class EnvelopeItem {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String iconName;

  EnvelopeItem({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.iconName,
  });

  double get progress {
    if (targetAmount <= 0) return 0.0;
    final ratio = currentAmount / targetAmount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  factory EnvelopeItem.fromMap(Map<String, dynamic> map) {
    return EnvelopeItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      iconName: map['icon_name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'icon_name': iconName,
    };
  }
}

class TransactionItem {
  final int? id;
  final String title;
  final double amount;
  final String category; // 'Makan/Minum', 'Bensin/Transport', 'Print/Fotokopi', 'Patungan/Kas Kelas', 'Sweep Tabungan'
  final String date; // Format: yyyy-MM-dd HH:mm
  final String unpaidNotes;
  final bool isSettled;

  TransactionItem({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.unpaidNotes = '',
    this.isSettled = true,
  });

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: map['date'] as String,
      unpaidNotes: map['unpaid_notes'] as String,
      isSettled: (map['is_settled'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date,
      'unpaid_notes': unpaidNotes,
      'is_settled': isSettled ? 1 : 0,
    };
  }
}
