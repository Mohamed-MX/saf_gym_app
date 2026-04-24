import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/workout_plans_viewmodel.dart';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import '../services/muscle_wiki_service.dart';
import '../ble/ble_manager.dart';

import 'ai_workout_plan_screen.dart';
import 'rep_game_screen.dart';
import 'workout_plan_editor_screen.dart';
import 'workout_plans_screen.dart';
import 'performance_dashboard_screen.dart';
import 'workout_session_screen.dart';

// ── Changed to StatefulWidget to safely handle the scan on startup ──
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleManager _bleManager = BleManager();

  @override
  void initState() {
    super.initState();
    // Safely start scanning exactly once when the screen loads
    _bleManager.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => WorkoutPlansViewModel()),
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final plansVm = context.watch<WorkoutPlansViewModel>();

    // Find today's workout day from plans
    final todayName = MuscleWikiService.getDayLabel(vm.today);
    WorkoutDay? todayWorkout;
    WorkoutPlan? todayPlan;
    for (final plan in plansVm.plans) {
      for (final day in plan.days) {
        if (day.dayName == todayName && day.exercises.isNotEmpty) {
          todayWorkout = day;
          todayPlan = plan;
          break;
        }
      }
      if (todayWorkout != null) break;
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
        slivers: [
          // ── Blue Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HomeHeader(vm: vm),
          ),

          // ── Action Cards ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Your Own Workout (blue card)
                  _CreateWorkoutCard(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkoutPlanEditorScreen(),
                        ),
                      );
                      if (context.mounted) {
                        context.read<WorkoutPlansViewModel>().loadPlans();
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // AI Workout Plan
                  _ActionCard(
                    icon: Icons.auto_awesome,
                    iconColor: AppTheme.primaryBlue,
                    title: 'AI Workout Plan',
                    subtitle: 'Customize your training',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiWorkoutPlanScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Performance Dashboard
                  _ActionCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppTheme.primaryBlue,
                    title: 'Performance Dashboard',
                    subtitle: 'View your progress',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PerformanceDashboardScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Rep Game removed per request

                  // ── Today's Plan ─────────────────────────────────────────
                  Text(
                    "Today's Plan",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TodaysPlanCard(
                    todayName: todayName,
                    planName: todayPlan?.name,
                    todayWorkout: todayWorkout,
                    isLoadingPlans: plansVm.isLoading,
                    onStart: () {
                      if (todayPlan != null && todayWorkout != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutSessionScreen(
                              day: todayWorkout!,
                              planName: todayPlan!.name,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WorkoutPlanEditorScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Header Widget ─────────────────────────────────────────────────────────────

class _HomeHeader extends StatefulWidget {
  final HomeViewModel vm;
  const _HomeHeader({required this.vm});

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
  // Shared BLE manager instance shown in header dot + passed to sheet
  final BleManager _bleManager = BleManager();
  bool _bleConnected = false;

  @override
  void initState() {
    super.initState();
    _bleManager.onDataCallback = (_, __, ___) {
      if (mounted && !_bleConnected) {
        setState(() => _bleConnected = true);
      }
    };
  }

  void _openBleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BleSheet(
        bleManager: _bleManager,
        isConnected: _bleConnected,
        onConnectionChanged: (connected) {
          if (mounted) setState(() => _bleConnected = connected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryBlue, Color(0xFF0A6DD4)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + BT icon + profile
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Let's Move Today",
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ready to crush your goals?',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Bluetooth icon button ────────────────────────────────
                  GestureDetector(
                    onTap: _openBleSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _bleConnected
                                ? Colors.greenAccent.withValues(alpha: 0.2)
                                : AppTheme.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _bleConnected
                                  ? Colors.greenAccent.withValues(alpha: 0.6)
                                  : AppTheme.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _bleConnected
                                ? Icons.bluetooth_connected_rounded
                                : Icons.bluetooth_rounded,
                            color: _bleConnected
                                ? Colors.greenAccent
                                : AppTheme.white,
                            size: 24,
                          ),
                        ),
                        // Status dot
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _bleConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryBlue,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Profile avatar ───────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const _ProfileSheet(),
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.redAccent,
                    value: '7',
                    label: 'Day streak',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppTheme.charcoal,
                    value: '900',
                    label: 'Total Reps',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.timer_rounded,
                    iconColor: AppTheme.primaryBlue,
                    value: '5k',
                    label: 'Minutes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BLE Connection Sheet ───────────────────────────────────────────────────────

class _BleSheet extends StatefulWidget {
  final BleManager bleManager;
  final bool isConnected;
  final ValueChanged<bool> onConnectionChanged;

  const _BleSheet({
    required this.bleManager,
    required this.isConnected,
    required this.onConnectionChanged,
  });

  @override
  State<_BleSheet> createState() => _BleSheetState();
}

class _BleSheetState extends State<_BleSheet> {
  bool _isScanning = false;
  bool _isConnecting = false;
  final List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults.clear();
          _scanResults.addAll(
            results.where((r) => r.device.platformName.isNotEmpty),
          );
        });
      }
    });
    // Listen to scanning state
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    try {
      await FlutterBluePlus.stopScan();
      widget.bleManager.device = device;
      await device.connect(timeout: const Duration(seconds: 8));
      widget.bleManager.discoverServices();
      widget.onConnectionChanged(true);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    final device = widget.bleManager.device;
    if (device != null) {
      await device.disconnect();
      widget.bleManager.device = null;
      widget.bleManager.characteristic = null;
      widget.onConnectionChanged(false);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isConnected
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : AppTheme.primaryBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_searching_rounded,
                  color: widget.isConnected
                      ? Colors.greenAccent
                      : AppTheme.accentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensor Connection',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.white,
                    ),
                  ),
                  Text(
                    widget.isConnected
                        ? 'SmartGymSensor connected'
                        : 'Find & connect your sensor',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isConnected
                          ? Colors.greenAccent
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // If connected — show disconnect button
          if (widget.isConnected) ...[
            _BleActionButton(
              label: 'Disconnect Sensor',
              icon: Icons.bluetooth_disabled_rounded,
              color: Colors.redAccent,
              onTap: _disconnect,
            ),
          ] else ...[
            // Scan button
            _BleActionButton(
              label: _isScanning ? 'Scanning…' : 'Scan for Devices',
              icon: _isScanning
                  ? Icons.radar_rounded
                  : Icons.search_rounded,
              color: AppTheme.primaryBlue,
              onTap: _isScanning ? null : _startScan,
              loading: _isScanning,
            ),
            const SizedBox(height: 16),

            // Device list
            if (_scanResults.isEmpty && !_isScanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No devices found. Tap Scan to search.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _scanResults.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final r = _scanResults[i];
                    final name = r.device.platformName.isNotEmpty
                        ? r.device.platformName
                        : r.device.remoteId.str;
                    final isSensor = name == 'SmartGymSensor';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSensor
                              ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSensor
                              ? Icons.sensors_rounded
                              : Icons.bluetooth_rounded,
                          color: isSensor
                              ? AppTheme.accentBlue
                              : Colors.white38,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSensor
                              ? AppTheme.white
                              : Colors.white60,
                        ),
                      ),
                      subtitle: Text(
                        'RSSI: ${r.rssi} dBm',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                      trailing: _isConnecting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryBlue,
                        ),
                      )
                          : TextButton(
                        onPressed: () => _connectTo(r.device),
                        style: TextButton.styleFrom(
                          backgroundColor:
                          AppTheme.primaryBlue.withValues(alpha: 0.15),
                          foregroundColor: AppTheme.accentBlue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Connect'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── BLE Action Button ─────────────────────────────────────────────────────────

class _BleActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _BleActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: onTap == null ? 0.08 : 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mediumGrey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Workout Card (blue) ────────────────────────────────────────────────

class _CreateWorkoutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateWorkoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryBlue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              // Plus circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Your Own Workout',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Build a Custom routine',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Action Card (white) ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.mediumGrey, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today's Plan Card ─────────────────────────────────────────────────────────

class _TodaysPlanCard extends StatelessWidget {
  final String todayName;
  final String? planName;
  final WorkoutDay? todayWorkout;
  final bool isLoadingPlans;
  final VoidCallback onStart;

  const _TodaysPlanCard({
    required this.todayName,
    required this.planName,
    required this.todayWorkout,
    required this.isLoadingPlans,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoadingPlans
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppTheme.primaryBlue),
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day row + play button
            Row(
              children: [
                Expanded(
                  child: Text(
                    planName != null ? '$planName — $todayName' : todayName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Play / Start button
                GestureDetector(
                  onTap: onStart,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Exercise list
            if (todayWorkout == null || todayWorkout!.exercises.isEmpty)
              _buildEmpty(context)
            else
              ...todayWorkout!.exercises.take(5).map(
                    (ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${ex.name} — ${ex.sets} sets × ${ex.reps} reps',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),

            if ((todayWorkout?.exercises.length ?? 0) > 5)
              Text(
                '+ ${todayWorkout!.exercises.length - 5} more exercises',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No workout planned for today.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.mediumGrey,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onStart,
          child: const Text(
            'Tap ▶ to create one now',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Profile Bottom Sheet ───────────────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.mediumGrey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.charcoal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            'Your Profile',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 24),

          // Edit Profile button
          _SheetButton(
            icon: Icons.edit_rounded,
            label: 'Edit Profile',
            iconColor: AppTheme.primaryBlue,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),

          // Log Out button
          _SheetButton(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            iconColor: Colors.redAccent,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: iconColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}