import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crop_price_provider.dart';
import '../providers/settings_provider.dart';
import '../models/crop_price.dart';
import '../utils/gujarati_number_helper.dart';

class AgraPotatoPricesScreen extends StatelessWidget {
  const AgraPotatoPricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final priceProvider = context.watch<CropPriceProvider>();
    final settings = context.watch<SettingsProvider>();

    final visibleAgraPrices = priceProvider.agraPrices
        .where((p) => !settings.hiddenAgraCrops.contains(p.name))
        .toList();

    // Group prices by date
    final Map<String, List<CropPrice>> groupedPrices = {};
    for (var price in visibleAgraPrices) {
      if (!groupedPrices.containsKey(price.date)) {
        groupedPrices[price.date] = [];
      }
      groupedPrices[price.date]!.add(price);
    }

    // Sort dates in descending order (assumes format DD/MM/YYYY)
    final sortedDates = groupedPrices.keys.toList()
      ..sort((a, b) {
        try {
          final aParts = a.split('/');
          final bParts = b.split('/');
          final aDate = DateTime(
              int.parse(aParts[2]), int.parse(aParts[1]), int.parse(aParts[0]));
          final bDate = DateTime(
              int.parse(bParts[2]), int.parse(bParts[1]), int.parse(bParts[0]));
          return bDate.compareTo(aDate);
        } catch (e) {
          return b.compareTo(a);
        }
      });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          gu ? 'બટાકા આગ્રા માર્કેટ' : 'Agra Potato Markets',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Hero(
              tag: 'agra_location_icon',
              child: Icon(Icons.location_on_rounded, color: cs.primary),
            ),
          ),
        ],
      ),
      body: visibleAgraPrices.isEmpty && !priceProvider.isLoading
          ? Center(
              child: Text(
                gu ? 'કોઈ ડેટા ઉપલબ્ધ નથી' : 'No data available',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => priceProvider.fetchPrices(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final date in sortedDates) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 4),
                      child: Text(
                        gu
                            ? GujaratiNumberHelper.toGujarati(date.replaceAll('/', '-'))
                            : date,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _buildAgraPriceGrid(context, groupedPrices[date]!, gu, cs),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAgraPriceGrid(
      BuildContext context, List<CropPrice> prices, bool gu, ColorScheme cs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.6,
      ),
      itemCount: prices.length,
      itemBuilder: (context, index) {
        final price = prices[index];
        return _AgraPriceCard(price: price, gu: gu, cs: cs, index: index);
      },
    );
  }
}

class _AgraPriceCard extends StatelessWidget {
  final CropPrice price;
  final bool gu;
  final ColorScheme cs;
  final int index;

  const _AgraPriceCard({
    required this.price,
    required this.gu,
    required this.cs,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Use yardName directly — it holds the actual Agra mandi/market name
    final String displayName = price.yardName.isNotEmpty ? price.yardName : price.name;

    return FutureBuilder(
      future: Future.delayed(Duration(milliseconds: index * 50)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            color: cs.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox()
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '₹ ${gu ? GujaratiNumberHelper.toGujarati(price.minPrice) : price.minPrice} - ${gu ? GujaratiNumberHelper.toGujarati(price.maxPrice) : price.maxPrice}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox()
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
