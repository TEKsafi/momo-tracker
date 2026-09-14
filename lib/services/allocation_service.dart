import '../models/transaction.dart';
import 'local_store.dart';

/// MoMo only tracks ONE pooled balance on the SIM/account. This service
/// implements "virtual envelopes" on top of it: money coming in gets
/// assigned (allocated) to a budget, and each budget's spendable amount is
/// its allocations minus its own expenses — even though the real MoMo
/// balance is a single number. This is the "unmix" the user asked for:
/// it's rule-based bookkeeping, not something that changes the real account.
class AllocationService {
  /// How much of the pooled balance is assigned to [budgetId] right now.
  static double envelopeBalance(List<Allocation> allocations, List<Transaction> transactions, String budgetId) {
    final allocated = allocations.where((a) => a.budgetId == budgetId).fold<double>(0, (s, a) => s + a.amount);
    final spent = transactions
        .where((t) => t.budgetId == budgetId && t.type == TxType.expense)
        .fold<double>(0, (s, t) => s + t.amount);
    final received = transactions
        .where((t) => t.budgetId == budgetId && t.type == TxType.income)
        .fold<double>(0, (s, t) => s + t.amount);
    return allocated + received - spent;
  }

  /// Total across all envelopes — should reconcile with the real MoMo
  /// balance if every incoming transaction has been allocated somewhere.
  static double totalAllocated(List<Allocation> allocations) => allocations.fold<double>(0, (s, a) => s + a.amount);

  /// Money that has come in via SMS but hasn't been assigned to any budget
  /// yet — i.e. still "mixed" and needs a decision from the user.
  static double unallocated(List<Transaction> allTransactions, List<Allocation> allocations, double realMomoBalance) {
    return realMomoBalance - totalAllocated(allocations);
  }

  static Future<void> allocate({required String budgetId, required double amount, String note = ''}) async {
    final allocations = await LocalStore.getAllocations();
    allocations.add(Allocation(id: LocalStore.uuid.v4(), budgetId: budgetId, amount: amount, date: DateTime.now(), note: note));
    await LocalStore.saveAllocations(allocations);
  }
}
