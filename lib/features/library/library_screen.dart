import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedCategory = 'All';
  String _search = '';

  static const _articles = [
    _Article('Optimizing HRV for Longevity', 'Understanding heart rate variability as a recovery metric and how to systematically improve it through sleep, stress management, and training load.', 'Recovery', '8 min', Icons.favorite),
    _Article('VO2 Max: The Ultimate Fitness Biomarker', 'Why cardiorespiratory fitness is the strongest predictor of all-cause mortality and evidence-based protocols to increase it at any age.', 'Fitness', '12 min', Icons.directions_run),
    _Article('CAC Score Zero: What It Really Means', 'A zero coronary artery calcium score is excellent news — but doesn\'t mean you\'re immune. Understanding plaque types and ongoing prevention.', 'Heart Health', '10 min', Icons.health_and_safety),
    _Article('Protein Optimization for Muscle Retention', 'The science of protein timing, distribution, leucine thresholds, and the 1.6–2.2g/kg bodyweight recommendation explained.', 'Nutrition', '9 min', Icons.restaurant),
    _Article('Zone 2 Training: The Foundation of Aerobic Fitness', 'Why Peter Attia, Inigo San Millan, and elite athletes spend 70–80% of training in low-intensity aerobic zones.', 'Fitness', '11 min', Icons.directions_bike),
    _Article('Sleep Architecture and Longevity', 'Deep sleep clears amyloid plaques, REM consolidates memory, and light sleep organizes information. How to maximize each stage.', 'Sleep', '10 min', Icons.bedtime),
    _Article('NAD+ Decline and Mitochondrial Health', 'The role of NAD+ in cellular energy, DNA repair, and aging. Evidence for NMN, NR, and lifestyle interventions.', 'Supplements', '13 min', Icons.science),
    _Article('DEXA Scanning: Reading Your Results', 'How to interpret T-scores, Z-scores, visceral fat area, and lean mass index from your DEXA scan report.', 'Body Comp', '7 min', Icons.accessibility_new),
    _Article('Insulin Sensitivity and Metabolic Health', 'HOMA-IR, fasting insulin, CGM patterns, and the lifestyle interventions that matter most for glucose control.', 'Metabolic', '9 min', Icons.biotech),
    _Article('Strength Training After 40', 'Muscle loss accelerates at 1% per year after 40. Progressive overload, eccentric training, and recovery strategies to halt it.', 'Fitness', '8 min', Icons.fitness_center),
    _Article('Peptides: BPC-157, TB-500, and Beyond', 'A science-based overview of research peptides: what the evidence shows, what remains unknown, and safety considerations.', 'Supplements', '15 min', Icons.science),
    _Article('Interpreting Your Blood Panel', 'Beyond normal ranges — understanding optimal values for CRP, homocysteine, ferritin, SHBG, and other key markers.', 'Labs', '11 min', Icons.biotech),
  ];

  static const _categories = ['All', 'Fitness', 'Nutrition', 'Sleep', 'Heart Health', 'Supplements', 'Body Comp', 'Labs', 'Recovery', 'Metabolic'];

  @override
  Widget build(BuildContext context) {
    final filtered = _articles.where((a) {
      final matchesCategory = _selectedCategory == 'All' || a.category == _selectedCategory;
      final matchesSearch = _search.isEmpty || a.title.toLowerCase().contains(_search.toLowerCase()) || a.summary.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Health Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search articles...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary)),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => FilterChip(
                label: Text(_categories[i]),
                selected: _selectedCategory == _categories[i],
                onSelected: (v) => setState(() => _selectedCategory = _categories[i]),
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ArticleCard(article: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Article {
  final String title;
  final String summary;
  final String category;
  final String readTime;
  final IconData icon;
  const _Article(this.title, this.summary, this.category, this.readTime, this.icon);
}

class _ArticleCard extends StatelessWidget {
  final _Article article;
  const _ArticleCard({required this.article});

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Fitness': return AppTheme.accent;
      case 'Nutrition': return AppTheme.warning;
      case 'Sleep': return AppTheme.secondary;
      case 'Heart Health': return AppTheme.danger;
      case 'Supplements': return Color(0xFF14B8A6);
      case 'Body Comp': return AppTheme.secondary;
      case 'Labs': return AppTheme.primary;
      case 'Recovery': return AppTheme.danger;
      case 'Metabolic': return AppTheme.warning;
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(article.category);
    return HvCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(article.icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              StatusBadge(label: article.category, color: color),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 4),
              Text(article.readTime, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(article.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15, height: 1.3)),
          const SizedBox(height: 6),
          Text(article.summary, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.1),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Read', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_outline, color: AppTheme.textSecondary, size: 18),
                onPressed: () {},
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
