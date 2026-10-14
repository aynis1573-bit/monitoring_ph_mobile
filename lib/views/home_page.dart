import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  final HomeViewModel viewModel;
  final String currentRole;

  const HomePage({super.key, required this.viewModel, required this.currentRole});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final Map<String, bool> _outOfRangeByLocation = {};
  final Map<String, bool> _staleByLocation = {};
  bool _alertDialogOpen = false;
  Timer? _sensorAlertTimer;

  bool get _isPengelola => widget.currentRole == 'pengelola';
  bool get _isMaintenance => widget.currentRole == 'maintenance';

  // Navigasi lengkap untuk sidebar web/desktop.
  List<_NavigationItem> get _navigationItems => [
        const _NavigationItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
        const _NavigationItem(Icons.show_chart, Icons.show_chart, 'Grafik', 1),
        const _NavigationItem(Icons.notifications_outlined, Icons.notifications, 'Notifikasi', 3),
        const _NavigationItem(Icons.history, Icons.history, 'Riwayat Data', 2),
        if (_isPengelola) const _NavigationItem(Icons.assessment_outlined, Icons.assessment, 'Laporan', 4),
        // Status sensor dapat dilihat kedua role; popup data kedaluwarsa khusus Maintenance.
        const _NavigationItem(Icons.build_circle_outlined, Icons.build_circle, 'Pemeliharaan Sensor', 5),
      ];

  // Navigasi ringkas khusus ponsel agar label tidak berdesakan.
  // Laporan dan Pemeliharaan dapat dibuka melalui menu Lainnya.
  List<_NavigationItem> get _mobileNavigationItems => const [
        _NavigationItem(Icons.dashboard_outlined, Icons.dashboard, 'Beranda', 0),
        _NavigationItem(Icons.show_chart, Icons.show_chart, 'Grafik', 1),
        _NavigationItem(Icons.history, Icons.history, 'Riwayat', 2),
        _NavigationItem(Icons.notifications_outlined, Icons.notifications, 'Notifikasi', 3),
        _NavigationItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Lainnya', 6),
      ];

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_scheduleAlertCheck);
    _sensorAlertTimer = Timer.periodic(const Duration(seconds: 30), (_) => _scheduleAlertCheck());
    _scheduleAlertCheck();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_scheduleAlertCheck);
    _sensorAlertTimer?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _scheduleAlertCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluateAlerts();
    });
  }

  void _evaluateAlerts() {
    if (widget.viewModel.isLoading || widget.viewModel.errorMessage != null) return;
    final messages = <String>[];
    for (final location in locations) {
      final item = _findLatestForLocation(location);
      // Tidak ada data belum cukup untuk menyimpulkan sensor rusak/offline.
      if (item == null) continue;

      final ph = double.tryParse(item.ph.toString());
      final outOfRange = ph != null && (ph < 6.5 || ph > 8.5);
      final wasOutOfRange = _outOfRangeByLocation[location] ?? false;
      _outOfRangeByLocation[location] = outOfRange;
      if (outOfRange && !wasOutOfRange) {
        final direction = ph! < 6.5 ? 'di bawah 6,5' : 'di atas 8,5';
        messages.add('Nilai pH $location ${direction}. Pembacaan terakhir ${ph.toStringAsFixed(2)}. Segera periksa pembacaan dan kondisi air.');
      }

      final timestamp = item.timestamp;
      DateTime? lastRead;
      try {
        lastRead = timestamp?.toDate().toLocal();
      } catch (_) {
        lastRead = null;
      }
      final isStale = lastRead != null && DateTime.now().difference(lastRead) > const Duration(minutes: 5);
      final wasStale = _staleByLocation[location] ?? false;
      _staleByLocation[location] = isStale;
      if (_isMaintenance && isStale && !wasStale) {
        messages.add('Data dari titik $location tidak diperbarui lebih dari 5 menit. Periksa daya ESP32, Wi-Fi, sensor, dan koneksi Firebase.');
      }
    }
    if (messages.isNotEmpty) _showAlertPopup(messages);
  }

  void _showAlertPopup(List<String> messages) {
    if (!mounted || _alertDialogOpen) return;
    _alertDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.notifications_active, color: Color(0xFFE18A17), size: 38),
        title: const Text('Peringatan Monitoring'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 330),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages.map((message) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE18A17), size: 20),
                  const SizedBox(width: 9),
                  Expanded(child: Text(message, style: const TextStyle(height: 1.45))),
                ]),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Saya mengerti'),
          ),
        ],
      ),
    ).whenComplete(() {
      _alertDialogOpen = false;
    });
  }

  static const Color navy = Color(0xFF123B65);
  static const Color blue = Color(0xFF147DCE);
  static const Color paleBlue = Color(0xFFEAF4FC);
  static const Color pageBg = Color(0xFFF4F8FC);
  static const Color green = Color(0xFF269B67);
  static const Color orange = Color(0xFFF2A12B);

  static const List<String> locations = [
    'Depot Utama',
    'Toren Cabang 1',
    'Toren Cabang 2',
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final navItems = isDesktop ? _navigationItems : _mobileNavigationItems;
    var selectedNavIndex = navItems.indexWhere((item) => item.routeIndex == _selectedIndex);
    // Jika halaman Laporan/Pemeliharaan dibuka dari menu Lainnya,
    // menu Lainnya tetap menjadi tab yang aktif di bottom navigation.
    if (!isDesktop && selectedNavIndex < 0 && (_selectedIndex == 4 || _selectedIndex == 5)) {
      selectedNavIndex = navItems.indexWhere((item) => item.routeIndex == 6);
    }
    return Scaffold(
      backgroundColor: pageBg,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              title: const Text('Monitoring pH Air', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(20)),
                    alignment: Alignment.center,
                    child: Text(_roleLabel, style: const TextStyle(fontSize: 11, color: navy, fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(
                  tooltip: 'Keluar',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                ),
                const SizedBox(width: 5),
              ],
            ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          if (widget.viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator(color: blue));
          }
          if (widget.viewModel.errorMessage != null) {
            return _errorView(widget.viewModel.errorMessage!);
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1000;
              if (desktop) {
                return Row(
                  children: [
                    _buildSidebar(),
                    Expanded(child: _buildMainContent(isDesktop: true)),
                  ],
                );
              }
              return _buildMainContent(isDesktop: false);
            },
          );
        },
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: selectedNavIndex < 0 ? 0 : selectedNavIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = navItems[index].routeIndex),
              backgroundColor: Colors.white,
              indicatorColor: paleBlue,
              destinations: navItems.map((item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              )).toList(),
            ),
    );
  }

  String get _roleLabel => _isPengelola ? 'Pengelola' : 'Maintenance';

  Widget _buildMainContent({required bool isDesktop}) {
    Widget page;
    switch (_selectedIndex) {
      case 1:
        page = _buildChartOnlyPage();
        break;
      case 2:
        page = _buildHistoryPage(isDesktop: isDesktop);
        break;
      case 3:
        page = _buildNotificationsPage();
        break;
      case 4:
        page = _isPengelola ? _buildReportsPage() : _buildDashboard(isDesktop: isDesktop);
        break;
      case 5:
        page = _buildMaintenancePage();
        break;
      case 6:
        page = _buildMorePage();
        break;
      default:
        page = _buildDashboard(isDesktop: isDesktop);
    }
    return SafeArea(child: page);
  }

  Widget _buildSidebar() {
    return Container(
      width: 225,
      decoration: const BoxDecoration(
        color: navy,
        gradient: LinearGradient(
          colors: [Color(0xFF123B65), Color(0xFF082A4A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 28),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Monitoring pH Air',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final item in _navigationItems)
            _sidebarItem(item.icon, item.label, item.routeIndex),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Text('Masuk sebagai $_roleLabel', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Keluar', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Sistem IoT • Monitoring kualitas air', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index) {
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? const Color(0xFF247FC6) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() => _selectedIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard({required bool isDesktop}) {
    final data = widget.viewModel.sensorData;
    final latest = widget.viewModel.latestData;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(isDesktop),
          const SizedBox(height: 22),
          if (latest == null)
            _emptyState()
          else ...[
            _buildLocationCards(isDesktop),
            const SizedBox(height: 18),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildChartCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildComparisonCard()),
                ],
              )
            else ...[
              _buildCurrentPhCard(latest),
              const SizedBox(height: 16),
              _buildChartCard(),
            ],
            const SizedBox(height: 18),
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildStatusAndInfo(latest)),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _buildPhEducationCard()),
                ],
              ),
              const SizedBox(height: 18),
              _buildHistoryTable(data),
            ] else ...[
              _buildStatusAndInfo(latest),
              const SizedBox(height: 14),
              _buildPhEducationCard(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard Monitoring',
                style: TextStyle(
                  color: navy,
                  fontSize: isDesktop ? 23 : 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Pantau data kualitas air dari Firebase secara realtime.',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        if (isDesktop)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDCE8F2)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.calendar_month, color: navy, size: 19),
                SizedBox(width: 8),
                Text('Data terbaru dari Firestore',
                    style: TextStyle(color: navy, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocationCards(bool isDesktop) {
    final cards = locations.map((location) {
      final match = widget.viewModel.sensorData.where((item) {
        return item.location.toString().trim().toLowerCase() ==
            location.toLowerCase();
      }).toList();

      final sensor = match.isNotEmpty ? match.first : null;
      return Expanded(
        child: _locationCard(location, sensor),
      );
    }).toList();

    if (!isDesktop) {
      return Column(
        children: [
          for (final location in locations) ...[
            _locationCard(
              location,
              _findLatestForLocation(location),
              compact: true,
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          cards[i],
        ],
      ],
    );
  }

  dynamic _findLatestForLocation(String location) {
    for (final item in widget.viewModel.sensorData) {
      if (item.location.toString().trim().toLowerCase() ==
          location.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  Widget _locationCard(String location, dynamic sensor, {bool compact = false}) {
    final ph = sensor == null
        ? null
        : double.tryParse(sensor.ph.toString());
    final status = _phStatus(ph);
    final borderColor = sensor == null
        ? const Color(0xFFDCE6EF)
        : status.color.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(compact ? 15 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop, color: blue, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
                const SizedBox(height: 7),
                if (sensor == null)
                  const Text(
                    'Belum ada data',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 9,
                    runSpacing: 5,
                    children: [
                      Text(
                        ph == null ? '-' : ph.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFF152B40),
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('pH',
                          style: TextStyle(color: navy, fontSize: 12)),
                      _statusPill(status, compact: true),
                    ],
                  ),
                if (sensor != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Update: ${_formatTime(sensor.timestamp)}',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPhCard(dynamic data) {
    final ph = double.tryParse(data.ph.toString());
    final status = _phStatus(ph);
    return _panel(
      child: Column(
        children: [
          const Text('pH TERKINI',
              style: TextStyle(
                color: Colors.blueGrey,
                letterSpacing: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),
          Text(
            ph == null ? '-' : ph.toStringAsFixed(2),
            style: const TextStyle(
              color: navy,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          _statusPill(status),
          const SizedBox(height: 10),
          Text('Lokasi: ${data.location}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          Text('Update: ${_formatTime(data.timestamp)}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final data = widget.viewModel.sensorData.reversed.toList();
    final valid = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final ph = double.tryParse(data[i].ph.toString());
      if (ph != null) valid.add(FlSpot(i.toDouble(), ph));
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grafik Perubahan pH',
              style: TextStyle(
                color: navy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          const Text('Berdasarkan pembacaan yang tersimpan',
              style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
          const SizedBox(height: 18),
          SizedBox(
            height: 250,
            child: valid.length < 2
                ? const Center(
                    child: Text(
                      'Grafik membutuhkan minimal 2 data pH.',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 14,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: const Color(0xFFE7EEF5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 2,
                            getTitlesWidget: (value, _) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 25,
                            interval: (valid.length / 4).clamp(1, 100).toDouble(),
                            getTitlesWidget: (value, _) {
                              final index = value.toInt();
                              if (index < 0 || index >= data.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  _shortTime(data[index].timestamp),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((spot) => LineTooltipItem(
                                    'pH ${spot.y.toStringAsFixed(2)}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: valid,
                          isCurved: true,
                          color: blue,
                          barWidth: 2.5,
                          dotData: FlDotData(
                            show: valid.length <= 20,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: blue,
                              strokeWidth: 1.5,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: blue.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    final values = locations.map((location) {
      final item = _findLatestForLocation(location);
      return (location, item == null ? null : double.tryParse(item.ph.toString()));
    }).toList();

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Perbandingan Nilai pH',
              style: TextStyle(
                color: navy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 14,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 2,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= locations.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            ['Depot', 'Toren 1', 'Toren 2'][i],
                            style: const TextStyle(
                              color: navy,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].$2 ?? 0,
                          width: 25,
                          color: [blue, green, orange][i],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                          rodStackItems: values[i].$2 == null
                              ? [BarChartRodStackItem(0, 0.08, Colors.grey.shade300)]
                              : [],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.$1,
                        style: const TextStyle(fontSize: 11, color: navy)),
                  ),
                  Text(
                    item.$2 == null ? 'Belum ada data' : item.$2!.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 11,
                      color: navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusAndInfo(dynamic data) {
    final ph = double.tryParse(data.ph.toString());
    final status = _phStatus(ph);
    return Column(
      children: [
        _panel(
          child: Row(
            children: [
              Icon(status.icon, color: status.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Kualitas Air',
                        style: TextStyle(color: navy, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(status.label,
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informasi Monitoring',
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
              const SizedBox(height: 14),
              _infoRow(Icons.location_on_outlined, 'Lokasi', '${data.location}'),
              _infoRow(Icons.memory_outlined, 'Perangkat', '${data.deviceId}'),
              _infoRow(Icons.data_usage, 'Jumlah data', '${widget.viewModel.sensorData.length} pembacaan'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTable(List<dynamic> data) {
    return _panel(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Riwayat Pengukuran Terbaru',
                      style: TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                Text('${data.length} data',
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
              ],
            ),
          ),
          if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Belum ada riwayat data.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(paleBlue),
                columns: const [
                  DataColumn(label: Text('Tanggal & Waktu')),
                  DataColumn(label: Text('Titik Monitoring')),
                  DataColumn(label: Text('Nilai pH')),
                  DataColumn(label: Text('Status')),
                ],
                rows: data.take(12).map((item) {
                  final ph = double.tryParse(item.ph.toString());
                  final status = _phStatus(ph);
                  return DataRow(cells: [
                    DataCell(Text(_formatTime(item.timestamp))),
                    DataCell(Text('${item.location}')),
                    DataCell(Text(ph == null ? '-' : ph.toStringAsFixed(2))),
                    DataCell(_statusPill(status, compact: true)),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryPage({required bool isDesktop}) {
    final data = widget.viewModel.sensorData;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: navy,
          child: const Text('Riwayat Data pH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
        ),
        Expanded(
          child: data.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final status = _phStatus(double.tryParse(item.ph.toString()));
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(status.icon, color: status.color),
                        title: Text('pH ${_formatPh(item.ph)}'),
                        subtitle: Text('${item.location} • ${_formatTime(item.timestamp)}'),
                        trailing: _statusPill(status, compact: true),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChartOnlyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grafik pH',
              style: TextStyle(color: navy, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildChartCard(),
          const SizedBox(height: 16),
          _buildComparisonCard(),
        ],
      ),
    );
  }

  Widget _buildNotificationsPage() {
    final alerts = <Widget>[];
    for (final location in locations) {
      final item = _findLatestForLocation(location);
      if (item == null) {
        alerts.add(_alertTile(
          icon: Icons.sensors_off_outlined,
          title: 'Data belum tersedia — $location',
          detail: 'Belum ada pembacaan yang ditemukan. Ini belum membuktikan sensor rusak; periksa daya, Wi-Fi, dan pengiriman data ESP32.',
          color: orange,
        ));
        continue;
      }
      final ph = double.tryParse(item.ph.toString());
      if (ph == null || ph < 6.5 || ph > 8.5) {
        final status = _phStatus(ph);
        alerts.add(_alertTile(
          icon: status.icon,
          title: 'Nilai pH perlu diperiksa — $location',
          detail: 'Pembacaan terakhir ${_formatPh(item.ph)} pada ${_formatTime(item.timestamp)}.',
          color: status.color,
        ));
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pageHeading('Notifikasi', 'Peringatan dari pembacaan pH terbaru.'),
        const SizedBox(height: 18),
        _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined, color: blue),
            const SizedBox(width: 9),
            const Expanded(child: Text('Peringatan saat ini', style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 16))),
            _statusPill(_PhStatus(
              label: alerts.isEmpty ? 'Tidak ada peringatan pH' : '${alerts.length} peringatan',
              shortLabel: alerts.isEmpty ? 'Aman' : 'Periksa',
              icon: alerts.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
              color: alerts.isEmpty ? green : orange,
            ), compact: true),
          ]),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada nilai pH di luar rentang 6,5–8,5 pada titik yang memiliki data.', style: TextStyle(color: Colors.blueGrey, height: 1.5)),
            )
          else
            ...alerts.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: item)),
        ])),
        const SizedBox(height: 12),
        _panel(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Peringatan gangguan sensor', style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Web dapat menandai titik yang belum memiliki data, tetapi untuk memastikan sensor terputus dibutuhkan heartbeat dari ESP32 atau aturan batas waktu data terakhir. Jangan menyimpulkan sensor rusak hanya dari data kosong.', style: TextStyle(color: Colors.blueGrey, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildReportsPage() {
    final data = widget.viewModel.sensorData;
    final values = data.map((item) => double.tryParse(item.ph.toString())).whereType<double>().toList();
    final average = values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    final low = values.where((value) => value < 6.5).length;
    final high = values.where((value) => value > 8.5).length;
    final normal = values.length - low - high;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pageHeading('Laporan Monitoring', 'Ringkasan berdasarkan data yang saat ini dimuat.'),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final cards = <Widget>[
            _metricCard('Rata-rata pH', average == null ? '-' : average.toStringAsFixed(2), Icons.analytics_outlined, blue),
            _metricCard('Dalam rentang', '$normal', Icons.check_circle_outline, green),
            _metricCard('Di bawah 6,5', '$low', Icons.trending_down, orange),
            _metricCard('Di atas 8,5', '$high', Icons.trending_up, orange),
          ];
          final columns = constraints.maxWidth > 850 ? 4 : constraints.maxWidth > 550 ? 2 : 1;
          final itemWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: itemWidth, child: card)).toList());
        }),
        const SizedBox(height: 14),
        _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Saran tindak lanjut', style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          const Text('• Periksa ulang pembacaan jika nilai pH tidak stabil atau berada di luar rentang.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const Text('• Lakukan kalibrasi menggunakan larutan buffer dan prosedur yang sesuai.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const Text('• Catat waktu gangguan, titik monitoring, penyebab, tindakan perbaikan, dan petugas.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 8),
          Text('Catatan: web saat ini hanya mengambil ${data.length} dokumen terbaru (maksimal 60). Angka ini bukan rekap bulanan lengkap. Untuk laporan bulanan akurat, perlu query rentang tanggal atau agregasi khusus.', style: const TextStyle(color: Colors.deepOrange, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildMorePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeading('Menu Lainnya', 'Buka fitur tambahan Monitoring pH Air.'),
          const SizedBox(height: 16),
          if (_isPengelola) ...[
            _mobileMenuCard(
              icon: Icons.assessment_outlined,
              title: 'Laporan Monitoring',
              description: 'Ringkasan pembacaan pH dan saran tindak lanjut.',
              onTap: () => setState(() => _selectedIndex = 4),
            ),
            const SizedBox(height: 12),
          ],
          _mobileMenuCard(
            icon: Icons.build_circle_outlined,
            title: 'Pemeliharaan Sensor',
            description: 'Periksa pembacaan terakhir pada Depot Utama dan kedua toren.',
            onTap: () => setState(() => _selectedIndex = 5),
          ),
          const SizedBox(height: 16),
          _panel(
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Untuk kembali ke halaman utama, gunakan menu Beranda di bagian bawah. Data ditampilkan dari Firestore jika ESP32 sudah berhasil mengirim pembacaan.',
                    style: TextStyle(color: Colors.blueGrey, height: 1.5, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileMenuCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDCE8F2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: paleBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: blue, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(description, style: const TextStyle(color: Colors.blueGrey, height: 1.4, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.blueGrey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenancePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pageHeading('Pemeliharaan Sensor', 'Status data terakhir dan panduan pencatatan perawatan.'),
        const SizedBox(height: 18),
        for (final location in locations) ...[
          Builder(builder: (context) {
            final item = _findLatestForLocation(location);
            final ph = item == null ? null : double.tryParse(item.ph.toString());
            final inRange = ph != null && ph >= 6.5 && ph <= 8.5;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _panel(child: Row(children: [
                Icon(item == null ? Icons.sensors_off : Icons.sensors, color: item == null ? orange : green, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(location, style: const TextStyle(color: navy, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item == null ? 'Belum ada data' : 'Data terakhir: ${_formatTime(item.timestamp)} • pH ${_formatPh(item.ph)}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                ])),
                _statusPill(_PhStatus(label: item == null ? 'Belum terpantau' : (inRange ? 'Dalam rentang' : 'Perlu diperiksa'), shortLabel: item == null ? 'N/A' : (inRange ? 'Normal' : 'Periksa'), icon: item == null ? Icons.help_outline : (inRange ? Icons.check_circle : Icons.warning_amber_rounded), color: item == null ? Colors.grey : (inRange ? green : orange)), compact: true),
              ])),
            );
          }),
        ],
        _panel(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Format catatan perbaikan yang disarankan', style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 10),
          Text('• Tanggal dan waktu kejadian', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          Text('• Titik monitoring dan ID perangkat', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          Text('• Gejala kerusakan dan hasil pemeriksaan', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          Text('• Tindakan perbaikan, petugas, dan status penyelesaian', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          SizedBox(height: 8),
          Text('Catatan perbaikan belum tersimpan dari halaman ini. Penyimpanan riwayat perbaikan memerlukan koleksi Firestore tersendiri.', style: TextStyle(color: Colors.deepOrange, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildPhEducationCard() {
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.info_outline, color: blue), SizedBox(width: 8), Text('Mengenal pH Air', style: TextStyle(color: navy, fontWeight: FontWeight.bold, fontSize: 16))]),
      const SizedBox(height: 8),
      const Text('pH menunjukkan tingkat asam atau basa air. Nilai di bawah 7 bersifat asam, 7 netral, dan di atas 7 bersifat basa.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5)),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Row(children: [
        for (final color in [Colors.red, Colors.deepOrange, Colors.orange, Colors.yellow, Colors.lightGreen, Colors.green, Colors.teal, Colors.cyan, Colors.blue, Colors.indigo, Colors.deepPurple])
          Expanded(child: Container(height: 12, color: color)),
      ])),
      const SizedBox(height: 8),
      const Text('Rentang 6,5–8,5 ditampilkan sebagai acuan pada dashboard ini. Pastikan rentang final mengikuti standar yang dipakai dalam proyek.', style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.5)),
    ]));
  }

  Widget _pageHeading(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: navy, fontSize: 23, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
    ]);
  }

  Widget _alertTile({required IconData icon, required String title, required String detail, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return _panel(child: Row(children: [
      Icon(icon, color: color, size: 28), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)), const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: navy, fontSize: 23, fontWeight: FontWeight.bold)),
      ])),
    ]));
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.water_drop_outlined, size: 52, color: blue),
            SizedBox(height: 12),
            Text(
              'Belum ada data pH dari Firebase',
              style: TextStyle(color: navy, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'Pastikan perangkat mengirim data ke koleksi ph-activity.',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            const Text('Gagal mengambil data Firebase',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2EBF3)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D3557),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _statusPill(_PhStatus status, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 12 : 15, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.shortLabel,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: blue, size: 19),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(label,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  color: navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  String _formatPh(dynamic value) {
    final ph = double.tryParse(value.toString());
    return ph == null ? '-' : ph.toStringAsFixed(2);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      final date = timestamp.toDate().toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _shortTime(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      final date = timestamp.toDate().toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  _PhStatus _phStatus(double? ph) {
    if (ph == null) {
      return const _PhStatus(
        label: 'Data tidak tersedia',
        shortLabel: 'N/A',
        icon: Icons.help_outline,
        color: Colors.grey,
      );
    }
    if (ph >= 6.5 && ph <= 8.5) {
      return const _PhStatus(
        label: 'Dalam Rentang',
        shortLabel: 'Normal',
        icon: Icons.check_circle,
        color: green,
      );
    }
    if (ph < 6.5) {
      return const _PhStatus(
        label: 'Di Bawah Rentang',
        shortLabel: 'Rendah',
        icon: Icons.warning_amber_rounded,
        color: orange,
      );
    }
    return const _PhStatus(
      label: 'Di Atas Rentang',
      shortLabel: 'Tinggi',
      icon: Icons.warning_amber_rounded,
      color: orange,
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int routeIndex;

  const _NavigationItem(this.icon, this.selectedIcon, this.label, this.routeIndex);
}

class _PhStatus {
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;

  const _PhStatus({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });
}
