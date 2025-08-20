import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/location_input_field.dart';
import '../models/journal_entry.dart';

/// Financial Journal Card Widget
/// This card safely adds journal functionality to the existing ShowTrackAI dashboard
/// without modifying any existing functionality
class FinancialJournalCard extends StatefulWidget {
  const FinancialJournalCard({Key? key}) : super(key: key);

  @override
  State<FinancialJournalCard> createState() => _FinancialJournalCardState();
}

class _FinancialJournalCardState extends State<FinancialJournalCard> {
  JournalCardData _data = JournalCardData.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournalData();
  }

  Future<void> _loadJournalData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get journal statistics from database
      final response = await supabase.rpc('get_user_journal_stats', 
        params: {'user_uuid': user.id});

      if (response != null && response.isNotEmpty) {
        final stats = response[0];
        setState(() {
          _data = JournalCardData(
            totalEntries: stats['total_entries'] ?? 0,
            totalHours: (stats['total_hours'] ?? 0).toDouble(),
            streak: stats['current_streak'] ?? 0,
            averageScore: (stats['average_quality_score'] ?? 0).toDouble(),
            aetPoints: (stats['unique_skills_count'] ?? 0) * 5,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error loading journal data: $e
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openJournalModal(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.book,
                            color: Color(0xFF4CAF50),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Journal Entries',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Count and Score Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_data.totalEntries}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D3A),
                          ),
                        ),
                        if (_data.averageScore > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, 
                              vertical: 4
                            ),
                            decoration: BoxDecoration(
                              color: _getScoreColor(_data.averageScore).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_data.averageScore.toInt()}%',
                              style: TextStyle(
                                color: _getScoreColor(_data.averageScore),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatColumn(
                          icon: Icons.local_fire_department,
                          value: '${_data.streak}',
                          label: 'Streak',
                          color: _data.streak > 0 ? Colors.orange : Colors.grey,
                        ),
                        _StatColumn(
                          icon: Icons.trending_up,
                          value: '${_data.totalHours.toInt()}h',
                          label: 'Hours',
                          color: Colors.blue,
                        ),
                        _StatColumn(
                          icon: Icons.star,
                          value: '${_data.aetPoints}',
                          label: 'AET',
                          color: Colors.amber,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  void _openJournalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JournalEntryModal(),
    );
  }
}

/// Journal Entry Modal for creating new journal entries
class JournalEntryModal extends StatefulWidget {
  const JournalEntryModal({Key? key}) : super(key: key);

  @override
  State<JournalEntryModal> createState() => _JournalEntryModalState();
}

class _JournalEntryModalState extends State<JournalEntryModal> {
  final _entryController = TextEditingController();
  String? _selectedAnimalId;
  String _selectedAnimalType = 'cattle';
  bool _isSubmitting = false;
  List<Animal> _animals = [];
  LocationData? _locationData;
  WeatherData? _weatherData;

  // WORKING N8N ORCHESTRATOR ENDPOINT (TESTED ✅)
  static const String _orchestratorUrl = 
      'https://showtrackai.app.n8n.cloud/webhook/a9b86a3a-2baa-4485-8c86-8538202d7966';

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('animals')
          .select('id, name, species')
          .eq('user_id', user.id)
          .eq('status', 'active');

      setState(() {
        _animals = (response as List).map((e) => Animal.fromJson(e)).toList();
        if (_animals.isNotEmpty) {
          _selectedAnimalId = _animals.first.id;
          _selectedAnimalType = _animals.first.species;
        }
      });
    } catch (e) {
      // Error loading animals: $e
    }
  }

  @override
  Widget build(BuildContext context) {
    // JournalEntryModal.build() called - animals loaded: ${_animals.length}
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Quick Journal Entry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSubmitting ? null : _submitToN8NOrchestrator,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
                // Quick access to full form
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Need more features? Use the green + button for the full journal form with AET skills and advanced options.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/journal/new');
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text('Full Form', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Animal Selection
                if (_animals.isNotEmpty) ...[
                  const Text(
                    'Select Animal',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedAnimalId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _animals.map((animal) {
                      return DropdownMenuItem(
                        value: animal.id,
                        child: Text('${animal.name} (${animal.species})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAnimalId = value;
                        final animal = _animals.firstWhere((a) => a.id == value);
                        _selectedAnimalType = animal.species;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Location & Weather Section
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: LocationInputField(
                    onLocationChanged: (location, weather) {
                      // Modal location changed: $location, $weather
                      setState(() {
                        _locationData = location;
                        _weatherData = weather;
                      });
                    },
                    initialLocation: _locationData,
                    initialWeather: _weatherData,
                  ),
                ),
                const SizedBox(height: 16),

                // Entry Text
                const Text(
                  'Today\'s Journal Entry',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _entryController,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: 'Describe your activities with the animal today. Include details about feeding, health observations, training progress, financial costs, or any challenges you encountered...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🤖 AI-Enhanced Processing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D3A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your entry will be analyzed by AI for educational content, FFA standards alignment, and financial insights. You\'ll receive a quality score and personalized recommendations.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitToN8NOrchestrator() async {
    if (_entryController.text.trim().isEmpty || _selectedAnimalId == null) {
      _showError('Please fill in all required fields');
      return;
    }

    if (_entryController.text.trim().length < 50) {
      _showError('Entry must be at least 50 characters long');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare payload for N8N Orchestrator
      final payload = {
        'domain': 'journaling',
        'action': 'journal_analysis',
        'userId': user.id,
        'animalId': _selectedAnimalId,
        'entryText': _entryController.text.trim(),
        'entryDate': DateTime.now().toIso8601String(),
        'animalType': _selectedAnimalType,
        'location': _locationData?.toJson(),
        'weather': _weatherData?.toJson(),
        'photos': [],
        'requestId': 'journal_${DateTime.now().millisecondsSinceEpoch}_${user.id.substring(0, 8)}',
      };

      // Submitting to N8N Orchestrator: $_orchestratorUrl

      // Call N8N Main Orchestrator
      final response = await http.post(
        Uri.parse(_orchestratorUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // N8N Response: ${response.statusCode} - ${response.body}

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (mounted) {
          Navigator.pop(context);
          _showSuccessDialog(result);
        }
      } else {
        throw Exception('N8N workflow failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Error submitting to N8N: $e
      if (mounted) {
        _showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 Journal Submitted!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Successfully sent to N8N workflow'),
            const SizedBox(height: 8),
            Text('Status: ${result['message'] ?? 'Processing started'}'),
            const SizedBox(height: 8),
            const Text(
              'Your entry is being processed by AI and will be stored with educational metadata. Check back in a few minutes for quality scores and recommendations!',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }
}

// Supporting Classes
class JournalCardData {
  final int totalEntries;
  final double totalHours;
  final int streak;
  final double averageScore;
  final int aetPoints;

  JournalCardData({
    required this.totalEntries,
    required this.totalHours,
    required this.streak,
    required this.averageScore,
    required this.aetPoints,
  });

  factory JournalCardData.empty() => JournalCardData(
    totalEntries: 0,
    totalHours: 0,
    streak: 0,
    averageScore: 0,
    aetPoints: 0,
  );
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class Animal {
  final String id;
  final String name;
  final String species;

  Animal({
    required this.id,
    required this.name,
    required this.species,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'],
      name: json['name'],
      species: json['species'],
    );
  }
}