import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:visaia/services/notification_content.dart';
import 'package:intl/intl.dart';
import 'package:visaia/screens/dashboard_screens/threat_details.dart';
import 'package:visaia/screens/report_history/report_details.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/notification_feed_service.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  static const green = Color(0xFF0D4D33);
  String _filter = 'All', _search = '';
  bool _marking = false;
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      AuthCacheService().cachedUid ??
      '';

  Future<void> _markRead(List<InboxNotification> items) async {
    setState(() => _marking = true);
    try {
      await NotificationFeedService.markRead(_uid, items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not mark notifications as read. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _open(InboxNotification item) async {
    await _markRead([item]);
    if (!mounted) return;
    if (!item.isReport && item.alertId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreatDetailsScreen(alertId: item.alertId!),
        ),
      );
      return;
    }
    try {
      final types = item.reportType.isEmpty
          ? ['regular', 'clustered']
          : [item.reportType];
      for (final type in types) {
        final snapshot = await FirebaseFirestore.instance
            .collection(type == 'clustered' ? 'clustered_reports' : 'reports')
            .doc(item.reportId)
            .get();
        if (!mounted) return;
        if (snapshot.exists) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(
                reportId: item.reportId,
                reportData: {...snapshot.data()!, 'reportType': type},
                reportType: type,
              ),
            ),
          );
          return;
        }
      }
      throw StateError('Report unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This report is unavailable. Please try again later.',
            ),
          ),
        );
      }
    }
  }

  String _group(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = date.toLocal();
    if (!local.isBefore(today)) return 'Today';
    if (!local.isBefore(DateTime(now.year, now.month, now.day - 1))) {
      return 'Yesterday';
    }
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F8F5),
    appBar: AppBar(
      title: const Text('Notifications'),
      foregroundColor: green,
      backgroundColor: const Color(0xFFF6F8F5),
    ),
    body: _uid.isEmpty
        ? const Center(child: Text('Please log in to view notifications.'))
        : StreamBuilder<List<InboxNotification>>(
            stream: NotificationFeedService.watch(_uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load notifications. Check your connection and reopen this page.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              final unread = items.where((n) => n.unread).length;
              final filtered = items
                  .where(
                    (n) =>
                        (_filter != 'Unread' || n.unread) &&
                        (_filter != 'Report Updates' || n.isReport) &&
                        (_filter != 'Alerts & Advisories' || !n.isReport) &&
                        '${n.title} ${n.message} ${n.reportId}'
                            .toLowerCase()
                            .contains(_search),
                  )
                  .toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            unread == 0
                                ? "You're all caught up"
                                : '$unread unread',
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: unread == 0 || _marking
                              ? null
                              : () => _markRead(items),
                          child: Text(
                            _marking ? 'Saving...' : 'Mark all as read',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _search = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search notifications',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children:
                          [
                                'All',
                                'Unread',
                                'Report Updates',
                                'Alerts & Advisories',
                              ]
                              .map(
                                (label) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(label),
                                    selected: _filter == label,
                                    onSelected: (_) =>
                                        setState(() => _filter = label),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                items.isEmpty
                                    ? 'No notifications yet. Report updates and farm alerts will appear here.'
                                    : 'No matching notifications.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final n = filtered[index];
                              final group = _group(n.createdAt);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (index == 0 ||
                                      group !=
                                          _group(filtered[index - 1].createdAt))
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        16,
                                        4,
                                        8,
                                      ),
                                      child: Text(
                                        group,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  _row(n),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
  );

  Widget _row(InboxNotification n) {
    final color = n.status == 'rejected'
        ? const Color(0xFFB42318)
        : n.status == 'validated' || n.status == 'resolved'
        ? green
        : const Color(0xFF956000);
    final icon = n.status == 'rejected'
        ? Icons.cancel_outlined
        : n.status == 'validated'
        ? Icons.verified_outlined
        : n.status == 'resolved'
        ? Icons.task_alt
        : n.isReport
        ? Icons.description_outlined
        : Icons.notifications_outlined;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: n.unread ? Colors.white : const Color(0xFFF6F8F5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(n),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.09),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!n.isReport) ...[
                        Text(
                          NotificationContent(n.data).label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: n.unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (n.message.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          n.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        n.createdAt == null
                            ? 'Date unavailable'
                            : DateFormat(
                                'MMM d, h:mm a',
                              ).format(n.createdAt!.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (n.unread)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 5),
                    child: Icon(Icons.circle, color: green, size: 8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
