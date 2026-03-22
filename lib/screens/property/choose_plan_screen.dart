import 'package:flutter/material.dart';

class ChoosePlanScreen extends StatefulWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onSkip;
  final Function(String plan, String period, int price) onPlanSelected;

  const ChoosePlanScreen({
    Key? key,
    this.onCancel,
    this.onSkip,
    required this.onPlanSelected,
  }) : super(key: key);

  @override
  State<ChoosePlanScreen> createState() => _ChoosePlanScreenState();
}

class _ChoosePlanScreenState extends State<ChoosePlanScreen> {
  String _selectedPeriod = 'monthly';
  String _selectedPlan = 'agent';

  int get _selectedPrice {
    if (_selectedPlan == 'agent') {
      return _selectedPeriod == 'monthly' ? 150000 : 150000 * 12 * 0.8 ~/ 1;
    } else if (_selectedPlan == 'enterprise') {
      return _selectedPeriod == 'monthly' ? 250000 : 250000 * 12 * 0.8 ~/ 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color surface = Theme.of(context).colorScheme.surface;
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final Color border = primary.withOpacity(0.2);
    final bool isMaterial3 = Theme.of(context).useMaterial3;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: surface,
        elevation: 0,
        title: const Text('Choose a Plan', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Choose a subscription plan to post listings.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPeriodToggle('monthly', 'Monthly'),
                const SizedBox(width: 12),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    _buildPeriodToggle('annual', 'Annual'),
                    if (_selectedPeriod == 'annual')
                      Positioned(
                        right: 0,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Save 20%',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildPlanCard(
                    plan: 'free',
                    title: 'No plan — browse only',
                    price: 0,
                    features: const [],
                    description: '',
                    selected: _selectedPlan == 'free',
                    onTap: () {
                      setState(() => _selectedPlan = 'free');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    plan: 'agent',
                    title: 'Agent Plan',
                    price: _selectedPeriod == 'monthly' ? 150000 : 150000 * 12 * 0.8 ~/ 1,
                    features: const [
                      'Up to 50 properties',
                      'Verified agent badge',
                    ],
                    description: 'Best choice for individual agents. Listings reach serious buyers faster.',
                    selected: _selectedPlan == 'agent',
                    highlight: true,
                    onTap: () {
                      setState(() => _selectedPlan = 'agent');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    plan: 'enterprise',
                    title: 'Enterprise Plan',
                    price: _selectedPeriod == 'monthly' ? 250000 : 250000 * 12 * 0.8 ~/ 1,
                    features: const [
                      'Up to 100 listings',
                      'Multi-agent support',
                      'Branded profile',
                    ],
                    description: 'For companies managing multiple agents',
                    selected: _selectedPlan == 'enterprise',
                    badge: 'Most Popular',
                    onTap: () {
                      setState(() => _selectedPlan = 'enterprise');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: primary,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _selectedPlan == 'free'
                    ? null
                    : () {
                        widget.onPlanSelected(
                          _selectedPlan,
                          _selectedPeriod,
                          _selectedPrice,
                        );
                      },
                child: Text(
                  _selectedPlan == 'free'
                      ? 'Browse Only'
                      : 'Subscribe — UGX ${_selectedPrice.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ",")} /${_selectedPeriod == 'monthly' ? 'month' : 'year'}',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle(String value, String label) {
    final bool selected = _selectedPeriod == value;
    final Color primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? primary : primary.withOpacity(0.2), width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? primary : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String plan,
    required String title,
    required int price,
    required List<String> features,
    required String description,
    bool selected = false,
    bool highlight = false,
    String? badge,
    VoidCallback? onTap,
  }) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color cardColor = Theme.of(context).colorScheme.surface;
    final Color borderColor = selected || highlight ? primary : Colors.grey.withOpacity(0.2);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: selected || highlight ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: selected || highlight ? primary : null,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (price > 0) ...[
              const SizedBox(height: 8),
              Text(
                'UGX ${price.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ",")} /${_selectedPeriod == 'monthly' ? 'month' : 'year'}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: selected || highlight ? primary : null,
                ),
              ),
            ],
            if (features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...features.map((f) => Row(
                    children: [
                      Icon(Icons.check_circle, color: primary, size: 18),
                      const SizedBox(width: 8),
                      Text(f, style: const TextStyle(fontSize: 15)),
                    ],
                  )),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
