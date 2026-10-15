import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Pure display widget. All calculation is done in _MapScreenState.
/// Pass already-computed values; this widget just renders them.
class PropertyTaxCalculatorWidget extends StatelessWidget {
  final double? rate;
  final double? totalCurrentArv;
  final double? adjustedArv;
  final String adjustmentLabel;
  final String arvFormula;
  final String roadLocationText;
  final String natureOfHouseText;

  const PropertyTaxCalculatorWidget({
    super.key,
    this.rate,
    this.totalCurrentArv,
    this.adjustedArv,
    this.adjustmentLabel = '',
    this.arvFormula = '',
    this.roadLocationText = '',
    this.natureOfHouseText = '',
  });

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final hasRate = rate != null;
    final hasArv = totalCurrentArv != null;
    final hasAdjusted = adjustedArv != null && adjustedArv != totalCurrentArv;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3B5BDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B5BDB).withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Property Tax Auto-Calculation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withAlpha(50)),
          const SizedBox(height: 16),

          // Rate row
          _CalcRow(
            step: '1–2',
            label: 'Auto Rate',
            value: hasRate ? _fmt(rate!) : '—',
            sublabel: hasRate
                ? '$roadLocationText  ×  $natureOfHouseText'
                : 'Select Road Width & Nature of House',
            icon: Icons.speed_outlined,
            isReady: hasRate,
          ),
          const SizedBox(height: 12),

          // ARV row
          _CalcRow(
            step: '3–5',
            label: 'Total Current ARV',
            value: hasArv ? '₹ ${_fmt(totalCurrentArv!)}' : '—',
            sublabel: hasArv ? arvFormula : 'Select Property Type & enter areas',
            icon: Icons.account_balance_outlined,
            isReady: hasArv,
          ),

          if (hasAdjusted) ...[
            const SizedBox(height: 12),
            _CalcRow(
              step: '6–8',
              label: 'Adjusted ARV',
              value: '₹ ${_fmt(adjustedArv!)}',
              sublabel: adjustmentLabel,
              icon: Icons.tune_outlined,
              isReady: true,
              highlight: true,
            ),
          ],

          const SizedBox(height: 14),
          if (!hasRate)
            _HintBanner(text: 'Select Road Location Width and Nature of House to auto-fill the Rate.')
          else if (!hasArv)
            _HintBanner(text: 'Select Property Type and enter area values to calculate ARV.')
          else if (!hasAdjusted)
            _HintBanner(text: 'Select Property Use As and enter Construction Year to apply the adjustment.'),
        ],
      ),
    );
  }
}

// ── Internal sub-widgets ──────────────────────────────────────────────────────

@staticIconProvider
class _CalcRow extends StatelessWidget {
  final String step;
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final bool isReady;
  final bool highlight;

  const _CalcRow({
    required this.step,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.isReady,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? Colors.white.withAlpha(40) : Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReady ? Colors.white.withAlpha(80) : Colors.white.withAlpha(30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isReady ? Colors.white.withAlpha(50) : Colors.white.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    Text('Step $step',
                        style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isReady ? Colors.white : Colors.white54,
                    fontSize: isReady ? 20 : 16,
                    fontWeight: isReady ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (sublabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintBanner extends StatelessWidget {
  final String text;
  const _HintBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
