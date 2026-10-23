import 'package:visaia/services/firestore_safe_ext.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String formatCycleName({required String crop, required String variety,
    required bool isPrevious, required int number}) =>
    '$crop ($variety) - ${isPrevious ? 'Prev' : 'New'} Cycle $number';

int nextCycleNumber(Iterable<Map<String, dynamic>> cycles, {required bool isPrevious}) {
  var count = 0;
  var highest = 0;
  final suffix = RegExp(r' - (New|Prev) Cycle ([0-9]+)$');
  for (final cycle in cycles) {
    final name = (cycle['cycleName'] ?? '').toString();
    final match = suffix.firstMatch(name);
    final previous = cycle['isPreviousCycle'] == true ||
        match?.group(1) == 'Prev' || name.startsWith('Prev. Cycle |');
    if (previous != isPrevious) continue;
    count++;
    final number = int.tryParse(match?.group(2) ?? '') ?? 0;
    if (number > highest) highest = number;
  }
  return (highest > count ? highest : count) + 1;
}

class CycleNamingService {
  Future<int> nextNumber({required String userId, required String farmId,
      required bool isPrevious}) async {
    final cycles = await FirebaseFirestore.instance.collection('users')
        .doc(userId).collection('cycles').where('farmId', isEqualTo: farmId).safeGet();
    return nextCycleNumber(cycles.docs.map((doc) => doc.data()), isPrevious: isPrevious);
  }
}
