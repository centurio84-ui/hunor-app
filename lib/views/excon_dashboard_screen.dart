import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/excon_category_summary.dart';
import '../services/excon_repository.dart';
import '../theme/hunor_theme.dart';

class ExconDashboardScreen extends StatefulWidget {
  const ExconDashboardScreen({super.key});

  @override
  State<ExconDashboardScreen> createState() => _ExconDashboardScreenState();
}

class _ExconDashboardScreenState extends State<ExconDashboardScreen> {
  final _repository = ExconRepository();
  bool _isLoading = true;
  String? _errorMessage;
  List<ExconCategorySummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.fetchCategorySummaries();
      if (!mounted) return;
      setState(() {
        _summaries = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Ha a hálózat nem elérhető, fallback bemutató adatok az azonnali használhatóságért
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        if (_summaries.isEmpty) {
          _summaries = _getSampleData();
        }
      });
    }
  }

  List<ExconCategorySummary> _getSampleData() {
    return const [
      ExconCategorySummary(
        categoryCode: 'OP-K9',
        evaluationCount: 12,
        maxPossibleScore: 24,
        totalAchievedScore: 22,
        performancePercentage: 91.6,
      ),
      ExconCategorySummary(
        categoryCode: 'CUT',
        evaluationCount: 8,
        maxPossibleScore: 16,
        totalAchievedScore: 13,
        performancePercentage: 81.2,
      ),
      ExconCategorySummary(
        categoryCode: 'SHOR',
        evaluationCount: 10,
        maxPossibleScore: 20,
        totalAchievedScore: 15,
        performancePercentage: 75.0,
      ),
      ExconCategorySummary(
        categoryCode: 'BREAK',
        evaluationCount: 9,
        maxPossibleScore: 18,
        totalAchievedScore: 12,
        performancePercentage: 66.7,
      ),
      ExconCategorySummary(
        categoryCode: 'ALPIN',
        evaluationCount: 6,
        maxPossibleScore: 12,
        totalAchievedScore: 7,
        performancePercentage: 58.3,
      ),
    ];
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return HunorColors.success;
    if (percentage >= 60) return HunorColors.warning;
    return HunorColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final totalEvaluations = _summaries.fold<int>(0, (sum, item) => sum + item.evaluationCount);
    final totalAchieved = _summaries.fold<int>(0, (sum, item) => sum + item.totalAchievedScore);
    final totalMax = _summaries.fold<int>(0, (sum, item) => sum + item.maxPossibleScore);
    final overallAverage = totalMax > 0 ? (totalAchieved / totalMax * 100) : 0.0;
    final bestCategory = _summaries.isNotEmpty ? _summaries.first : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: HunorColors.graphite,
      appBar: AppBar(
        title: const Text('Vezetői Műszerfal'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Frissítés',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: HunorColors.red),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: HunorColors.red,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: HunorColors.warning.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HunorColors.warning),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: HunorColors.warning, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Élő adat nem elérhető (mintaadatok megjelenítve): $_errorMessage',
                                    style: const TextStyle(fontSize: 12, color: HunorColors.text),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Címsor és jelmagyarázat
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'EXCON ÉRTÉKELÉSI KPI-K',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: HunorColors.muted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: HunorColors.redDark,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ÉLŐ ELEMZÉS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 1. Reszponzív KPI kártyák: széles képernyőn és mobilon is Row (Expanded elemekkel)
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Összes Értékelés',
                                value: '$totalEvaluations',
                                subtitle: 'rögzített adat',
                                icon: Icons.checklist_rounded,
                                accentColor: HunorColors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Átlag Teljesítmény',
                                value: '${overallAverage.toStringAsFixed(1)}%',
                                subtitle: '$totalAchieved / $totalMax pont',
                                icon: Icons.speed_rounded,
                                accentColor: _getScoreColor(overallAverage),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Legjobb Terület',
                                value: bestCategory?.categoryCode ?? 'N/A',
                                subtitle: bestCategory != null
                                    ? '${bestCategory.performancePercentage.toStringAsFixed(0)}% (${bestCategory.displayName})'
                                    : 'Nincs adat',
                                icon: Icons.military_tech_rounded,
                                accentColor: HunorColors.success,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 2. BarChart szekció kordában tartott asztali magassággal (max 320px)
                        Card(
                          color: HunorColors.surface1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Kategóriánkénti Megfelelési Arány (%)',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: HunorColors.surface2,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Max: 100%', style: TextStyle(fontSize: 11, color: HunorColors.muted)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: isDesktop ? 300 : 240,
                                  child: _buildBarChart(),
                                ),
                                const SizedBox(height: 12),
                                // Jelmagyarázat
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegendItem('≥ 80% Kiváló', HunorColors.success),
                                    const SizedBox(width: 16),
                                    _buildLegendItem('60-79% Megfelelő', HunorColors.warning),
                                    const SizedBox(width: 16),
                                    _buildLegendItem('< 60% Kritikus', HunorColors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 3. Részletes kategória lista (asztali nézetben 2 oszlopos grid vagy lista)
                        const Text(
                          'RÉSZLETES KATEGÓRIA BONTÁS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: HunorColors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (isDesktop)
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: _summaries.map((cat) {
                              return SizedBox(
                                width: (1200 - 48 - 12) / 2 > 350 ? 550 : double.infinity,
                                child: _buildCategoryCard(cat),
                              );
                            }).toList(),
                          )
                        else
                          ..._summaries.map((cat) => _buildCategoryCard(cat)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryCard(ExconCategorySummary cat) {
    return Card(
      color: HunorColors.surface1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getScoreColor(cat.performancePercentage).withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _getScoreColor(cat.performancePercentage)),
          ),
          child: Center(
            child: Text(
              cat.categoryCode,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: _getScoreColor(cat.performancePercentage),
              ),
            ),
          ),
        ),
        title: Text(
          cat.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          '${cat.evaluationCount} ellenőrzés • Elért: ${cat.totalAchievedScore}/${cat.maxPossibleScore} pont',
          style: const TextStyle(color: HunorColors.muted, fontSize: 12),
        ),
        trailing: Text(
          '${cat.performancePercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: _getScoreColor(cat.performancePercentage),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: HunorColors.muted)),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HunorColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: HunorColors.muted),
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: HunorColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_summaries.isEmpty) {
      return const Center(child: Text('Nincs megjeleníthető adat', style: TextStyle(color: HunorColors.muted)));
    }

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < _summaries.length; i++) {
      final item = _summaries[i];
      final color = _getScoreColor(item.performancePercentage);

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: item.performancePercentage,
              color: color,
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: HunorColors.surface2,
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final cat = _summaries[group.x.toInt()];
              return BarTooltipItem(
                '${cat.displayName}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                children: [
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(1)}% (${cat.totalAchievedScore}/${cat.maxPossibleScore}p)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(color: HunorColors.muted, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _summaries.length) return const SizedBox.shrink();
                final code = _summaries[idx].categoryCode;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: HunorColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: HunorColors.border.withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }
}
