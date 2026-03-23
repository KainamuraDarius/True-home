import 'package:flutter/material.dart';

class ChoosePlanScreen extends StatefulWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSkip;
  final Function(String plan, String period, int price) onPlanSelected;

  const ChoosePlanScreen({
    super.key,
    this.onCancel,
    this.onSkip,
    required this.onPlanSelected,
  });

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  static const int _agentMonthlyPrice = 150000;
  static const int _enterpriseMonthlyPrice = 250000;
  static const double _annualDiscount = 0.20;

  static const List<_PlanConfig> _plans = [
    _PlanConfig(
      id: 'free',
      title: 'Starter',
      subtitle: 'Submit without paid promotion',
      icon: Icons.explore_outlined,
      badge: 'No Cost',
      monthlyPrice: 0,
      features: [
        'Complete listing submission',
        'Pay later when ready to scale',
        'No subscription required',
      ],
    ),
    _PlanConfig(
      id: 'agent',
      title: 'Agent',
      subtitle: 'Best for individual professionals',
      icon: Icons.workspace_premium_outlined,
      badge: 'Most Chosen',
      monthlyPrice: _agentMonthlyPrice,
      features: [
        'Up to 50 live properties',
        'Verified agent badge visibility',
        'Faster listing review priority',
      ],
    ),
    _PlanConfig(
      id: 'enterprise',
      title: 'Enterprise',
      subtitle: 'For agencies and growing teams',
      icon: Icons.apartment_outlined,
      badge: 'Scale',
      monthlyPrice: _enterpriseMonthlyPrice,
      features: [
        'Up to 100 live properties',
        'Multi-agent account support',
        'Company branded presence',
      ],
    ),
  ];

  String _selectedPeriod = 'monthly';
  String _selectedPlan = 'agent';

  _PlanConfig get _selectedConfig {
    return _plans.firstWhere(
      (plan) => plan.id == _selectedPlan,
      orElse: () => _plans[1],
    );
  }

  int get _selectedPrice => _priceFor(_selectedConfig);

  int _priceFor(_PlanConfig plan) {
    if (plan.monthlyPrice == 0) return 0;
    if (_selectedPeriod == 'annual') {
      return (plan.monthlyPrice * 12 * (1 - _annualDiscount)).round();
    }
    return plan.monthlyPrice;
  }

  int _annualSavingsFor(_PlanConfig plan) {
    if (plan.monthlyPrice == 0) return 0;
    final fullYear = plan.monthlyPrice * 12;
    final discounted = (fullYear * (1 - _annualDiscount)).round();
    return fullYear - discounted;
  }

  String _formatCurrency(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  void _handlePrimaryAction() {
    if (_selectedPlan == 'free') {
      if (widget.onSkip != null) {
        widget.onSkip!.call();
      } else if (widget.onCancel != null) {
        widget.onCancel!.call();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    widget.onPlanSelected(_selectedPlan, _selectedPeriod, _selectedPrice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: Stack(
        children: [
          _buildBackgroundDecor(colorScheme),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(theme),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                        children: [
                          _buildHeroSection(colorScheme),
                          const SizedBox(height: 16),
                          _buildBillingToggle(theme),
                          const SizedBox(height: 16),
                          _buildPlansLayout(),
                          const SizedBox(height: 16),
                          _buildComparisonPanel(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomDock(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF7FAFF),
                  colorScheme.primary.withValues(alpha: 0.04),
                  const Color(0xFFF3F6FD),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: 90,
          left: -100,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0BAA8C).withValues(alpha: 0.09),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
          Expanded(
            child: Text(
              'Choose Visibility Plan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.98),
            const Color(0xFF173A7A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'List smarter, convert faster',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick a plan that matches your listing goals. You can still continue without a paid plan and upgrade later.',
            style: TextStyle(color: Color(0xFFE5EDFF), height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroPill(icon: Icons.security_rounded, label: 'Secure checkout'),
              _HeroPill(icon: Icons.flash_on_rounded, label: 'Faster review queue'),
              _HeroPill(icon: Icons.stars_rounded, label: 'Higher visibility'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final savings = _annualSavingsFor(_selectedConfig);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PeriodButton(
                  label: 'Monthly',
                  selected: _selectedPeriod == 'monthly',
                  onTap: () => setState(() => _selectedPeriod = 'monthly'),
                ),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _PeriodButton(
                      label: 'Yearly',
                      selected: _selectedPeriod == 'annual',
                      onTap: () => setState(() => _selectedPeriod = 'annual'),
                    ),
                    Positioned(
                      top: -9,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0BAA8C),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Save 20%',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedPeriod == 'annual' && savings > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Text(
                'You save UGX ${_formatCurrency(savings)} per year on ${_selectedConfig.title}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF0A8F77),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlansLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useGrid = constraints.maxWidth >= 860;

        if (useGrid) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _plans.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _plans.length - 1 ? 0 : 12),
                    child: _buildPlanCard(_plans[i]),
                  ),
                ),
            ],
          );
        }

        return Column(
          children: [
            for (int i = 0; i < _plans.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == _plans.length - 1 ? 0 : 12),
                child: _buildPlanCard(_plans[i]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(_PlanConfig plan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool selected = _selectedPlan == plan.id;
    final bool isFree = plan.monthlyPrice == 0;
    final bool isRecommended = plan.id == 'agent';

    final int currentPrice = _selectedPeriod == 'annual' && !isFree
        ? (plan.monthlyPrice * 12 * (1 - _annualDiscount)).round()
        : plan.monthlyPrice;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.0 : 0.985,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(() => _selectedPlan = plan.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : isRecommended
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.08),
                width: selected ? 2.1 : 1.2,
              ),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.14),
                        Colors.white,
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: selected ? 22 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        plan.icon,
                        color: selected ? Colors.white : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isRecommended
                            ? const Color(0xFF0BAA8C).withValues(alpha: 0.14)
                            : colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        plan.badge,
                        style: TextStyle(
                          color: isRecommended
                              ? const Color(0xFF067A66)
                              : colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'UGX 0' : 'UGX ${_formatCurrency(currentPrice)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    if (!isFree)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 4),
                        child: Text(
                          '/ ${_selectedPeriod == 'monthly' ? 'month' : 'year'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_selectedPeriod == 'annual' && !isFree)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Billed yearly • Save UGX ${_formatCurrency(_annualSavingsFor(plan))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF0A8F77),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                ...plan.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.primary.withValues(alpha: 0.80),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Plan Comparison',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Everything you need to choose confidently.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _buildComparisonRow('Live listings', 'Basic', 'Up to 50', 'Up to 100'),
          _buildComparisonRow('Verification badge', 'No', 'Yes', 'Yes'),
          _buildComparisonRow('Team access', 'No', 'No', 'Yes'),
          _buildComparisonRow('Priority support', 'No', 'Standard', 'Priority'),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String feature,
    String starter,
    String agent,
    String enterprise,
  ) {
    final theme = Theme.of(context);

    Widget valueCell(String value, {bool emphasize = false}) {
      return Expanded(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: emphasize ? theme.colorScheme.primary : Colors.black87,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          valueCell(starter),
          valueCell(agent, emphasize: true),
          valueCell(enterprise),
        ],
      ),
    );
  }

  Widget _buildBottomDock(ThemeData theme) {
    final bool isFree = _selectedPlan == 'free';
    final String cadence = _selectedPeriod == 'monthly' ? 'month' : 'year';

    final String actionLabel = isFree
        ? 'Continue Without Paid Plan'
        : 'Pay UGX ${_formatCurrency(_selectedPrice)} / $cadence';

    final String summaryText = isFree
        ? 'Starter selected. Submit now and upgrade later from My Properties.'
        : '${_selectedConfig.title} selected • ${_selectedPeriod == 'monthly' ? 'Monthly billing' : 'Yearly billing'}';

    return Material(
      elevation: 20,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 700;

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          summaryText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _handlePrimaryAction,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            child: Text(actionLabel),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          summaryText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: _handlePrimaryAction,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        child: Text(actionLabel),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.82),
                  ],
                )
              : null,
          color: selected ? null : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanConfig {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final int monthlyPrice;
  final List<String> features;

  const _PlanConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.monthlyPrice,
    required this.features,
  });
}
