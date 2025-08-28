import 'package:flutter/material.dart';
import '../../models/weight.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';

/// List view displaying weight history with analytics
/// Features filtering, sorting, and expandable details
class WeightHistoryList extends StatefulWidget {
  final List<Weight> weights;
  final List<Animal> animals;
  final Function(Weight) onEditWeight;
  final Function(String) onDeleteWeight;
  final bool isLoading;
  final String? selectedAnimalId;

  const WeightHistoryList({
    super.key,
    required this.weights,
    required this.animals,
    required this.onEditWeight,
    required this.onDeleteWeight,
    this.isLoading = false,
    this.selectedAnimalId,
  });

  @override
  State<WeightHistoryList> createState() => _WeightHistoryListState();
}

class _WeightHistoryListState extends State<WeightHistoryList> {
  String? _filterAnimalId;
  String _sortBy = 'date_desc'; // date_desc, date_asc, weight_desc, weight_asc
  Set<String> _expandedItems = <String>{};

  @override
  void initState() {
    super.initState();
    _filterAnimalId = widget.selectedAnimalId;
  }

  List<Weight> get _filteredWeights {
    var filtered = widget.weights.where((w) => w.status == WeightStatus.active).toList();
    
    if (_filterAnimalId != null) {
      filtered = filtered.where((w) => w.animalId == _filterAnimalId).toList();
    }
    
    // Sort weights
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) {
          final dateCompare = b.measurementDate.compareTo(a.measurementDate);
          if (dateCompare != 0) return dateCompare;
          if (a.measurementTime != null && b.measurementTime != null) {
            return b.measurementTime!.hour.compareTo(a.measurementTime!.hour);
          }
          return dateCompare;
        });
        break;
      case 'date_asc':
        filtered.sort((a, b) {
          final dateCompare = a.measurementDate.compareTo(b.measurementDate);
          if (dateCompare != 0) return dateCompare;
          if (a.measurementTime != null && b.measurementTime != null) {
            return a.measurementTime!.hour.compareTo(b.measurementTime!.hour);
          }
          return dateCompare;
        });
        break;
      case 'weight_desc':
        filtered.sort((a, b) => b.weightValue.compareTo(a.weightValue));
        break;
      case 'weight_asc':
        filtered.sort((a, b) => a.weightValue.compareTo(b.weightValue));
        break;
    }
    
    return filtered;
  }

  Animal? _getAnimalById(String animalId) {
    try {
      return widget.animals.firstWhere((a) => a.id == animalId);
    } catch (e) {
      return null;
    }
  }

  void _toggleExpanded(String weightId) {
    setState(() {
      if (_expandedItems.contains(weightId)) {
        _expandedItems.remove(weightId);
      } else {
        _expandedItems.add(weightId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AppTheme.accentBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Weight History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_filteredWeights.length} entries',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters and Sort
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _filterAnimalId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Animal',
                      prefixIcon: Icon(Icons.pets, size: 20),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Animals'),
                      ),
                      ...widget.animals.map((animal) => DropdownMenuItem<String>(
                        value: animal.id,
                        child: Text(animal.name),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterAnimalId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      prefixIcon: Icon(Icons.sort, size: 20),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'date_desc', child: Text('Newest First')),
                      DropdownMenuItem(value: 'date_asc', child: Text('Oldest First')),
                      DropdownMenuItem(value: 'weight_desc', child: Text('Heaviest First')),
                      DropdownMenuItem(value: 'weight_asc', child: Text('Lightest First')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight List
            if (widget.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_filteredWeights.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.monitor_weight_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filterAnimalId != null 
                            ? 'No weight records for this animal'
                            : 'No weight records found',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start by recording your first weight entry',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredWeights.length,
                itemBuilder: (context, index) {
                  final weight = _filteredWeights[index];
                  final animal = _getAnimalById(weight.animalId);
                  final isExpanded = _expandedItems.contains(weight.id);
                  
                  return _WeightHistoryItem(
                    weight: weight,
                    animal: animal,
                    isExpanded: isExpanded,
                    onToggleExpanded: () => _toggleExpanded(weight.id!),
                    onEdit: () => widget.onEditWeight(weight),
                    onDelete: () => widget.onDeleteWeight(weight.id!),
                    showAnimalName: _filterAnimalId == null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WeightHistoryItem extends StatelessWidget {
  final Weight weight;
  final Animal? animal;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showAnimalName;

  const _WeightHistoryItem({
    required this.weight,
    required this.animal,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onEdit,
    required this.onDelete,
    required this.showAnimalName,
  });

  @override
  Widget build(BuildContext context) {
    final weightDisplay = '${weight.weightValue.toStringAsFixed(1)} ${weight.weightUnitDisplay}';
    final dateDisplay = '${weight.measurementDate.month}/${weight.measurementDate.day}/${weight.measurementDate.year}';
    final timeDisplay = weight.measurementTime?.format(context) ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getWeightColor(weight).withOpacity(0.1),
              child: Icon(
                _getWeightIcon(weight),
                color: _getWeightColor(weight),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(
                  weightDisplay,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (weight.isShowWeight) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SHOW',
                      style: TextStyle(
                        color: AppTheme.accentOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (weight.isOutlier) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.warning_amber,
                    color: AppTheme.accentRed,
                    size: 16,
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAnimalName && animal != null)
                  Text(
                    animal!.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                Text('$dateDisplay${timeDisplay.isNotEmpty ? " at $timeDisplay" : ""}'),
                if (weight.adg != null)
                  Text(
                    'ADG: ${weight.adg!.toStringAsFixed(2)} lbs/day',
                    style: TextStyle(
                      color: weight.adg! > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                  onPressed: onToggleExpanded,
                  tooltip: isExpanded ? 'Hide details' : 'Show details',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        _showDeleteDialog(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: onToggleExpanded,
          ),
          
          // Expanded Details
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _DetailRow(
                    icon: Icons.scale,
                    label: 'Method',
                    value: weight.measurementMethodDisplay,
                  ),
                  if (weight.confidenceLevel != null)
                    _DetailRow(
                      icon: Icons.star_rate,
                      label: 'Confidence',
                      value: '${weight.confidenceLevel}/10',
                    ),
                  if (weight.feedStatus != null && weight.feedStatus != 'unknown')
                    _DetailRow(
                      icon: Icons.grass,
                      label: 'Feed Status',
                      value: weight.feedStatus!.toUpperCase(),
                    ),
                  if (weight.waterStatus != null && weight.waterStatus != 'unknown')
                    _DetailRow(
                      icon: Icons.water_drop,
                      label: 'Water Status',
                      value: weight.waterStatus!.toUpperCase(),
                    ),
                  if (weight.weightChange != null)
                    _DetailRow(
                      icon: weight.weightChange! > 0 ? Icons.trending_up : Icons.trending_down,
                      label: 'Weight Change',
                      value: '${weight.weightChange! > 0 ? "+" : ""}${weight.weightChange!.toStringAsFixed(1)} ${weight.weightUnitDisplay}',
                      valueColor: weight.weightChange! > 0 ? Colors.green : Colors.red,
                    ),
                  if (weight.daysSinceLastWeight != null)
                    _DetailRow(
                      icon: Icons.calendar_today,
                      label: 'Days Since Last',
                      value: '${weight.daysSinceLastWeight} days',
                    ),
                  if (weight.notes != null && weight.notes!.isNotEmpty)
                    _DetailRow(
                      icon: Icons.note,
                      label: 'Notes',
                      value: weight.notes!,
                      isMultiline: true,
                    ),
                  if (weight.isOutlier && weight.outlierReason != null)
                    _DetailRow(
                      icon: Icons.warning_amber,
                      label: 'Outlier Reason',
                      value: weight.outlierReason!,
                      valueColor: AppTheme.accentRed,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Weight Entry'),
        content: const Text('Are you sure you want to delete this weight entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getWeightColor(Weight weight) {
    if (weight.isShowWeight) return AppTheme.accentOrange;
    if (weight.isOutlier) return AppTheme.accentRed;
    if (weight.adg != null && weight.adg! > 0) return Colors.green;
    return AppTheme.primaryGreen;
  }

  IconData _getWeightIcon(Weight weight) {
    if (weight.isShowWeight) return Icons.emoji_events;
    if (weight.isOutlier) return Icons.warning_amber;
    return Icons.monitor_weight;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isMultiline;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
                fontSize: 13,
              ),
              maxLines: isMultiline ? null : 1,
              overflow: isMultiline ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}