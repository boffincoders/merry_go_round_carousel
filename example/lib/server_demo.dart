import 'package:flutter/material.dart';
import 'package:merry_go_round_carousel/merry_go_round_carousel.dart';

import 'layout.dart';
import 'mock_api.dart';

/// Loads the carousel's options from a (mock) server and shows every field
/// of the option at the front.
class ServerDemoPage extends StatefulWidget {
  const ServerDemoPage({super.key});

  @override
  State<ServerDemoPage> createState() => _ServerDemoPageState();
}

class _ServerDemoPageState extends State<ServerDemoPage> {
  final _api = MockApi();
  final _controller = MerryGoRoundController();

  List<Destination> _items = const [];
  Destination? _selected;
  bool _loading = false;
  Object? _error;
  bool _simulateError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.fetchDestinations(fail: _simulateError);
      if (!mounted) return;

      // Keep the same destination at the front after a refresh, even if the
      // server returns the list in a different order.
      var index = items.indexWhere((d) => d.id == _selected?.id);
      if (index < 0) index = 0;

      setState(() {
        _items = items;
        _selected = items.isEmpty ? null : items[index];
        _loading = false;
      });
      if (items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients) _controller.jumpToIndex(index);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _book() {
    // Another way to read the selection: ask the controller.
    final d = _items[_controller.currentIndex];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Booking ${d.name} (id: ${d.id}) for ₹${d.price}'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loaded from a server'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: _loading && _items.isNotEmpty
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final errorToggle = FilterChip(
      label: const Text('Simulate server error'),
      selected: _simulateError,
      onSelected: (v) => setState(() => _simulateError = v),
    );

    // First load still running.
    if (_items.isEmpty && _loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching destinations…'),
        ],
      );
    }

    // First load failed: nothing to show yet.
    if (_items.isEmpty && _error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text("Couldn't load destinations\n$_error",
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 12),
          errorToggle,
        ],
      );
    }

    if (_items.isEmpty) return const Text('No destinations available.');

    final width = MediaQuery.sizeOf(context).width;
    final itemSize = carouselItemSizeFor(width);
    final scale = itemSize.width / 110;
    final selected = _selected!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Refresh failed ($_error). Showing the last loaded data.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        MerryGoRoundCarousel.builder(
          controller: _controller,
          itemCount: _items.length,
          itemSize: itemSize,
          tilt: 0.28,
          semanticLabel: 'Destinations',
          // The page scrolls vertically, so let the mouse wheel scroll it;
          // sideways trackpad swipes and Shift + wheel turn the carousel.
          scrollBehavior: MerryGoRoundScrollBehavior.horizontalOnly,
          // The carousel gives you an index; the full object is _items[i].
          // onSelectedItemChanged fires once the wheel stops, so a fast fling
          // doesn't update the details for every card that flies past.
          onSelectedItemChanged: (i) => setState(() => _selected = _items[i]),
          itemBuilder: (context, i, depth) => _DestinationCard(
            destination: _items[i],
            highlighted: depth > 0.97,
            scale: scale,
          ),
        ),
        SizedBox(height: 32 * scale),
        _DetailsCard(destination: selected, onBook: _book),
        const SizedBox(height: 16),
        errorToggle,
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.highlighted,
    required this.scale,
  });

  final Destination destination;
  final bool highlighted;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: d.color,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.transparent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: d.color.withAlpha(highlighted ? 153 : 64),
            blurRadius: (highlighted ? 20 : 8) * scale,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(d.icon, size: 44 * scale, color: Colors.white),
          SizedBox(height: 8 * scale),
          Text(
            d.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16 * scale,
            ),
          ),
          Text(
            '₹${d.price}',
            style: TextStyle(color: Colors.white, fontSize: 12 * scale),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.destination, required this.onBook});

  final Destination destination;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(d.icon, color: d.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${d.name}, ${d.country}',
                        style: theme.textTheme.titleLarge),
                  ),
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  Text(' ${d.rating}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(d.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('₹${d.price} per person')),
                  Chip(label: Text('${d.nights} nights')),
                  Chip(label: Text('id: ${d.id}')),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child:
                    FilledButton(onPressed: onBook, child: const Text('Book')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
