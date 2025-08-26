import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animal.dart';
import '../services/animal_service.dart';
import '../services/auth_service.dart';
import '../services/coppa_service.dart';
import '../widgets/responsive_scaffold.dart';
import 'animal_create_screen.dart';
import 'animal_detail_screen.dart';

class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({Key? key}) : super(key: key);

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> with NavigationHandler {
  final _animalService = AnimalService();
  final _authService = AuthService();
  final _coppaService = CoppaService();
  final _searchController = TextEditingController();
  
  List<Animal> _animals = [];
  List<Animal> _filteredAnimals = [];
  bool _isLoading = true;
  String _searchQuery = '';
  AnimalSpecies? _filterSpecies;
  bool _isOffline = false;
  CoppaStatus? _coppaStatus;
  
  @override
  void initState() {
    super.initState();
    _loadAnimals();
    _checkCoppaStatus();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _checkCoppaStatus() async {
    if (_authService.currentUser != null) {
      final status = await _coppaService.getUserCoppaStatus(_authService.currentUser!.id);
      if (mounted) {
        setState(() {
          _coppaStatus = status;
        });
      }
    }
  }
  
  bool get _canAccessAnimalManagement {
    return _coppaStatus?.isCompliant ?? true ||
           _coppaService.canAccessFeature(
             coppaStatus: _coppaStatus ?? const CoppaStatus(
               isMinor: false,
               age: 18,
               requiresConsent: false,
               hasConsent: false,
             ),
             feature: CoppaFeature.animalManagement,
           );
  }
  
  Future<void> _loadAnimals() async {
    if (!_canAccessAnimalManagement) return;
    
    setState(() => _isLoading = true);
    
    try {
      final animals = await _animalService.getAnimals();
      if (mounted) {
        setState(() {
          _animals = animals;
          _filterAnimals();
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load animals: ${e.toString()}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadAnimals,
            ),
          ),
        );
      }
    }
  }
  
  void _filterAnimals() {
    setState(() {
      _filteredAnimals = _animals.where((animal) {
        final matchesSearch = _searchQuery.isEmpty ||
            animal.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (animal.tag?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesSpecies = _filterSpecies == null || animal.species == _filterSpecies;
        
        return matchesSearch && matchesSpecies;
      }).toList();
    });
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterAnimals();
  }
  
  void _onSpeciesFilterChanged(AnimalSpecies? species) {
    setState(() {
      _filterSpecies = species;
    });
    _filterAnimals();
  }
  
  Future<void> _navigateToCreateAnimal() async {
    if (!_canAccessAnimalManagement) {
      _showCoppaRestrictionDialog();
      return;
    }
    
    try {
      final result = await Navigator.push<Animal>(
        context,
        MaterialPageRoute(
          builder: (context) => const AnimalCreateScreen(),
        ),
      );
      
      if (result != null) {
        // Refresh the list
        await _loadAnimals();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _navigateToAnimalDetail(Animal animal) async {
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AnimalDetailScreen(animal: animal),
        ),
      );
      
      if (result == true) {
        // Refresh the list if animal was updated/deleted
        await _loadAnimals();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteAnimal(Animal animal) async {
    if (!_canAccessAnimalManagement) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Animal'),
        content: Text('Are you sure you want to delete ${animal.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _animalService.deleteAnimal(animal.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${animal.name} has been deleted'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadAnimals();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting animal: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  void _showCoppaRestrictionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Restricted'),
        content: Text(_coppaService.getRestrictedFeatureMessage(CoppaFeature.animalManagement)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
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
            _searchQuery.isNotEmpty || _filterSpecies != null
                ? 'No animals match your filters'
                : 'No animals yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _filterSpecies != null
                ? 'Try adjusting your search or filters'
                : 'Add your first animal to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          if (_canAccessAnimalManagement) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateAnimal,
              icon: const Icon(Icons.add),
              label: const Text('Add Animal'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Offline Mode',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to connect to server',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnimals,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimalCard(Animal animal) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToAnimalDetail(animal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animal avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: animal.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              animal.photoUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.pets,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.pets,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Animal info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                animal.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (animal.tag != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  animal.tag!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${animal.speciesDisplay}${animal.breed != null ? ' • ${animal.breed}' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (animal.gender != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            animal.genderDisplay,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Actions menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToAnimalDetail(animal);
                          break;
                        case 'delete':
                          _deleteAnimal(animal);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (_canAccessAnimalManagement)
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              // Stats row
              if (animal.currentWeight != null || animal.ageInDays != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (animal.currentWeight != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.scale,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${animal.currentWeight!.toStringAsFixed(1)} lbs',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (animal.ageInDays != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatAge(animal.ageInDays!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatAge(int days) {
    if (days < 30) {
      return '$days days';
    } else if (days < 365) {
      return '${(days / 30).floor()} months';
    } else {
      final years = (days / 365).floor();
      final months = ((days % 365) / 30).floor();
      return months > 0 ? '$years yr $months mo' : '$years year${years > 1 ? 's' : ''}';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!_canAccessAnimalManagement) {
      return ResponsiveScaffold(
        title: 'Animals',
        currentIndex: 2,
        onNavigationTap: (index) => handleNavigation(context, index),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Feature Restricted',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _coppaService.getRestrictedFeatureMessage(CoppaFeature.animalManagement),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ResponsiveScaffold(
      title: 'Animals',
      currentIndex: 2,
      onNavigationTap: (index) => handleNavigation(context, index),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search animals...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              
              // Species filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filterSpecies == null,
                      onSelected: (selected) {
                        if (selected) _onSpeciesFilterChanged(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ...AnimalSpecies.values.map((species) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_getSpeciesDisplay(species)),
                          selected: _filterSpecies == species,
                          onSelected: (selected) {
                            _onSpeciesFilterChanged(selected ? species : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!_isLoading && !_isOffline)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnimals,
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isOffline
              ? _buildOfflineState()
              : _filteredAnimals.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredAnimals.length,
                      itemBuilder: (context, index) {
                        return _buildAnimalCard(_filteredAnimals[index]);
                      },
                    ),
      floatingActionButton: _canAccessAnimalManagement
          ? FloatingActionButton(
              onPressed: _navigateToCreateAnimal,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
  
  String _getSpeciesDisplay(AnimalSpecies species) {
    switch (species) {
      case AnimalSpecies.cattle:
        return 'Cattle';
      case AnimalSpecies.swine:
        return 'Swine';
      case AnimalSpecies.sheep:
        return 'Sheep';
      case AnimalSpecies.goat:
        return 'Goat';
      case AnimalSpecies.poultry:
        return 'Poultry';
      case AnimalSpecies.rabbit:
        return 'Rabbit';
      case AnimalSpecies.other:
        return 'Other';
    }
  }
}