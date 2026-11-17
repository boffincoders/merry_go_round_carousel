import 'package:flutter/material.dart';
import 'package:merry_go_round_carousel/merry_go_round_carousel.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class _Ride {
  const _Ride(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

const _rides = [
  _Ride('Horse', Icons.bedroom_baby, Color(0xFFE57373)),
  _Ride('Rocket', Icons.rocket_launch, Color(0xFF64B5F6)),
  _Ride('Car', Icons.directions_car, Color(0xFF81C784)),
  _Ride('Boat', Icons.sailing, Color(0xFF4DD0E1)),
  _Ride('Plane', Icons.flight, Color(0xFFFFB74D)),
  _Ride('Train', Icons.train, Color(0xFFBA68C8)),
  _Ride('Bike', Icons.pedal_bike, Color(0xFFF06292)),
  _Ride('Bus', Icons.directions_bus, Color(0xFFA1887F)),
];

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _controller = MerryGoRoundController();
  bool _autoRotate = true;
  int _front = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Card size for the current screen width: phone, tablet or desktop.
  static Size _itemSizeFor(double width) {
    if (width >= 1024) return const Size(180, 230);
    if (width >= 600) return const Size(150, 190);
    return const Size(110, 140);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final itemSize = _itemSizeFor(width);
    final scale = itemSize.width / 110;

    return Scaffold(
      appBar: AppBar(title: const Text('Merry-go-round carousel')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            // Keep the ring from stretching across very wide windows.
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _rides[_front].name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: 32 * scale),
                MerryGoRoundCarousel.builder(
                  controller: _controller,
                  itemCount: _rides.length,
                  itemSize: itemSize,
                  tilt: 0.28,
                  autoRotate: _autoRotate,
                  semanticLabel: 'Rides',
                  onIndexChanged: (i) => setState(() => _front = i),
                  onItemTap: (i) => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                        SnackBar(content: Text('Tapped ${_rides[i].name}'))),
                  center: _Pole(height: itemSize.height * 1.3),
                  itemBuilder: (context, index, depth) => _RideCard(
                    ride: _rides[index],
                    highlighted: depth > 0.97,
                    scale: scale,
                  ),
                ),
                SizedBox(height: 40 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _controller.previous(),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 16),
                    FilterChip(
                      label: const Text('Auto-rotate'),
                      selected: _autoRotate,
                      onSelected: (v) => setState(() => _autoRotate = v),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      onPressed: () => _controller.next(),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (width >= 600) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Drag, scroll or use the arrow keys to spin',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    required this.highlighted,
    this.scale = 1,
  });
  final _Ride ride;
  final bool highlighted;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: ride.color,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.transparent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: ride.color.withAlpha(highlighted ? 153 : 64),
            blurRadius: (highlighted ? 20 : 8) * scale,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ride.icon, size: 48 * scale, color: Colors.white),
          SizedBox(height: 8 * scale),
          Text(
            ride.name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pole extends StatelessWidget {
  const _Pole({this.height = 180});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFD54F)],
        ),
      ),
    );
  }
}
