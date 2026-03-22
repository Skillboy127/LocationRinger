import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/location_zone.dart';
import '../services/location_manager.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RingerModeStatus _currentMode = RingerModeStatus.unknown;
  List<LocationZone> _zones = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadState();
  }

  Future<void> _checkPermissions() async {
    await Permission.locationAlways.request();
    await Permission.notification.request();
    await Permission.accessNotificationPolicy.request();
  }

  Future<void> _loadState() async {
    try {
      await _evaluateLocationNow();

      final mode = await SoundMode.ringerModeStatus;
      final zones = await LocationManager.getZones();
      setState(() {
        _currentMode = mode;
        _zones = zones;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _evaluateLocationNow() async {
    try {
      final zones = await LocationManager.getZones();
      bool isInsideZone = false;
      String targetMode = 'silent';

      if (zones.isNotEmpty) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        for (var zone in zones) {
          double distance = Geolocator.distanceBetween(
            position.latitude, position.longitude, zone.latitude, zone.longitude,
          );
          if (distance <= zone.radiusInMeters) {
            isInsideZone = true;
            targetMode = zone.targetMode;
            break;
          }
        }
      }

      RingerModeStatus currentMode = await SoundMode.ringerModeStatus;
      if (isInsideZone) {
        if (targetMode == 'vibrate' && currentMode != RingerModeStatus.vibrate) {
          await SoundMode.setSoundMode(RingerModeStatus.vibrate);
        } else if (targetMode == 'normal' && currentMode != RingerModeStatus.normal) {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
        }
      } else {
        if (currentMode == RingerModeStatus.vibrate || currentMode == RingerModeStatus.silent) {
          await SoundMode.setSoundMode(RingerModeStatus.normal);
        }
      }
    } catch (e) {
      print("Evaluation error: $e");
    }
  }

  void _showModeSelector(LocationZone zone) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151522),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Select Ringer Mode', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.vibration, color: Color(0xFFFFC04D)),
                title: const Text('Vibrate', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  await LocationManager.updateZone(LocationZone(id: zone.id, name: zone.name, latitude: zone.latitude, longitude: zone.longitude, radiusInMeters: zone.radiusInMeters, targetMode: 'vibrate'));
                  Navigator.pop(context);
                  _loadState();
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up, color: Color(0xFF42F5CE)),
                title: const Text('Normal (Ringer)', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  await LocationManager.updateZone(LocationZone(id: zone.id, name: zone.name, latitude: zone.latitude, longitude: zone.longitude, radiusInMeters: zone.radiusInMeters, targetMode: 'normal'));
                  Navigator.pop(context);
                  _loadState();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Location Ringer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Futuristic Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D15),
                  Color(0xFF1B1B2F),
                  Color(0xFF04101A),
                ],
              ),
            ),
          ),
          
          // Glowing Ambient Orbs (Abstract design)
          Positioned(
            top: -50,
            right: -50,
            child: _buildGlowingOrb(const Color(0xFF00E5FF), 150),
          ).animate().fade(duration: 1000.ms).scale(duration: 1500.ms, curve: Curves.easeOutBack),
          
          Positioned(
            bottom: -100,
            left: -50,
            child: _buildGlowingOrb(const Color(0xFFB388FF), 200),
          ).animate().fade(duration: 1000.ms).scale(duration: 1500.ms, curve: Curves.easeOutBack),

          // Main Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadState,
              color: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF151522),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildStatusCard().animate().slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic, duration: 600.ms).fade(),
                        const SizedBox(height: 30),
                        _buildSectionTitle('Active Silent Zones').animate().fadeIn(delay: 300.ms),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  _zones.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_off, size: 60, color: Colors.white24),
                                const SizedBox(height: 20),
                                Text(
                                  'No silent zones added yet.\nTap below to add your first smart zone.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16),
                                ),
                              ],
                            ).animate().fadeIn(delay: 500.ms),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildZoneItem(_zones[index], index)
                                  .animate(delay: Duration(milliseconds: 100 * index))
                                  .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic, duration: 500.ms)
                                  .fade();
                            },
                            childCount: _zones.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MapScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                var begin = const Offset(0.0, 1.0);
                var end = Offset.zero;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            ),
          );
          if (result == true) {
            _loadState();
          }
        },
        icon: const Icon(Icons.add_location_alt, color: Color(0xFF0D0D15)),
        label: Text('Add Zone', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0D0D15))),
        backgroundColor: const Color(0xFF00E5FF),
      ).animate().scale(delay: 500.ms, duration: 500.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildGlowingOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    String text;
    Color color;
    Color shadowColor;

    switch (_currentMode) {
      case RingerModeStatus.normal:
        icon = Icons.volume_up_rounded;
        text = 'Ringer';
        color = const Color(0xFF42F5CE); // Neon Mint
        shadowColor = const Color(0xFF42F5CE).withOpacity(0.4);
        break;
      case RingerModeStatus.silent:
        icon = Icons.volume_off_rounded;
        text = 'Silent';
        color = const Color(0xFFFF4D4D); // Neon Red
        shadowColor = const Color(0xFFFF4D4D).withOpacity(0.4);
        break;
      case RingerModeStatus.vibrate:
        icon = Icons.vibration_rounded;
        text = 'Vibrate';
        color = const Color(0xFFFFC04D); // Neon Orange
        shadowColor = const Color(0xFFFFC04D).withOpacity(0.4);
        break;
      default:
        icon = Icons.help_outline_rounded;
        text = 'Scanning...';
        color = Colors.white54;
        shadowColor = Colors.transparent;
    }

    return _GlassmorphicContainer(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      borderRadius: 24,
      borderColor: color.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              boxShadow: [
                BoxShadow(color: shadowColor, blurRadius: 20, spreadRadius: -5),
              ],
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text, 
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneItem(LocationZone zone, int index) {
    // Map target modes to nice display strings and colors
    String modeText = 'Vibrate';
    Color modeColor = const Color(0xFFFFC04D);
    if (zone.targetMode == 'normal') {
      modeText = 'Normal';
      modeColor = const Color(0xFF42F5CE);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _GlassmorphicContainer(
        borderRadius: 16,
        padding: const EdgeInsets.all(4),
        borderColor: Colors.white12,
        child: ListTile(
          onLongPress: () => _showModeSelector(zone),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.radar, color: modeColor),
          ),
          title: Text(zone.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Radius: ${zone.radiusInMeters.toInt()} meters', style: GoogleFonts.outfit(color: Colors.white60)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Mode: ', style: GoogleFonts.outfit(color: Colors.white60)),
                  Text(modeText, style: GoogleFonts.outfit(color: modeColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white30),
            onPressed: () async {
              await LocationManager.removeZone(zone.id);
              _loadState();
            },
          ),
        ),
      ),
    );
  }
}

// Reusable Glassmorphic Container
class _GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color borderColor;

  const _GlassmorphicContainer({
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 16,
    this.borderColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
