import 'package:flutter/material.dart';

class CycleAssignmentButton extends StatelessWidget {
  final bool assigned;
  final bool busy;
  final VoidCallback onAssign;
  const CycleAssignmentButton({
    super.key,
    required this.assigned,
    required this.onAssign,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: assigned || busy ? null : onAssign,
    icon: Icon(
      assigned ? Icons.check_circle_outline : Icons.add_task_rounded,
      size: 18,
    ),
    label: Text(assigned ? 'Cycle Assigned' : 'Assign to Cycle'),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF1A5C30),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFE4ECE6),
      disabledForegroundColor: const Color(0xFF536257),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}
