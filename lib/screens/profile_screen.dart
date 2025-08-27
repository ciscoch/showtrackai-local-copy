import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/ffa_constants.dart';

/// Comprehensive profile screen for ShowTrackAI
/// Displays user information, FFA membership details, livestock statistics, and account settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _profileData = {};
  Map<String, dynamic> _statistics = {};
  
  // Form controllers for editable fields
  final _nameController = TextEditingController();
  final _chapterController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadProfileData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _chapterController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProfileData() async {
    try {
      setState(() => _isLoading = true);
      
      // Check if we should use demo data
      if (_authService.isDemoMode || (!_authService.isAuthenticated)) {
        print('⚠️ Using demo mode or not authenticated, loading demo data');
        _loadDemoProfileData();
        return;
      }
      
      // Load profile data and statistics using ProfileService
      final results = await Future.wait([
        _profileService.getProfileData(),
        _profileService.getUserStatistics(),
      ]);
      
      setState(() {
        _profileData = results[0];
        _statistics = results[1];
        
        _nameController.text = _profileData['name'] ?? '';
        _chapterController.text = _profileData['chapter'] ?? '';
        _bioController.text = _profileData['bio'] ?? '';
        _phoneController.text = _profileData['phone'] ?? '';
        
        _isLoading = false;
      });
      
      // Start fade animation once data is loaded
      _animationController.forward();
    } catch (e) {
      print('Error loading profile: $e');
      // Fallback to demo data on error
      _loadDemoProfileData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Using demo profile data'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    }
  }
  
  /// Load demo profile data when services aren't available
  void _loadDemoProfileData() {
    setState(() {
      _profileData = {
        'name': 'Demo Student',
        'email': 'demo@showtrackai.com',
        'chapter': 'Demo FFA Chapter',
        'degree': 'Chapter FFA Degree',
        'years_active': 2,
        'state': 'Demo State',
        'bio': 'This is a demo profile showing how ShowTrackAI works.',
        'phone': '(555) 123-4567',
        'joined_date': '2023-08-01T00:00:00Z',
      };
      
      _statistics = {
        'total_animals': 5,
        'active_projects': 3,
        'journal_entries': 12,
        'health_records': 8,
        'current_shows': 2,
        'achievements': 4,
      };
      
      _nameController.text = _profileData['name'] ?? '';
      _chapterController.text = _profileData['chapter'] ?? '';
      _bioController.text = _profileData['bio'] ?? '';
      _phoneController.text = _profileData['phone'] ?? '';
      
      _isLoading = false;
    });
    
    _animationController.forward();
  }
  

  

  
  Future<void> _saveProfile() async {
    // Validate form data
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }
    
    try {
      setState(() => _isSaving = true);
      
      // Prepare profile update data
      final updateData = {
        'name': _nameController.text.trim(),
        'chapter': _chapterController.text.trim(),
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'degree': _profileData['degree'],
        'years_active': _profileData['years_active'],
        'state': _profileData['state'],
      };
      
      await _profileService.updateProfile(updateData);
      
      setState(() {
        _isEditing = false;
        _isSaving = false;
        _profileData['name'] = _nameController.text.trim();
        _profileData['chapter'] = _chapterController.text.trim();
        _profileData['bio'] = _bioController.text.trim();
        _profileData['phone'] = _phoneController.text.trim();
      });
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error saving profile: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }
  
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSettingsSheet(),
    );
  }
  
  Widget _buildSettingsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings/notifications');
            },
          ),
          _buildSettingTile(
            icon: Icons.lock,
            title: 'Privacy & Security',
            subtitle: 'Manage your privacy settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings/privacy');
            },
          ),
          _buildSettingTile(
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help with ShowTrackAI',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/help');
            },
          ),
          _buildSettingTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about');
            },
          ),
          const Divider(),
          _buildSettingTile(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            iconColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryGreen),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              ),
              SizedBox(height: 16),
              Text(
                'Loading Profile...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
            // Custom App Bar with Profile Header
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppTheme.primaryGreen,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (!_isEditing && !_authService.isDemoMode)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isEditing = true);
                    },
                  ),
                if (_authService.isDemoMode)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DEMO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showSettingsMenu();
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60), // Account for app bar
                      // Profile Picture
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: _profileData['profile_picture'] != null
                                ? ClipOval(
                                    child: Image.network(
                                      _profileData['profile_picture'],
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppTheme.primaryGreen,
                                  ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Name
                      if (_isEditing)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Your Name',
                              hintStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          _profileData['name'] ?? 'FFA Student',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Email
                      Text(
                        _profileData['email'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Profile Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Edit Actions (when editing)
                    if (_isEditing)
                      Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Editing Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _isSaving ? null : () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _isEditing = false;
                                    _nameController.text = _profileData['name'] ?? '';
                                    _chapterController.text = _profileData['chapter'] ?? '';
                                    _bioController.text = _profileData['bio'] ?? '';
                                    _phoneController.text = _profileData['phone'] ?? '';
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isSaving ? null : () {
                                  HapticFeedback.mediumImpact();
                                  _saveProfile();
                                },
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // FFA Membership Card
                    Card(
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
                                const Icon(
                                  Icons.agriculture,
                                  color: AppTheme.primaryGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'FFA Membership',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow('Chapter', 
                              _isEditing 
                                ? Expanded(
                                    child: TextField(
                                      controller: _chapterController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter your FFA chapter name',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.grey[300]!),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _profileData['chapter'] ?? 'Not set',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Degree', 
                              DropdownButton<String>(
                                value: _profileData['degree'] ?? FFAConstants.degreeTypes[1],
                                items: FFAConstants.degreeTypes
                                    .map((degree) => DropdownMenuItem(
                                          value: degree,
                                          child: Text(degree),
                                        ))
                                    .toList(),
                                onChanged: _isEditing
                                    ? (value) {
                                        setState(() {
                                          _profileData['degree'] = value;
                                        });
                                      }
                                    : null,
                                underline: Container(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Years Active', Text(
                              '${_profileData['years_active'] ?? 1} year${(_profileData['years_active'] ?? 1) != 1 ? 's' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            )),
                            const SizedBox(height: 12),
                            _buildInfoRow('State', Text(
                              _profileData['state'] ?? 'Not set',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            )),
                            if (_isEditing) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow('Bio', 
                                Expanded(
                                  child: TextField(
                                    controller: _bioController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Tell us about your agricultural interests...',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow('Phone', 
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: '(555) 123-4567',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (_profileData['bio'] != null && _profileData['bio'].isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow('Bio', Text(
                                _profileData['bio'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Livestock Statistics
                    const Text(
                      'Livestock Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Statistics Grid - Responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        int crossAxisCount = screenWidth > 600 ? 3 : 2;
                        double childAspectRatio = screenWidth > 600 ? 1.3 : 1.4;
                        
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStatCard(
                              'Animals',
                              _statistics['total_animals'] ?? 0,
                              Icons.pets,
                              AppTheme.accentBlue,
                              'View all animals',
                              '/animals',
                            ),
                            _buildStatCard(
                              'Projects',
                              _statistics['active_projects'] ?? 0,
                              Icons.folder,
                              AppTheme.primaryGreen,
                              'Manage projects',
                              '/projects',
                            ),
                            _buildStatCard(
                              'Journal Entries',
                              _statistics['journal_entries'] ?? 0,
                              Icons.book,
                              const Color(0xFF9C27B0),
                              'View journal entries',
                              '/journal',
                            ),
                            _buildStatCard(
                              'Health Records',
                              _statistics['health_records'] ?? 0,
                              Icons.health_and_safety,
                              AppTheme.accentOrange,
                              'View health records',
                              '/records',
                            ),
                            _buildStatCard(
                              'Shows',
                              _statistics['current_shows'] ?? 0,
                              Icons.emoji_events,
                              const Color(0xFFE91E63),
                              'View shows',
                              '/shows',
                            ),
                            _buildStatCard(
                              'Achievements',
                              _statistics['achievements'] ?? 0,
                              Icons.star,
                              const Color(0xFFFFC107),
                              'View achievements',
                              '/badges',
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Column(
                      children: [
                        _buildActionButton(
                          icon: Icons.download,
                          title: 'Export Data',
                          subtitle: 'Download your records',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Export feature coming soon')),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.share,
                          title: 'Share Profile',
                          subtitle: 'Share your FFA achievements',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share feature coming soon')),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.badge,
                          title: 'View Badges',
                          subtitle: 'See all earned badges',
                          onTap: () {
                            Navigator.pushNamed(context, '/badges');
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Member Since
                    Center(
                      child: Text(
                        'Member since ${_formatJoinDate(_profileData['joined_date'])}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }
  
  Widget _buildStatCard(
    String title, 
    int count, 
    IconData icon, 
    Color color, 
    String tooltip, 
    String route,
  ) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          
          // Show tooltip for demo mode
          if (_authService.isDemoMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Demo: $tooltip feature'),
                backgroundColor: AppTheme.accentOrange,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          
          // Navigate to respective section
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'stat_icon_$title',
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: count),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  String _formatJoinDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}