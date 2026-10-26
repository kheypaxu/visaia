import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportDetailSection {
  final String label;
  final List<Widget> children;
  const ReportDetailSection(this.label, this.children);
}

/// One scroll view keeps the report header and section navigation together.
class ReportDetailTabs extends StatefulWidget {
  final Widget header;
  final double expandedHeight;
  final List<ReportDetailSection> sections;
  const ReportDetailTabs({
    super.key,
    required this.header,
    required this.expandedHeight,
    required this.sections,
  });

  @override
  State<ReportDetailTabs> createState() => _ReportDetailTabsState();
}

class _ReportDetailTabsState extends State<ReportDetailTabs> {
  final _scrollController = ScrollController();
  int _selected = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _selected) return;
    // Start the new section at its top without expanding a collapsed photo header.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        math.min(
          _scrollController.offset,
          math.max(0, widget.expandedHeight - kToolbarHeight),
        ),
      );
    }
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      56.0,
      32 + MediaQuery.textScalerOf(context).scale(18),
    );
    final tabs = TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      onTap: _select,
      padding: const EdgeInsets.all(8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: const Color(0xFF1B3015),
        borderRadius: BorderRadius.circular(12),
      ),
      dividerColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: const Color(0xFF1B3015),
      labelStyle: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      tabs: [
        for (final section in widget.sections)
          Tab(height: height - 16, text: section.label),
      ],
    );
    final children = widget.sections[_selected].children;
    return DefaultTabController(
      length: widget.sections.length,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          widget.header,
          SliverPersistentHeader(
            pinned: true,
            delegate: _ReportTabsHeader(tabs, height),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.separated(
              key: ValueKey(widget.sections[_selected].label),
              itemCount: children.length,
              itemBuilder: (_, index) => children[index],
              separatorBuilder: (_, index) => const SizedBox(height: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTabsHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabs;
  final double height;
  _ReportTabsHeader(this.tabs, this.height);
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: const Color(0xFFF8F5EF),
    elevation: overlapsContent ? 2 : 0,
    child: tabs,
  );
  @override
  bool shouldRebuild(covariant _ReportTabsHeader oldDelegate) =>
      oldDelegate.tabs != tabs || oldDelegate.height != height;
}
