import 'package:flutter/material.dart';
import '../models/weight.dart';
import '../models/weight_goal.dart';
import '../models/animal.dart';
import '../services/weight_service.dart';
import '../services/animal_service.dart';
import '../widgets/weight/weight_entry_card.dart';
import '../widgets/weight/weight_history_list.dart';
import '../widgets/weight/weight_goal_card.dart';
import '../widgets/weight/weight_statistics_card.dart';
import '../widgets/responsive_scaffold.dart';
import '../theme/app_theme.dart';

/// Main screen for weight tracking functionality
/// Features tabbed interface for data entry, history, goals, and analytics
class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen>
    with TickerProviderStateMixin {
  final WeightService _weightService = WeightService();
  final AnimalService _animalService = AnimalService();
  
  late TabController _tabController;
  
  List<Weight> _weights = [];
  List<WeightGoal> _goals = [];
  List<Animal> _animals = [];
  
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;
  String? _selectedAnimalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all data concurrently
      final results = await Future.wait([
        _animalService.getAnimals(),
        _weightService.getWeights(),
        _weightService.getWeightGoals(),
      ]);

      if (mounted) {
        setState(() {
          _animals = results[0] as List<Animal>;
          _weights = results[1] as List<Weight>;
          _goals = results[2] as List<WeightGoal>;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: ${e.toString()}';
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<void> _addWeight(Weight weight) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newWeight = await _weightService.createWeight(weight);
      setState(() {
        _weights.insert(0, newWeight);
        _isLoading = false;
      });
      
      _showSnackBar('Weight recorded successfully', isSuccess: true);
      
      // Switch to history tab to show the new entry
      _tabController.animateTo(1);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to record weight: ${e.toString()}', isSuccess: false);
    }
  }

  Future<void> _updateWeight(Weight weight) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedWeight = await _weightService.updateWeight(weight);
      setState(() {
        final index = _weights.indexWhere((w) => w.id == updatedWeight.id);
        if (index != -1) {
          _weights[index] = updatedWeight;
        }
        _isLoading = false;
      });
      
      _showSnackBar('Weight updated successfully', isSuccess: true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to update weight: ${e.toString()}', isSuccess: false);
    }
  }

  Future<void> _deleteWeight(String weightId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _weightService.deleteWeight(weightId);
      setState(() {
        _weights.removeWhere((w) => w.id == weightId);
        _isLoading = false;
      });
      
      _showSnackBar('Weight deleted successfully', isSuccess: true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to delete weight: ${e.toString()}', isSuccess: false);
    }
  }

  Future<void> _addGoal(WeightGoal goal) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newGoal = await _weightService.createWeightGoal(goal);
      setState(() {
        _goals.add(newGoal);
        _isLoading = false;
      });
      
      _showSnackBar('Goal created successfully', isSuccess: true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to create goal: ${e.toString()}', isSuccess: false);
    }
  }

  Future<void> _updateGoal(WeightGoal goal) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedGoal = await _weightService.updateWeightGoal(goal);
      setState(() {
        final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
        if (index != -1) {
          _goals[index] = updatedGoal;
        }
        _isLoading = false;
      });
      
      _showSnackBar('Goal updated successfully', isSuccess: true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to update goal: ${e.toString()}', isSuccess: false);
    }
  }

  Future<void> _deleteGoal(String goalId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _weightService.deleteWeightGoal(goalId);
      setState(() {
        _goals.removeWhere((g) => g.id == goalId);
        _isLoading = false;
      });
      
      _showSnackBar('Goal deleted successfully', isSuccess: true);
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to delete goal: ${e.toString()}', isSuccess: false);
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showWeightDetails() {
    // Navigate to detailed weight analytics screen
    // This would be implemented as a separate screen
    _showSnackBar('Weight analytics details coming soon!', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    // Handle initial loading
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Weight Tracker'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading weight data...'),
            ],
          ),
        ),
      );
    }

    // Handle error state
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Weight Tracker'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Data',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Handle no animals state
    if (_animals.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Weight Tracker'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pets_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Animals Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add an animal first to start tracking weights',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to add animal screen
                    Navigator.pushNamed(context, '/animals/create');
                  },
                  child: const Text('Add Animal'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Weight Tracker'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showSnackBar('Export feature coming soon!', isSuccess: true);
                  break;
                case 'settings':
                  _showSnackBar('Settings feature coming soon!', isSuccess: true);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle),
              text: 'Record',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
            Tab(
              icon: Icon(Icons.flag),
              text: 'Goals',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Record Weight Tab
          RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  WeightEntryCard(
                    animals: _animals,
                    onWeightAdded: _addWeight,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  // Quick stats card for this tab
                  if (_weights.isNotEmpty)
                    WeightStatisticsCard(
                      weights: _weights,
                      goals: _goals,
                      animals: _animals,
                      onViewDetails: _showWeightDetails,
                      selectedAnimalId: _selectedAnimalId,
                    ),
                ],
              ),
            ),
          ),

          // History Tab
          RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: WeightHistoryList(
                weights: _weights,
                animals: _animals,
                onEditWeight: _updateWeight,
                onDeleteWeight: _deleteWeight,
                isLoading: _isLoading,
                selectedAnimalId: _selectedAnimalId,
              ),
            ),
          ),

          // Goals Tab
          RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: WeightGoalCard(
                goals: _goals,
                animals: _animals,
                onGoalAdded: _addGoal,
                onGoalUpdated: _updateGoal,
                onGoalDeleted: _deleteGoal,
                isLoading: _isLoading,
              ),
            ),
          ),

          // Analytics Tab
          RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  WeightStatisticsCard(
                    weights: _weights,
                    goals: _goals,
                    animals: _animals,
                    onViewDetails: _showWeightDetails,
                    selectedAnimalId: _selectedAnimalId,
                  ),
                  const SizedBox(height: 16),
                  
                  // Additional analytics widgets could go here
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.insights,
                                  color: AppTheme.accentBlue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Advanced Analytics',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Coming Soon: Weight trend charts, feeding efficiency analysis, and predictive modeling.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              _showSnackBar('Advanced features in development!', isSuccess: true);
                            },
                            child: const Text('Request Feature'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
          ? null  // Don't show FAB on record tab since it has its own form
          : FloatingActionButton(
              onPressed: () {
                // Switch to record tab
                _tabController.animateTo(0);
              },
              tooltip: 'Record Weight',
              child: const Icon(Icons.add),
            ),
    );
  }
}