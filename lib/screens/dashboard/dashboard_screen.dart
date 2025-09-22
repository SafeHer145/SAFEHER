import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../services/sms_service_simple.dart';
import '../../services/location_service.dart';
import '../contacts/contacts_screen.dart';
import '../alerts/alerts_history_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  
  const DashboardScreen({
    super.key,
    required this.userId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final SMSServiceSimple _smsService = SMSServiceSimple();
  final LocationService _locationService = LocationService();
  
  late AnimationController _sosAnimationController;
  late Animation<double> _sosAnimation;
  
  bool _isSOSPressed = false;
  final bool _isEmergencyMode = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
  }

  void _initializeAnimations() {
    _sosAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _sosAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _sosAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start pulsing animation
    _sosAnimationController.repeat(reverse: true);
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'SafeHer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _navigateToProfile(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showSignOutDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              _buildWelcomeCard(),
              
              const SizedBox(height: 24),
              
              // SOS Button
              _buildSOSButton(),
              
              const SizedBox(height: 32),
              
              // Quick Actions
              _buildQuickActions(),
              
              const SizedBox(height: 24),
              
              // Safety Tips
              _buildSafetyTips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userProfile?['name'] ?? 'SafeHer User',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are protected. Stay safe!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Center(
        child: Column(
          children: [
            Text(
              'Emergency SOS',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _sosAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _sosAnimation.value,
                  child: GestureDetector(
                    onTap: _isSOSPressed ? null : _handleSOSPress,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSOSPressed ? Colors.red[800] : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSOSPressed
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.emergency,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'SOS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Press and hold to send emergency alert',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Emergency Contacts',
                  subtitle: 'Manage contacts',
                  icon: Icons.contacts,
                  color: Colors.blue,
                  onTap: () => _navigateToContacts(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Alert History',
                  subtitle: 'View past alerts',
                  icon: Icons.history,
                  color: Colors.orange,
                  onTap: () => _navigateToHistory(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyTips() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1200),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Safety Tips',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSafetyTip('Always inform someone about your whereabouts'),
              _buildSafetyTip('Keep your emergency contacts updated'),
              _buildSafetyTip('Trust your instincts in unsafe situations'),
              _buildSafetyTip('Practice using the SOS button regularly'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSOSPress() async {
    try {
      // Haptic feedback
      HapticFeedback.heavyImpact();
      
      setState(() {
        _isSOSPressed = true;
      });

      // Request permissions
      await _requestPermissions();

      // Get current location
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Send emergency alert
      await _smsService.sendEmergencyAlert(widget.userId, position);

      if (mounted) {
        setState(() {
          _isSOSPressed = false;
        });

        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSOSPressed = false;
        });

        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request location permission
    var locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      throw Exception('Location permission is required for emergency alerts');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('SOS Sent'),
          ],
        ),
        content: const Text(
          'Emergency alert has been sent to all your verified contacts with your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactsScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertsHistoryScreen(userId: widget.userId),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: widget.userId),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sosAnimationController.dispose();
    super.dispose();
  }
}
