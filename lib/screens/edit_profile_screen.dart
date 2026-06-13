import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _targetWeightController = TextEditingController();
  final _startedWeightController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  
  String? _gender;
  int? _activityFactor;
  DateTime? _dob;
  
  List<String> _injuries = [];
  final List<String> _availableInjuries = [
    'Shoulder',
    'Arm',
    'Forearm (Wrist)',
    'Legs',
    'Back',
    'Chest'
  ];
  
  String? _profileImagePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileData = await FirestoreService.instance.getProfile();
    setState(() {
      _profileImagePath = profileData['profileImagePath'] as String?;
      _targetWeightController.text = profileData['targetWeight'] != null ? (profileData['targetWeight'] as num).toString() : '';
      _startedWeightController.text = profileData['startedWeight'] != null ? (profileData['startedWeight'] as num).toString() : '';
      _usernameController.text = _authService.currentUser?.displayName ?? '';
      _ageController.text = profileData['dob'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(profileData['dob'] as int).toString().split(' ')[0] 
          : (profileData['age'] != null ? '${profileData['age']} years' : '');
      if (profileData['dob'] != null) {
        _dob = DateTime.fromMillisecondsSinceEpoch(profileData['dob'] as int);
      }
      _heightController.text = profileData['height'] != null ? (profileData['height'] as num).toString() : '';
      _gender = profileData['gender'] as String?;
      _activityFactor = profileData['activityFactor'] as int?;
      _injuries = (profileData['injuries'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    });
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    _startedWeightController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        await FirestoreService.instance.updateProfile({'profileImagePath': pickedFile.path});
        setState(() {
          _profileImagePath = pickedFile.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open gallery. Did you fully restart the app?'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate = _dob ?? DateTime(DateTime.now().year - 25);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _ageController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _saveWeight() async {
    final targetWeightStr = _targetWeightController.text.trim();
    final startedWeightStr = _startedWeightController.text.trim();
    
    if (targetWeightStr.isNotEmpty && double.tryParse(targetWeightStr) != null &&
        startedWeightStr.isNotEmpty && double.tryParse(startedWeightStr) != null) {
      await FirestoreService.instance.updateProfile({
        'targetWeight': double.parse(targetWeightStr),
        'startedWeight': double.parse(startedWeightStr),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight settings updated!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _saveUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isNotEmpty) {
      await _authService.currentUser?.updateDisplayName(newName);
      await _authService.currentUser?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _saveHealthData() async {
    final heightStr = _heightController.text.trim();
    
    if (_gender == null || _dob == null || heightStr.isEmpty || _activityFactor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all health metrics!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final height = double.tryParse(heightStr);
    if (height == null) return;

    // Calculate age from dob
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }

    await FirestoreService.instance.updateProfile({
      'dob': _dob!.millisecondsSinceEpoch,
      'age': age,
      'height': height,
      'gender': _gender,
      'activityFactor': _activityFactor,
      'injuries': _injuries,
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health metrics updated!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _changePassword() async {
    final email = _authService.currentUser?.email;
    if (email != null) {
      setState(() => _isLoading = true);
      try {
        await _authService.sendPasswordResetEmail(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent! Check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send reset email.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.charcoal),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(color: AppTheme.charcoal, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Image Picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal,
                        shape: BoxShape.circle,
                        image: _profileImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(_profileImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImagePath == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Username
            Text(
              'Username',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveUsername,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Weight Goals
            Text(
              'Weight Goals (Kg)',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startedWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Start Weight',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveWeight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Health Metrics
            Text(
              'Health Metrics',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: null, // Gender cannot be changed after registration
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDateOfBirth,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _ageController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _activityFactor,
                    decoration: InputDecoration(
                      labelText: 'Activity Level',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 - Sedentary', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 2, child: Text('2 - Lightly active', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 3, child: Text('3 - Moderately active', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 4, child: Text('4 - Very active', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 5, child: Text('5 - Extra active', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setState(() => _activityFactor = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Injured Muscles (Select any that apply)',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableInjuries.map((injury) {
                final isSelected = _injuries.contains(injury);
                return FilterChip(
                  label: Text(injury),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _injuries.add(injury);
                      } else {
                        _injuries.remove(injury);
                      }
                    });
                  },
                  selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.charcoal,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.lightGrey,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveHealthData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Health Metrics & Injuries', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            // Change Password
            Text(
              'Account Security',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _changePassword,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.lock_reset, color: Colors.white),
              label: Text(_isLoading ? 'Sending...' : 'Send Password Reset Email', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
