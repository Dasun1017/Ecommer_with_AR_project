import 'package:flutter/material.dart';

class ArTryOnControls extends StatelessWidget {
  const ArTryOnControls({
    super.key,
    required this.productName,
    required this.selectedSize,
    required this.cartCount,
    required this.fitScale,
    required this.verticalOffset,
    required this.isPoseDetected,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onFitScaleChanged,
    required this.onVerticalOffsetChanged,
  });

  final String productName;
  final String? selectedSize;
  final int cartCount;
  final double fitScale;
  final double verticalOffset;
  final bool isPoseDetected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<double> onFitScaleChanged;
  final ValueChanged<double> onVerticalOffsetChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedSize == null
                              ? 'Starting fit: standard'
                              : 'Starting fit: size $selectedSize',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: onToggleCollapsed,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                    ),
                    icon: Icon(
                      isCollapsed ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                    ),
                    tooltip: isCollapsed ? 'Expand controls' : 'Collapse controls',
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: isPoseDetected ? 'Pose locked' : 'Scanning body',
                    color: isPoseDetected ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ],
              ),
              if (!isCollapsed) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.straighten,
                      label: selectedSize == null
                          ? 'Size not selected'
                          : 'Selected size: $selectedSize',
                    ),
                    _InfoChip(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Cart items: $cartCount',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SliderRow(
                  icon: Icons.zoom_out_map,
                  label: 'Fit size',
                  valueLabel: '${(fitScale * 100).round()}%',
                  value: fitScale,
                  min: 0.75,
                  max: 1.35,
                  onChanged: onFitScaleChanged,
                ),
                const SizedBox(height: 10),
                _SliderRow(
                  icon: Icons.height,
                  label: 'Lift',
                  valueLabel: verticalOffset.round().toString(),
                  value: verticalOffset,
                  min: -80,
                  max: 80,
                  onChanged: onVerticalOffsetChanged,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stand a little back from the camera so shoulders and hips stay visible.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.zoom_out_map,
                        label: 'Fit ${(fitScale * 100).round()}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.height,
                        label: 'Lift ${verticalOffset.round()}',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
