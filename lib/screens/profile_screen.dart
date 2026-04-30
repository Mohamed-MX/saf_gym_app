import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/saf_database.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  
  String? _profileImagePath;
  double _currentWeight = 69.0;
  double _targetWeight = 60.0;
  double _startedWeight = 75.0;
  
  // Mock data for workouts
  int _startedWorkouts = 65;
  int _completedWorkouts = 60;
  int _missedWorkouts = 5;

  List<String> _injuries = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = SafDatabase.instance;
    final logs = await db.getPerformanceLogs();

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    Set<String> completedDays = {};
    for (var log in logs) {
      final dt = DateTime.fromMillisecondsSinceEpoch(log['date_time']);
      final logDate = DateTime(dt.year, dt.month, dt.day);
      if (!logDate.isBefore(startOfWeekDate)) {
        completedDays.add('${logDate.year}-${logDate.month}-${logDate.day}');
      }
    }

    setState(() {
      _profileImagePath = prefs.getString('profileImagePath');
      _currentWeight = prefs.getDouble('currentWeight') ?? 69.0;
      _targetWeight = prefs.getDouble('targetWeight') ?? 60.0;
      _startedWeight = prefs.getDouble('startedWeight') ?? 75.0;
      _injuries = prefs.getStringList('injuries') ?? [];
      
      _completedWorkouts = completedDays.length;
      _startedWorkouts = 7; // Weekly Goal
      _missedWorkouts = (now.weekday - _completedWorkouts).clamp(0, 7);
    });
  }

  Future<void> _logNewWeight() async {
    final TextEditingController controller = TextEditingController(text: _currentWeight.toString());
    final newWeightStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3B3B4F),
        title: Text('Log New Weight', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Weight in Kg',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newWeightStr != null && double.tryParse(newWeightStr) != null) {
      final newWeight = double.parse(newWeightStr);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('currentWeight', newWeight);
      setState(() {
        _currentWeight = newWeight;
      });
    }
  }

  Future<void> _addInjury() async {
    final TextEditingController controller = TextEditingController();
    final injury = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3B3B4F),
        title: Text('Add Injury', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'E.g., Left shoulder pain',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryBlue)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (injury != null && injury.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final newInjuries = List<String>.from(_injuries)..add(injury.trim());
      await prefs.setStringList('injuries', newInjuries);
      setState(() {
        _injuries = newInjuries;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Injury added: $injury'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _logOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/auth-check', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = _authService.currentUser?.displayName ?? 'User';
    // Calculate weight progress (clamped between 0 and 1)
    double weightProgress = 0.0;
    if (_startedWeight != _targetWeight) {
      weightProgress = (_startedWeight - _currentWeight) / (_startedWeight - _targetWeight);
      weightProgress = weightProgress.clamp(0.0, 1.0);
    }
    
    double workoutProgress = 0.0;
    if (_startedWorkouts > 0) {
      workoutProgress = _completedWorkouts / _startedWorkouts;
      workoutProgress = workoutProgress.clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 28),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 10),

              // Avatar
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 3),
                    image: _profileImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_profileImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: _profileImagePath == null ? const Color(0xFF2D2D3E) : null,
                  ),
                  child: _profileImagePath == null
                      ? const Icon(Icons.person, size: 80, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Username
              Center(
                child: Text(
                  username,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // WEIGHT Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B3B4F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEIGHT',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress Bar
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            flex: (weightProgress * 100).toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: ((1 - weightProgress) * 100).toInt(),
                            child: Container(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('Started', '${_startedWeight.toStringAsFixed(0)}Kg'),
                        _buildStatColumn('Current', '${_currentWeight.toStringAsFixed(0)}Kg'),
                        _buildStatColumn('Target', '${_targetWeight.toStringAsFixed(0)}Kg'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Log New Weight Button
              _ProfileActionButton(
                label: 'Log New Weight',
                onTap: _logNewWeight,
                backgroundColor: const Color(0xFF3B3B4F),
                textColor: Colors.white,
              ),
              const SizedBox(height: 24),

              // WORKOUTS COMPLETED Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B3B4F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORKOUTS COMPLETED',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress Bar
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            flex: (workoutProgress * 100).toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: ((1 - workoutProgress) * 100).toInt(),
                            child: Container(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('Goal (Weekly)', '$_startedWorkouts'),
                        _buildStatColumn('Completed', '$_completedWorkouts'),
                        _buildStatColumn('Missed', '$_missedWorkouts'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Add Injury Button
              if (_injuries.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(bottom: 16),
                   child: Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Colors.redAccent.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Current Injuries:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 8),
                         ..._injuries.map((i) => Text('• $i', style: const TextStyle(color: Colors.white70))),
                       ],
                     ),
                   ),
                 ),
              _ProfileActionButton(
                label: 'Add Injury',
                icon: Icons.local_hospital_rounded,
                onTap: _addInjury,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                textColor: Colors.white,
              ),
              const SizedBox(height: 16),

              // Edit Profile Button
              _ProfileActionButton(
                label: 'Edit Profile',
                icon: Icons.person_outline_rounded,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  _loadProfileData(); // Reload in case image or weight changed
                },
                backgroundColor: const Color(0xFF5A99D4),
                textColor: Colors.white,
              ),
              const SizedBox(height: 16),

              // Log Out Button
              _ProfileActionButton(
                label: 'Log Out',
                icon: Icons.logout_rounded,
                onTap: _logOut,
                backgroundColor: const Color(0xFF5A99D4),
                textColor: Colors.white,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;

  const _ProfileActionButton({
    required this.label,
    this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Row(
            mainAxisAlignment: icon != null ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.black87, size: 28),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28), // balance the icon
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
