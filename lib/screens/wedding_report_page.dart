import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import 'wedding_theme.dart';

class WeddingReportPage extends StatelessWidget {
  const WeddingReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: weddingBg,
      appBar: AppBar(
        backgroundColor: weddingBg,
        elevation: 0,
        title: const Text(
          'AI Wedding Report',
          style: TextStyle(
            color: weddingOnSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: weddingOnSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.streamWeddingGuests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: weddingAccent,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load report right now.',
                style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
              ),
            );
          }

          final guests = snapshot.data ?? [];
          if (guests.isEmpty) {
            return const _EmptyState();
          }

          final analytics = _ReportAnalytics.fromGuests(guests);
          final currency = NumberFormat.compactCurrency(
            symbol: '₹',
            decimalDigits: 0,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeroSummary(analytics: analytics, currency: currency),
              const SizedBox(height: 16),
              _MetricsSection(analytics: analytics, currency: currency),
              const SizedBox(height: 16),
              _AIInsightsSection(analytics: analytics),
              const SizedBox(height: 16),
              _TopContributorsSection(
                analytics: analytics,
                currency: currency,
              ),
              const SizedBox(height: 16),
              _RelationBreakdownSection(analytics: analytics),
              const SizedBox(height: 16),
              _PlaceBreakdownSection(
                analytics: analytics,
                currency: currency,
              ),
              const SizedBox(height: 16),
              _GiftTimingSection(analytics: analytics),
            ],
          );
        },
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.analytics, required this.currency});

  final _ReportAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final totalGuests = analytics.totalGuests;
    final invitedShare = totalGuests == 0
        ? 0.0
        : (analytics.invitedCount / totalGuests).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This week at a glance',
            style: TextStyle(
              color: weddingOnSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${analytics.totalGuests} guests tracked',
                      style: const TextStyle(
                        color: weddingAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${analytics.invitedCount} invited · ${analytics.pendingCount} pending',
                      style: const TextStyle(
                        color: weddingOnSurfaceMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF242B39),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: invitedShare,
                        child: Container(
                          decoration: BoxDecoration(
                            color: weddingAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total gifts',
                    style: TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(analytics.totalGiftValue),
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${analytics.giftContributors} contributors',
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.analytics, required this.currency});

  final _ReportAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        label: 'Response rate',
        value: '${analytics.inviteResponseRate.toStringAsFixed(0)}%',
        helper: '${analytics.invitedCount} of ${analytics.totalGuests}',
        icon: Icons.check_circle_outline,
        color: weddingAccent,
      ),
      _Metric(
        label: 'Gift avg.',
        value: currency.format(analytics.averageGiftValue),
        helper: '${analytics.giftContributors} recorded',
        icon: Icons.card_giftcard_outlined,
        color: Colors.pinkAccent,
      ),
      _Metric(
        label: 'Pending reminders',
        value: '${analytics.pendingCount}',
        helper: analytics.pendingCount == 0
            ? 'All guests invited'
            : '${analytics.pendingCount} need invite',
        icon: Icons.notifications_paused_outlined,
        color: Colors.orangeAccent,
      ),
      _Metric(
        label: 'Duplicate risk',
        value: '${analytics.possibleDuplicates.length}',
        helper: analytics.possibleDuplicates.isEmpty
            ? 'No duplicates flagged'
            : 'Review similar names',
        icon: Icons.warning_amber_outlined,
        color: Colors.amberAccent,
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 540 ? 180 : 150;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map((m) => SizedBox(
                width: cardWidth.toDouble(),
                child: _MetricCard(metric: m),
              ))
          .toList(),
    );
  }
}

class _AIInsightsSection extends StatelessWidget {
  const _AIInsightsSection({required this.analytics});

  final _ReportAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final insights = analytics.generateInsights();
    return _SectionCard(
      title: 'AI suggested next steps',
      subtitle:
          'We analysed invites, gifts, and engagement to highlight what deserves attention.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.bolt_outlined,
                        size: 16, color: weddingAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        color: weddingOnSurface,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (insights.isEmpty)
            const Text(
              'Everything looks on track. Keep logging invites and gifts for deeper insights.',
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _TopContributorsSection extends StatelessWidget {
  const _TopContributorsSection({
    required this.analytics,
    required this.currency,
  });

  final _ReportAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final contributors = analytics.topContributors;
    return _SectionCard(
      title: 'Top gift contributors',
      subtitle: contributors.isEmpty
          ? 'No gift entries recorded yet.'
          : 'Celebrate your most generous guests and send a thank-you.',
      child: Column(
        children: [
          for (final contributor in contributors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.pinkAccent.withOpacity(0.15),
                child: Text(
                  contributor.initials,
                  style: const TextStyle(
                    color: Colors.pinkAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                contributor.name.isEmpty ? 'Unknown guest' : contributor.name,
                style: const TextStyle(
                  color: weddingOnSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                contributor.place,
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 11,
                ),
              ),
              trailing: Text(
                currency.format(contributor.amount),
                style: const TextStyle(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelationBreakdownSection extends StatelessWidget {
  const _RelationBreakdownSection({required this.analytics});

  final _ReportAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final segments = analytics.relationSegments;
    return _SectionCard(
      title: 'Relation mix',
      subtitle: 'Understand who you are inviting most and balance outreach.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seg in segments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      seg.label,
                      style: const TextStyle(
                        color: weddingOnSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: seg.percentage / 100,
                        backgroundColor: const Color(0xFF2A3140),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(weddingAccent),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${seg.count} · ${seg.percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: weddingOnSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          if (segments.isEmpty)
            const Text(
              'No relations recorded yet. Add relation tags to guests to unlock this view.',
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _PlaceBreakdownSection extends StatelessWidget {
  const _PlaceBreakdownSection({
    required this.analytics,
    required this.currency,
  });

  final _ReportAnalytics analytics;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final places = analytics.topPlaces;
    return _SectionCard(
      title: 'Place performance',
      subtitle: 'See where invites and gifts are coming from.',
      child: Column(
        children: [
          for (final place in places)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: weddingAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: weddingAccent,
                ),
              ),
              title: Text(
                place.label,
                style: const TextStyle(
                  color: weddingOnSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${place.invitedCount} invited · ${place.pendingCount} pending',
                style: const TextStyle(
                  color: weddingOnSurfaceMuted,
                  fontSize: 11,
                ),
              ),
              trailing: Text(
                currency.format(place.giftValue),
                style: const TextStyle(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (places.isEmpty)
            const Text(
              'Add place information to guests to view geographical trends.',
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _GiftTimingSection extends StatelessWidget {
  const _GiftTimingSection({required this.analytics});

  final _ReportAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final trend = analytics.giftTrend;
    return _SectionCard(
      title: 'Gift logging pace',
      subtitle: trend.isEmpty
          ? 'Log gift dates to see pacing over time.'
          : 'Monitor how quickly gifts are being received.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in trend)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.label,
                      style: const TextStyle(
                        color: weddingOnSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entry.count} gifts',
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          if (trend.isEmpty)
            const Text(
              'Add received dates to gifts to track their pace.',
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D2330),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, size: 16, color: metric.color),
          ),
          const SizedBox(height: 10),
          Text(
            metric.value,
            style: TextStyle(
              color: metric.color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: const TextStyle(
              color: weddingOnSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.helper,
            style: const TextStyle(
              color: weddingOnSurfaceMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: weddingOnSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: weddingOnSurfaceMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
          ]
          else
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.auto_graph_outlined,
              size: 42,
              color: weddingOnSurfaceMuted,
            ),
            SizedBox(height: 14),
            Text(
              'Add wedding guests to see AI-suggested insights. Your report will update instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: weddingOnSurfaceMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
}

class _ReportAnalytics {
  _ReportAnalytics({
    required this.totalGuests,
    required this.invitedCount,
    required this.pendingCount,
    required this.totalGiftValue,
    required this.giftContributors,
    required this.averageGiftValue,
    required this.inviteResponseRate,
    required this.topContributors,
    required this.relationSegments,
    required this.topPlaces,
    required this.giftTrend,
    required this.possibleDuplicates,
  });

  final int totalGuests;
  final int invitedCount;
  final int pendingCount;
  final double totalGiftValue;
  final int giftContributors;
  final double averageGiftValue;
  final double inviteResponseRate;
  final List<_Contributor> topContributors;
  final List<_RelationSegment> relationSegments;
  final List<_PlaceSegment> topPlaces;
  final List<_GiftTrendEntry> giftTrend;
  final List<String> possibleDuplicates;

  static _ReportAnalytics fromGuests(List<Map<String, dynamic>> guests) {
    int invitedCount = 0;
    int pendingCount = 0;
    double giftSum = 0;
    final giftEntries = <Map<String, dynamic>>[];
    final relationCount = <String, int>{};
    final placeStats = <String, _PlaceStats>{};
    final duplicates = <String, List<Map<String, dynamic>>>{};
    final dayBuckets = <String, int>{};

    for (final g in guests) {
      final invited = g['invited'] == true;
      final hasGift = g['hasAmount'] == true;
      final relation = (g['relation'] ?? '').toString().trim();
      final place = (g['place'] ?? '').toString().trim().isEmpty
          ? 'Unknown'
          : (g['place'] ?? '').toString().trim();
      final name = (g['name'] ?? '').toString().trim();
      final normalizedKey = '${name.toLowerCase()}|${place.toLowerCase()}';
      duplicates.putIfAbsent(normalizedKey, () => []).add(g);

      if (invited) {
        invitedCount += 1;
      } else {
        pendingCount += 1;
      }

      if (relation.isNotEmpty) {
        relationCount.update(relation, (value) => value + 1,
            ifAbsent: () => 1);
      }

      final stats = placeStats.putIfAbsent(place, () => _PlaceStats());
      if (invited) stats.invited += 1;
      if (!invited) stats.pending += 1;

      if (hasGift) {
        final amount =
            (g['amount'] is num) ? (g['amount'] as num).toDouble() : 0;
        giftSum += amount;
        stats.giftTotal += amount;
        giftEntries.add(g);

        final receivedRaw = g['receivedAt']?.toString();
        if (receivedRaw != null && receivedRaw.isNotEmpty) {
          final dayKey = receivedRaw.split('T').first;
          dayBuckets.update(dayKey, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }
    }

    final totalGuests = guests.length;
    final contributors = giftEntries
        .where((g) => (g['amount'] ?? 0) is num)
        .map((g) => _Contributor(
              name: (g['name'] ?? '').toString(),
              place: (g['place'] ?? '').toString(),
              amount: (g['amount'] as num).toDouble(),
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final relationSegments = relationCount.entries
        .map((e) => _RelationSegment(
              label: e.key,
              count: e.value,
              percentage: totalGuests == 0
                  ? 0
                  : (e.value / totalGuests * 100).clamp(0, 100),
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final placeSegments = placeStats.entries
        .map((e) => _PlaceSegment(
              label: e.key,
              invitedCount: e.value.invited,
              pendingCount: e.value.pending,
              giftValue: e.value.giftTotal,
            ))
        .toList()
      ..sort((a, b) => b.giftValue.compareTo(a.giftValue));

    final giftTrend = dayBuckets.entries
        .map((e) => _GiftTrendEntry(label: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.label.compareTo(a.label));

    final duplicateNames = duplicates.values
        .where((list) => list.length > 1)
        .map((group) => (group.first['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();

    return _ReportAnalytics(
      totalGuests: totalGuests,
      invitedCount: invitedCount,
      pendingCount: pendingCount,
      totalGiftValue: giftSum,
      giftContributors: contributors.length,
      averageGiftValue: contributors.isEmpty
          ? 0
          : giftSum / contributors.length,
      inviteResponseRate: totalGuests == 0
          ? 0
          : (invitedCount / totalGuests * 100).clamp(0, 100),
      topContributors: contributors.take(5).toList(),
      relationSegments: relationSegments.take(5).toList(),
      topPlaces: placeSegments.take(6).toList(),
      giftTrend: giftTrend.take(7).toList(),
      possibleDuplicates: duplicateNames,
    );
  }

  List<String> generateInsights() {
    final insights = <String>[];
    if (pendingCount > 0) {
      final pct = totalGuests == 0
          ? 0
          : (pendingCount / totalGuests * 100).toStringAsFixed(0);
      insights.add(
        'You still have $pendingCount guests pending invitations ($pct% of your list). Consider scheduling a follow-up call this week.',
      );
    } else {
      insights.add(
        'Nice work! Every tracked guest has been invited. Capture RSVP status next to stay organised.',
      );
    }

    if (giftContributors == 0) {
      insights.add(
        'No gifts recorded yet. Log gift amounts when they arrive so you can plan return favours.',
      );
    } else {
      final avg = averageGiftValue.toStringAsFixed(0);
      insights.add(
        'Average gift value is ₹$avg. Highlight high-value guests for personalised thank-you notes.',
      );
    }

    if (topContributors.isNotEmpty) {
      final top = topContributors.first;
      final name = top.name.isEmpty ? 'A guest' : top.name;
      insights.add(
        '$name has contributed the most so far. Send a personal appreciation message.',
      );
    }

    if (possibleDuplicates.isNotEmpty) {
      insights.add(
        'Found ${possibleDuplicates.length} possible duplicates. Merge them to avoid double reminders.',
      );
    }

    if (giftTrend.length >= 3) {
      final latest = giftTrend.first.count;
      final previous = giftTrend.skip(1).first.count;
      if (latest < previous) {
        insights.add(
          'Gift logging slowed down compared to earlier periods. Encourage guests to share confirmations.',
        );
      } else if (latest > previous) {
        insights.add(
          'Gift logging is accelerating. Keep momentum by acknowledging recent contributors.',
        );
      }
    }

    if (relationSegments.isNotEmpty) {
      final topRelation = relationSegments.first;
      if (topRelation.percentage > 60) {
        insights.add(
          'Most of your list (${topRelation.percentage.toStringAsFixed(0)}%) is ${topRelation.label}. Diversify outreach to other relation groups.',
        );
      }
    }

    return insights;
  }
}

class _Contributor {
  _Contributor({
    required this.name,
    required this.place,
    required this.amount,
  });

  final String name;
  final String place;
  final double amount;

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _RelationSegment {
  _RelationSegment({
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String label;
  final int count;
  final double percentage;
}

class _PlaceSegment {
  _PlaceSegment({
    required this.label,
    required this.invitedCount,
    required this.pendingCount,
    required this.giftValue,
  });

  final String label;
  final int invitedCount;
  final int pendingCount;
  final double giftValue;
}

class _GiftTrendEntry {
  _GiftTrendEntry({required this.label, required this.count});

  final String label;
  final int count;
}

class _PlaceStats {
  int invited = 0;
  int pending = 0;
  double giftTotal = 0;
}
