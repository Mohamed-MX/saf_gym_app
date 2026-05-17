import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';
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
  double? _currentWeight;
  double? _targetWeight;
  double? _startedWeight;
  String? _gender;
  int? _age;
  double? _height;
  int? _activityFactor;
  
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
    final profileData = await FirestoreService.instance.getProfile();
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
      _profileImagePath = profileData['profileImagePath'] as String?;
      _currentWeight = profileData['currentWeight'] as double?;
      _targetWeight = profileData['targetWeight'] as double?;
      _startedWeight = profileData['startedWeight'] as double?;
      _gender = profileData['gender'] as String?;
      _age = profileData['age'] as int?;
      _height = profileData['height'] as double?;
      _activityFactor = profileData['activityFactor'] as int?;
      _injuries = (profileData['injuries'] as List?)?.map((e) => e.toString()).toList() ?? [];
      
      _completedWorkouts = completedDays.length;
      _startedWorkouts = 7; // Weekly Goal
      _missedWorkouts = (now.weekday - _completedWorkouts).clamp(0, 7);
    });
  }

  Future<void> _logNewWeight() async {
    final TextEditingController controller = TextEditingController(text: _currentWeight?.toString() ?? '');
    final newWeightStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3B3B4F),
        title: Text('Log New Weight', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      final updates = <String, dynamic>{'currentWeight': newWeight};
      if (_startedWeight == null) {
        updates['startedWeight'] = newWeight;
      }
      
      await FirestoreService.instance.updateProfile(updates);
      setState(() {
        _currentWeight = newWeight;
        if (_startedWeight == null) {
          _startedWeight = newWeight;
        }
      });
    }
  }

  Future<void> _addInjury() async {
    String? selectedInjury = 'Shoulder';
    final availableInjuries = ['Shoulder', 'Arm', 'Forearm (Wrist)', 'Legs', 'Back', 'Chest']
        .where((i) => !_injuries.contains(i))
        .toList();
        
    if (availableInjuries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All available injuries are already added!'), backgroundColor: Colors.green),
      );
      return;
    }
    
    selectedInjury = availableInjuries.first;

    final injury = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            backgroundColor: const Color(0xFF3B3B4F),
            title: Text('Add Injury', style: GoogleFonts.outfit(color: Colors.white)),
            content: DropdownButton<String>(
              value: selectedInjury,
              dropdownColor: const Color(0xFF3B3B4F),
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              items: availableInjuries
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setStateSB(() => selectedInjury = val);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, selectedInjury),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (injury != null && injury.trim().isNotEmpty && !_injuries.contains(injury.trim())) {
      final newInjuries = List<String>.from(_injuries)..add(injury.trim());
      await FirestoreService.instance.updateProfile({'injuries': newInjuries});
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

  Future<void> _removeInjury(String injury) async {
    final newInjuries = List<String>.from(_injuries)..remove(injury);
    await FirestoreService.instance.updateProfile({'injuries': newInjuries});
    setState(() {
      _injuries = newInjuries;
    });
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
    bool isProfileIncomplete = _currentWeight == null || _targetWeight == null || _height == null || _age == null || _gender == null;

    // Calculate weight progress (clamped between 0 and 1)
    double weightProgress = 0.0;
    if (_startedWeight != null && _targetWeight != null && _currentWeight != null && _startedWeight != _targetWeight) {
      weightProgress = (_startedWeight! - _currentWeight!) / (_startedWeight! - _targetWeight!);
      weightProgress = weightProgress.clamp(0.0, 1.0);
    }
    
    double workoutProgress = 0.0;
    if (_startedWorkouts > 0) {
      workoutProgress = _completedWorkouts / _startedWorkouts;
      workoutProgress = workoutProgress.clamp(0.0, 1.0);
    }
    
    // Calculate BMI
    double? bmi;
    if (_height != null && _currentWeight != null && _height! > 0) {
      double heightInM = _height! / 100;
      bmi = _currentWeight! / (heightInM * heightInM);
    }
    
    // Calculate BMR
    double? tdee;
    double? targetCalories;
    if (_currentWeight != null && _height != null && _age != null && _gender != null && _activityFactor != null) {
      double bmr = (10 * _currentWeight!) + (6.25 * _height!) - (5 * _age!);
      if (_gender == 'Male') {
        bmr += 5;
      } else {
        bmr -= 161;
      }
      
      // Calculate TDEE
      double multiplier = 1.2;
      switch (_activityFactor) {
        case 1: multiplier = 1.2; break;
        case 2: multiplier = 1.375; break;
        case 3: multiplier = 1.55; break;
        case 4: multiplier = 1.725; break;
        case 5: multiplier = 1.9; break;
      }
      tdee = bmr * multiplier;
      targetCalories = tdee - 500;
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

              if (isProfileIncomplete)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Your profile is incomplete!',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                          _loadProfileData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                ),

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
                        _buildStatColumn('Started', _startedWeight != null ? '${_startedWeight!.toStringAsFixed(0)}Kg' : '--'),
                        _buildStatColumn('Current', _currentWeight != null ? '${_currentWeight!.toStringAsFixed(0)}Kg' : '--'),
                        _buildStatColumn('Target', _targetWeight != null ? '${_targetWeight!.toStringAsFixed(0)}Kg' : '--'),
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
              
              // DAILY STATS Card
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
                      'DAILY HEALTH STATS',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('BMI', bmi != null ? bmi.toStringAsFixed(1) : '--'),
                        _buildStatColumn('TDEE', tdee != null ? '${tdee.toStringAsFixed(0)} kcal' : '--'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        targetCalories != null && _targetWeight != null
                            ? 'Recommendation: Consume ~${targetCalories.toStringAsFixed(0)} calories daily (500 deficit) to safely reach your target weight of ${_targetWeight!.toStringAsFixed(0)}kg.'
                            : 'Recommendation: Please complete your profile to receive calorie recommendations.',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
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
                         ..._injuries.map((i) => Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text('• $i', style: const TextStyle(color: Colors.white70)),
                             IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                               onPressed: () => _removeInjury(i),
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             ),
                           ],
                         )),
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
