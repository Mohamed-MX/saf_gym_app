import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/saf_database.dart';
import '../theme/app_theme.dart';

class PerformanceDashboardScreen extends StatefulWidget {
  const PerformanceDashboardScreen({super.key});

  @override
  State<PerformanceDashboardScreen> createState() => _PerformanceDashboardScreenState();
}

class _PerformanceDashboardScreenState extends State<PerformanceDashboardScreen> {
  String _filter = 'weekly'; // daily, weekly, monthly, yearly
  bool _isLoading = true;
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];

  // Stats
  int _totalReps = 0;
  int _workoutsStarted = 0;
  int _exercisesDone = 0;
  int _totalTimeSeconds = 0;
  double _totalWeightLifted = 0.0;
  List<_SessionData> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _allLogs = await SafDatabase.instance.getPerformanceLogs();
    _applyFilter();
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime cutoff;

    if (_filter == 'daily') {
      cutoff = DateTime(now.year, now.month, now.day);
    } else if (_filter == 'weekly') {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_filter == 'monthly') {
      cutoff = DateTime(now.year, now.month - 1, now.day);
    } else { // yearly
      cutoff = DateTime(now.year - 1, now.month, now.day);
    }

    _filteredLogs = _allLogs.where((log) {
      final dt = DateTime.fromMillisecondsSinceEpoch(log['date_time']);
      return dt.isAfter(cutoff);
    }).toList();

    _calculateStats();
    setState(() => _isLoading = false);
  }

  void _calculateStats() {
    _totalReps = 0;
    _workoutsStarted = 0;
    _exercisesDone = 0;
    _totalTimeSeconds = 0;
    _totalWeightLifted = 0.0;
    _sessions.clear();

    final Map<int, _SessionData> sessionMap = {};
    final Set<String> uniqueExercises = {};

    for (var log in _filteredLogs) {
      final sessionId = log['session_id'] as int? ?? 0;
      final reps = log['reps'] as int;
      final exName = log['exercise_name'] as String;
      final workoutName = log['workout_name'] as String;
      final timeTaken = log['time_taken_seconds'] as int? ?? 0;
      final weight = (log['weight'] as num?)?.toDouble() ?? 0.0;
      final dt = DateTime.fromMillisecondsSinceEpoch(log['date_time']);
      
      _totalReps += reps;
      _totalTimeSeconds += timeTaken;
      _totalWeightLifted += (reps * weight);
      uniqueExercises.add(exName);

      // Use sessionId as grouping key. Fallback to daily grouping if 0.
      int effectiveSessionId = sessionId;
      if (effectiveSessionId == 0) {
        effectiveSessionId = DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      }

      if (!sessionMap.containsKey(effectiveSessionId)) {
        sessionMap[effectiveSessionId] = _SessionData(
          sessionId: effectiveSessionId,
          workoutName: workoutName,
          date: DateTime.fromMillisecondsSinceEpoch(
            effectiveSessionId == 0 ? dt.millisecondsSinceEpoch : effectiveSessionId
          ),
        );
      }

      final session = sessionMap[effectiveSessionId]!;
      session.totalTimeSeconds += timeTaken;
      session.totalWeightLifted += (reps * weight);
      if (weight > session.maxWeight) {
        session.maxWeight = weight;
      }

      // Find or create exercise in session
      _ExerciseLogData? exData;
      for (var e in session.exercises) {
        if (e.name == exName) {
          exData = e;
          break;
        }
      }
      if (exData == null) {
        exData = _ExerciseLogData(name: exName, timestamp: dt);
        session.exercises.add(exData);
      }

      exData.sets += 1;
      exData.reps += reps;
      exData.timeTakenSeconds += timeTaken;
      exData.weights.add(weight);
      
      // Update timestamp to the earliest set's timestamp
      if (dt.isBefore(exData.timestamp)) {
        exData.timestamp = dt; 
      }
    }

    _sessions = sessionMap.values.toList();
    _sessions.sort((a, b) => b.date.compareTo(a.date)); // newest first

    _workoutsStarted = _sessions.length;
    _exercisesDone = uniqueExercises.length;
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return "${seconds}s";
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "${h}h ${m}m";
    final s = seconds % 60;
    return "${m}m ${s}s";
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$h:$m, ${dt.day}/${dt.month}/${dt.year}";
  }

  Future<void> _exportData() async {
    final pdf = pw.Document();
    
    // Prepare chart data for PDF
    final chartData = _sessions.reversed.toList();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Performance Metrics ($_filter)", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text("Total Reps: $_totalReps"),
              pw.Text("Workouts Started: $_workoutsStarted"),
              pw.Text("Exercises Done: $_exercisesDone"),
              pw.Text("Total Weight Lifted: ${_totalWeightLifted.toStringAsFixed(1)} kg"),
              pw.Text("Total Time Spent: ${_formatTime(_totalTimeSeconds)}"),
              pw.SizedBox(height: 20),
              pw.Text("Workout Sessions:", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ..._sessions.map((session) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("${session.workoutName} - ${_formatDateTime(session.date)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Total Time: ${_formatTime(session.totalTimeSeconds)} | Weight Lifted: ${session.totalWeightLifted.toStringAsFixed(1)} kg"),
                      pw.Text("Max Weight: ${session.maxWeight} kg", style: pw.TextStyle(color: PdfColors.blueGrey)),
                      pw.SizedBox(height: 4),
                      ...session.exercises.map((ex) {
                        final maxW = ex.weights.isEmpty ? 0 : ex.weights.reduce((a, b) => a > b ? a : b);
                        return pw.Text("  - ${ex.name}: ${ex.sets} sets, ${ex.reps} reps (Max Weight: $maxW kg)");
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );

    // Add Graph Page
    if (chartData.isNotEmpty) {
      final double maxVal = chartData.fold<double>(0.0, (m, e) => m > e.maxWeight ? m : e.maxWeight);
      final double yMax = maxVal == 0 ? 10.0 : maxVal * 1.2;
      
      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Column(
              children: [
                pw.Text("Weight Progression (Max kg per session)", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Chart(
                    grid: pw.CartesianGrid(
                      xAxis: pw.FixedAxis(
                        chartData.map((e) => e.date.millisecondsSinceEpoch.toDouble()).toList(),
                        format: (v) => DateTime.fromMillisecondsSinceEpoch(v.toInt()).day.toString(),
                        ticks: true,
                      ),
                      yAxis: pw.FixedAxis(
                        List.generate(6, (i) => (yMax / 5) * i),
                        format: (v) => v.toInt().toString(),
                        ticks: true,
                      ),
                    ),
                    datasets: [
                      pw.LineDataSet(
                        data: List.generate(chartData.length, (i) {
                          return pw.PointChartValue(chartData[i].date.millisecondsSinceEpoch.toDouble(), chartData[i].maxWeight);
                        }),
                        color: PdfColors.blue,
                        lineWidth: 2,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        )
      );
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/performance_$_filter.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'My Performance PDF Report',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Performance Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.offWhite,
        foregroundColor: AppTheme.charcoal,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['daily', 'weekly', 'monthly', 'yearly'].map((f) {
                        final isSelected = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              f[0].toUpperCase() + f.substring(1),
                              style: TextStyle(
                                color: isSelected ? AppTheme.white : AppTheme.charcoal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryBlue,
                            backgroundColor: AppTheme.lightGrey,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _filter = f;
                                  _applyFilter();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Export Button
                  ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: Text('Export PDF', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.charcoal,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // UI Graph
                  if (_sessions.isNotEmpty) ...[
                    Text(
                      'Max Weight Progression (kg)',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide for simplicity
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(_sessions.length, (i) {
                                // Reverse sessions for chronological order
                                final reversedIndex = _sessions.length - 1 - i;
                                return FlSpot(i.toDouble(), _sessions[reversedIndex].maxWeight);
                              }),
                              isCurved: true,
                              color: AppTheme.primaryBlue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Exercise List
                  Text(
                    'Workout Sessions',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 12),
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No workouts logged in this time frame.', style: TextStyle(color: AppTheme.mediumGrey))),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                              final session = _sessions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                color: AppTheme.white,
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text(
                                      session.workoutName,
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                    subtitle: Text(
                                      "${_formatDateTime(session.date)}  •  ${_formatTime(session.totalTimeSeconds)}",
                                      style: const TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
                                    ),
                                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    children: session.exercises.map((ex) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(ex.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                                                  const SizedBox(height: 2),
                                                  Text(_formatDateTime(ex.timestamp), style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
                                                ],
                                              ),
                                            ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text("${ex.sets} Sets / ${ex.reps} Reps", style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryBlue, fontSize: 13)),
                                                  const SizedBox(height: 2),
                                                  Text("Max Weight: ${ex.weights.isEmpty ? 0 : ex.weights.reduce((a, b) => a > b ? a : b)} kg", style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 2),
                                                  Text(_formatTime(ex.timeTakenSeconds), style: const TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
                                                ],
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),

                  // Summary Stats below
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Summary ($_filter)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.white)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(child: _SummaryItem(label: 'Reps', value: '$_totalReps')),
                            Expanded(child: _SummaryItem(label: 'Workouts', value: '$_workoutsStarted')),
                            Expanded(child: _SummaryItem(label: 'Time Spent', value: _formatTime(_totalTimeSeconds))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _SessionData {
  final int sessionId;
  final String workoutName;
  final DateTime date;
  int totalTimeSeconds = 0;
  double totalWeightLifted = 0.0;
  double maxWeight = 0.0;
  List<_ExerciseLogData> exercises = [];

  _SessionData({
    required this.sessionId,
    required this.workoutName,
    required this.date,
  });
}

class _ExerciseLogData {
  final String name;
  DateTime timestamp;
  int timeTakenSeconds = 0;
  int reps = 0;
  int sets = 0;
  List<double> weights = [];

  _ExerciseLogData({
    required this.name,
    required this.timestamp,
  });
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
