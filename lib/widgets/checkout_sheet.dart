import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_type.dart';
import '../theme/spotify_colors.dart';

/// A single item in the checkout list.
class CheckoutItem {
  const CheckoutItem({
    required this.title,
    required this.amount,
    required this.iconAsset,
    this.selected = true,
  });

  final String title;
  final String amount;
  final String iconAsset;
  final bool selected;
}

/// A simple draggable bottom sheet showing a checkout summary.
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key, required this.items});

  final List<CheckoutItem> items;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  late List<CheckoutItem> _items = List.of(widget.items);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _items
        .where((e) => e.selected)
        .fold<double>(0, (p, e) {
          final val = double.tryParse(
            e.amount.replaceAll(RegExp('[^0-9.]'), ''),
          );
          return p + (val ?? 0);
        })
        .toStringAsFixed(0);
    final totalDisplay =
        '₦${total.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}.00';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: SpotifyColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Checkout', style: AppType.name(scheme)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: scheme.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: SpotifyColors.border,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Items', style: AppType.subtitle(scheme)),
                  TextButton(
                    onPressed: () {
                      setState(() => _items = List.of(widget.items));
                    },
                    child: Text(
                      'Add all',
                      style: AppType.subtitle(
                        scheme,
                      ).copyWith(color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _items.length; i++)
              _CheckoutTile(
                item: _items[i],
                onToggle: (v) => setState(
                  () => _items[i] = CheckoutItem(
                    title: _items[i].title,
                    amount: _items[i].amount,
                    iconAsset: _items[i].iconAsset,
                    selected: v,
                  ),
                ),
                onRemove: () => setState(() => _items.removeAt(i)),
              ),
            const Divider(
              height: 1,
              thickness: 1,
              color: SpotifyColors.border,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: AppType.name(scheme)),
                  Text(totalDisplay, style: AppType.name(scheme)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Complete Payment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutTile extends StatelessWidget {
  const _CheckoutTile({
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final CheckoutItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: item.selected,
            onChanged: (v) => onToggle(v ?? false),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            item.iconAsset,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(scheme),
                ),
                const SizedBox(height: 2),
                Text(item.amount, style: AppType.meta(scheme)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 11),
            color: scheme.onSurfaceVariant,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
