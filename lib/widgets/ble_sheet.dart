import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ble/ble_manager.dart';
import '../theme/app_theme.dart';

/// Shared BLE connection bottom sheet used by HomeScreen and WorkoutSessionScreen.
class BleConnectionSheet extends StatefulWidget {
  final BleManager bleManager;
  final bool isConnected;
  final ValueChanged<bool> onConnectionChanged;

  const BleConnectionSheet({
    super.key,
    required this.bleManager,
    required this.isConnected,
    required this.onConnectionChanged,
  });

  @override
  State<BleConnectionSheet> createState() => _BleConnectionSheetState();
}

class _BleConnectionSheetState extends State<BleConnectionSheet> {
  bool _isScanning = false;
  bool _isConnecting = false;
  final List<ScanResult> _scanResults = [];

  // Diagnostic live state
  String _lastRaw = '';
  int _packetCount = 0;
  StreamSubscription<String>? _rawSub;

  @override
  void initState() {
    super.initState();
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
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });

    // Subscribe to live raw data stream for diagnostics
    _rawSub = widget.bleManager.rawDataStream.listen((raw) {
      if (mounted) {
        setState(() {
          _lastRaw = raw;
          _packetCount = widget.bleManager.packetCount;
        });
      }
    });

    // Seed with existing values if already receiving data
    _lastRaw = widget.bleManager.lastRawPacket;
    _packetCount = widget.bleManager.packetCount;
  }

  @override
  void dispose() {
    _rawSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    setState(() => _isConnecting = true);
    try {
      await FlutterBluePlus.stopScan();
      await widget.bleManager.connectToDevice(device);
      widget.onConnectionChanged(widget.bleManager.isConnected);
      if (mounted) setState(() {}); // refresh diagnostic panel
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
    await widget.bleManager.disconnect();
    widget.onConnectionChanged(false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bm = widget.bleManager;
    final isConnected = bm.isConnected;
    final physicallyLinked = bm.discoveredServices.isNotEmpty || isConnected;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.greenAccent.withValues(alpha: 0.15)
                        : AppTheme.primaryBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_searching_rounded,
                    color: isConnected
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
                      isConnected
                          ? '${bm.connectedDeviceName} — data flowing'
                          : physicallyLinked
                              ? '${bm.connectedDeviceName} — UUID mismatch'
                              : 'Find & connect your sensor',
                      style: TextStyle(
                        fontSize: 13,
                        color: isConnected
                            ? Colors.greenAccent
                            : physicallyLinked
                                ? Colors.orangeAccent
                                : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── DIAGNOSTIC PANEL (shown once a device is physically linked) ──
            if (physicallyLinked) ...[
              _DiagnosticPanel(
                bleManager: bm,
                lastRaw: _lastRaw,
                packetCount: _packetCount,
              ),
              const SizedBox(height: 16),
            ],

            // ── Disconnect / Scan ──────────────────────────────────
            if (isConnected || physicallyLinked) ...[
              _BleActionButton(
                label: 'Disconnect',
                icon: Icons.bluetooth_disabled_rounded,
                color: Colors.redAccent,
                onTap: _disconnect,
              ),
            ] else ...[
              _BleActionButton(
                label: _isScanning ? 'Scanning…' : 'Scan for Devices',
                icon: _isScanning ? Icons.radar_rounded : Icons.search_rounded,
                color: AppTheme.primaryBlue,
                onTap: _isScanning ? null : _startScan,
                loading: _isScanning,
              ),
              const SizedBox(height: 16),

              if (_scanResults.isEmpty && !_isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No devices found. Tap Scan to search.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _scanResults.length,
                    separatorBuilder: (_, i) => const Divider(
                      color: Colors.white10,
                      height: 1,
                    ),
                    itemBuilder: (_, i) {
                      final r = _scanResults[i];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : r.device.remoteId.str;
                      final isSensor = name.contains('SmartGymSensor');
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
                            color:
                                isSensor ? AppTheme.accentBlue : Colors.white38,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSensor ? AppTheme.white : Colors.white60,
                          ),
                        ),
                        subtitle: Text(
                          'RSSI: ${r.rssi} dBm',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38),
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
      ),
    );
  }
}

// ── Diagnostic Panel ──────────────────────────────────────────────────────────

class _DiagnosticPanel extends StatelessWidget {
  final BleManager bleManager;
  final String lastRaw;
  final int packetCount;

  const _DiagnosticPanel({
    required this.bleManager,
    required this.lastRaw,
    required this.packetCount,
  });

  @override
  Widget build(BuildContext context) {
    final bm = bleManager;
    final dataOk = bm.charFound && packetCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(
                'DIAGNOSTICS',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status rows
          _StatusRow(
            label: 'Target Service UUID',
            value: bm.serviceFound ? 'FOUND ✓' : 'NOT FOUND ✗',
            ok: bm.serviceFound,
          ),
          _StatusRow(
            label: 'Target Char UUID',
            value: bm.charFound ? 'FOUND ✓' : 'NOT FOUND ✗',
            ok: bm.charFound,
          ),
          _StatusRow(
            label: 'Packets received',
            value: '$packetCount',
            ok: packetCount > 0,
          ),

          if (bm.charFound)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => bm.triggerManualRead(),
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Manual Read Test'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),

          // Last raw packet
          if (lastRaw.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'LAST PACKET',
              style: GoogleFonts.outfit(
                fontSize: 9,
                color: Colors.white30,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: lastRaw));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dataOk
                      ? Colors.greenAccent.withValues(alpha: 0.07)
                      : Colors.orangeAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dataOk
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.orangeAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  lastRaw,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          // ── All discovered services ─────────────────────────
          if (bm.discoveredServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'DISCOVERED SERVICES (${bm.discoveredServices.length})',
              style: GoogleFonts.outfit(
                fontSize: 9,
                color: Colors.white30,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            ...bm.discoveredServices.map((s) {
              final isTargetService = s.serviceUuid.toLowerCase() ==
                  serviceUUID.toString().toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service row
                    Row(
                      children: [
                        Icon(
                          isTargetService
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 12,
                          color: isTargetService
                              ? Colors.greenAccent
                              : Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.serviceUuid,
                            style: TextStyle(
                              fontSize: 10,
                              color: isTargetService
                                  ? Colors.greenAccent
                                  : Colors.white38,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (isTargetService)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TARGET',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    // Characteristics
                    ...s.characteristics.map((c) {
                      final isTargetChar = c.isTarget;
                      return Padding(
                        padding: const EdgeInsets.only(left: 18, top: 3),
                        child: Row(
                          children: [
                            Icon(
                              isTargetChar
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded,
                              size: 10,
                              color: isTargetChar
                                  ? Colors.greenAccent
                                  : Colors.white24,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                c.charUuid,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isTargetChar
                                      ? Colors.greenAccent
                                      : Colors.white30,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (c.canNotify)
                              const _Tag('NOTIFY', Colors.blueAccent),
                            if (c.canRead)
                              const _Tag('READ', Colors.white38),
                            if (isTargetChar)
                              const _Tag('TARGET', Colors.greenAccent),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

            // Show expected UUIDs for easy comparison
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPECTED (in firmware)',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: Colors.blueAccent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Svc: ${serviceUUID.toString()}',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white54,
                        fontFamily: 'monospace'),
                  ),
                  SelectableText(
                    'Chr: ${charUUID.toString()}',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white54,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  const _StatusRow({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ok ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 7,
          color: color,
          fontWeight: FontWeight.bold,
        ),
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
