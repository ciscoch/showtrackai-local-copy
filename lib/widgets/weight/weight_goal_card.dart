import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/weight_goal.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';

/// Card widget for displaying and managing weight goals
/// Features progress tracking, goal creation/editing, and urgency indicators
class WeightGoalCard extends StatefulWidget {
  final List<WeightGoal> goals;
  final List<Animal> animals;
  final Function(WeightGoal) onGoalAdded;
  final Function(WeightGoal) onGoalUpdated;
  final Function(String) onGoalDeleted;
  final bool isLoading;

  const WeightGoalCard({
    super.key,
    required this.goals,
    required this.animals,
    required this.onGoalAdded,
    required this.onGoalUpdated,
    required this.onGoalDeleted,
    this.isLoading = false,
  });

  @override
  State<WeightGoalCard> createState() => _WeightGoalCardState();
}

class _WeightGoalCardState extends State<WeightGoalCard> {
  bool _showCreateForm = false;

  @override
  Widget build(BuildContext context) {
    final activeGoals = widget.goals.where((g) => g.status == GoalStatus.active).toList();
    final urgentGoals = activeGoals.where((g) => g.isUrgent).length;
    final overdueGoals = activeGoals.where((g) => g.isOverdue).length;

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
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flag,
                    color: AppTheme.accentOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Weight Goals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_showCreateForm)
                  IconButton(
                    onPressed: widget.isLoading ? null : () {
                      setState(() {
                        _showCreateForm = true;
                      });
                    },
                    icon: const Icon(Icons.add_circle),
                    tooltip: 'Add Goal',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Stats
            if (!_showCreateForm && activeGoals.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'Active Goals',
                        value: activeGoals.length.toString(),
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    if (urgentGoals > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'Urgent',
                          value: urgentGoals.toString(),
                          color: AppTheme.accentOrange,
                        ),
                      ),
                    ],
                    if (overdueGoals > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'Overdue',
                          value: overdueGoals.toString(),
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            if (!_showCreateForm && activeGoals.isNotEmpty)
              const SizedBox(height: 16),

            // Create Goal Form
            if (_showCreateForm)
              _CreateGoalForm(
                animals: widget.animals,
                onSubmit: (goal) {
                  widget.onGoalAdded(goal);
                  setState(() {
                    _showCreateForm = false;
                  });
                },
                onCancel: () {
                  setState(() {
                    _showCreateForm = false;
                  });
                },
                isLoading: widget.isLoading,
              )
            // Goals List
            else if (widget.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (activeGoals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Active Goals',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set weight goals to track progress',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showCreateForm = true;
                          });
                        },
                        child: const Text('Create First Goal'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeGoals.length,
                itemBuilder: (context, index) {
                  final goal = activeGoals[index];
                  final animal = widget.animals.firstWhere(
                    (a) => a.id == goal.animalId,
                    orElse: () => Animal(name: 'Unknown', species: 'cattle'),
                  );
                  
                  return _GoalItem(
                    goal: goal,
                    animal: animal,
                    onEdit: (updatedGoal) => widget.onGoalUpdated(updatedGoal),
                    onDelete: () => widget.onGoalDeleted(goal.id!),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateGoalForm extends StatefulWidget {
  final List<Animal> animals;
  final Function(WeightGoal) onSubmit;
  final VoidCallback onCancel;
  final bool isLoading;

  const _CreateGoalForm({
    required this.animals,
    required this.onSubmit,
    required this.onCancel,
    required this.isLoading,
  });

  @override
  State<_CreateGoalForm> createState() => _CreateGoalFormState();
}

class _CreateGoalFormState extends State<_CreateGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _startingWeightController = TextEditingController();

  Animal? _selectedAnimal;
  WeightUnit _weightUnit = WeightUnit.lb;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  DateTime _startingDate = DateTime.now();
  bool _isShowGoal = false;
  String? _showName;

  @override
  void dispose() {
    _nameController.dispose();
    _targetWeightController.dispose();
    _startingWeightController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || widget.isLoading) return;

    final goal = WeightGoal(
      animalId: _selectedAnimal!.id!,
      userId: '', // Will be set by service
      goalName: _nameController.text.trim(),
      targetWeight: double.parse(_targetWeightController.text),
      weightUnit: _weightUnit,
      targetDate: _targetDate,
      startingWeight: double.parse(_startingWeightController.text),
      startingDate: _startingDate,
      showName: _isShowGoal ? _showName : null,
      showDate: _isShowGoal ? _targetDate : null,
    );

    widget.onSubmit(goal);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Goal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Animal Selection
            DropdownButtonFormField<Animal>(
              value: _selectedAnimal,
              decoration: const InputDecoration(
                labelText: 'Select Animal',
                prefixIcon: Icon(Icons.pets),
              ),
              items: widget.animals.map((animal) => DropdownMenuItem(
                value: animal,
                child: Text(animal.name),
              )).toList(),
              onChanged: widget.isLoading ? null : (animal) {
                setState(() {
                  _selectedAnimal = animal;
                });
              },
              validator: (value) {
                if (value == null) return 'Please select an animal';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Goal Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                prefixIcon: Icon(Icons.label),
                hintText: 'e.g., Show Weight, Market Ready',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a goal name';
                }
                return null;
              },
              enabled: !widget.isLoading,
            ),
            const SizedBox(height: 16),

            // Weight inputs
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startingWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Starting Weight',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final weight = double.tryParse(value);
                      if (weight == null || weight <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                    enabled: !widget.isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _targetWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Target Weight',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final weight = double.tryParse(value);
                      if (weight == null || weight <= 0) {
                        return 'Invalid';
                      }
                      final startingWeight = double.tryParse(_startingWeightController.text);
                      if (startingWeight != null && weight <= startingWeight) {
                        return 'Must be > starting';
                      }
                      return null;
                    },
                    enabled: !widget.isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonFormField<WeightUnit>(
                  value: _weightUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                  ),
                  items: WeightUnit.values.map((unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(unit == WeightUnit.lb ? 'lbs' : 'kg'),
                  )).toList(),
                  onChanged: widget.isLoading ? null : (unit) {
                    setState(() {
                      _weightUnit = unit!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Selection
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target Date'),
                    subtitle: Text(
                      '${_targetDate.month}/${_targetDate.day}/${_targetDate.year}',
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: widget.isLoading ? null : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setState(() {
                          _targetDate = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            // Show Goal Toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show/Competition Goal'),
              subtitle: const Text('Track progress toward a specific show'),
              value: _isShowGoal,
              onChanged: widget.isLoading ? null : (value) {
                setState(() {
                  _isShowGoal = value ?? false;
                });
              },
            ),

            if (_isShowGoal)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Show Name',
                    prefixIcon: Icon(Icons.emoji_events),
                  ),
                  onChanged: (value) {
                    _showName = value.trim().isEmpty ? null : value;
                  },
                  enabled: !widget.isLoading,
                ),
              ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                TextButton(
                  onPressed: widget.isLoading ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: widget.isLoading ? null : _submit,
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Goal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalItem extends StatelessWidget {
  final WeightGoal goal;
  final Animal animal;
  final Function(WeightGoal) onEdit;
  final VoidCallback onDelete;

  const _GoalItem({
    required this.goal,
    required this.animal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercentage ?? 0;
    final isOnTrack = goal.isOnTrack;
    final urgencyColor = _getUrgencyColor();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.goalName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getUrgencyText(),
                    style: TextStyle(
                      color: urgencyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        // TODO: Implement edit dialog
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
            const SizedBox(height: 8),

            // Animal and Target Info
            Row(
              children: [
                Text(
                  animal.name,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Target: ${goal.targetWeight.toStringAsFixed(1)} ${goal.weightUnitDisplay}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress: ${progress.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      isOnTrack ? 'On Track' : 'Behind',
                      style: TextStyle(
                        color: isOnTrack ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOnTrack ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatText(
                    label: 'Days Left',
                    value: goal.daysRemaining?.toString() ?? '--',
                  ),
                ),
                Expanded(
                  child: _StatText(
                    label: 'Need to Gain',
                    value: goal.totalWeightNeeded != null
                        ? '${goal.totalWeightNeeded!.toStringAsFixed(1)} ${goal.weightUnitDisplay}'
                        : '--',
                  ),
                ),
                Expanded(
                  child: _StatText(
                    label: 'Required ADG',
                    value: goal.requiredAdgToMeetGoal != null
                        ? '${goal.requiredAdgToMeetGoal!.toStringAsFixed(2)}'
                        : '--',
                  ),
                ),
              ],
            ),

            if (goal.showName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    goal.showName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getUrgencyColor() {
    switch (goal.urgencyStatus) {
      case 'overdue':
        return AppTheme.accentRed;
      case 'urgent':
        return AppTheme.accentOrange;
      case 'approaching':
        return Colors.yellow[700]!;
      default:
        return AppTheme.primaryGreen;
    }
  }

  String _getUrgencyText() {
    switch (goal.urgencyStatus) {
      case 'overdue':
        return 'OVERDUE';
      case 'urgent':
        return 'URGENT';
      case 'approaching':
        return 'SOON';
      default:
        return 'ON TRACK';
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.goalName}"? This action cannot be undone.'),
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
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatText extends StatelessWidget {
  final String label;
  final String value;

  const _StatText({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}