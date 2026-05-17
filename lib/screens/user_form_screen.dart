import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String _gender = 'Male';
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  int _activityFactor = 3;

  bool _isLoading = false;

  final List<String> _genders = ['Male', 'Female'];
  final List<int> _activityFactors = [1, 2, 3, 4, 5];

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final age = int.parse(_ageController.text);
    final height = double.parse(_heightController.text);
    final weight = double.parse(_weightController.text);
    final targetWeight = double.parse(_targetWeightController.text);
    
    await FirestoreService.instance.updateProfile({
      'hasCompletedForm': true,
      'gender': _gender,
      'age': age,
      'height': height,
      'currentWeight': weight,
      'startedWeight': weight,
      'targetWeight': targetWeight,
      'activityFactor': _activityFactor,
    });
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  Future<void> _skipForm() async {
    setState(() => _isLoading = true);
    
    await FirestoreService.instance.updateProfile({
      'hasCompletedForm': true,
    });
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Let\'s get to know you!',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill out this form to calculate your fitness goals.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: _inputDecoration('Gender'),
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _gender = val!),
                ),
                const SizedBox(height: 16),
                
                // Age Field
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Age (years)'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                // Height Field
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Height (cm)'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                // Weight Field
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Weight (kg)'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                // Target Weight Field
                TextFormField(
                  controller: _targetWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Target Weight (kg)'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                // Activity Factor Dropdown
                DropdownButtonFormField<int>(
                  value: _activityFactor,
                  decoration: _inputDecoration('Activity Level (1-5 scale)'),
                  items: _activityFactors.map((a) {
                    String label = '';
                    switch(a) {
                      case 1: label = '1 - Sedentary'; break;
                      case 2: label = '2 - Lightly active'; break;
                      case 3: label = '3 - Moderately active'; break;
                      case 4: label = '4 - Very active'; break;
                      case 5: label = '5 - Extra active'; break;
                    }
                    return DropdownMenuItem(value: a, child: Text(label));
                  }).toList(),
                  onChanged: (val) => setState(() => _activityFactor = val!),
                ),
                const SizedBox(height: 48),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: AppTheme.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Save & Continue', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _skipForm,
                  child: Text('Skip for now', style: GoogleFonts.outfit(color: AppTheme.mediumGrey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.darkGrey),
      filled: true,
      fillColor: AppTheme.lightGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: const BorderSide(color: AppTheme.darkGrey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: const BorderSide(color: AppTheme.darkGrey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
    );
  }
}
