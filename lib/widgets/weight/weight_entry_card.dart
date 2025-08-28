import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/weight.dart';
import '../../models/animal.dart';
import '../../theme/app_theme.dart';

/// Card widget for entering new weight entries
/// Features form validation, multiple measurement methods, and enhanced context
class WeightEntryCard extends StatefulWidget {
  final List<Animal> animals;
  final Function(Weight) onWeightAdded;
  final bool isLoading;

  const WeightEntryCard({
    super.key,
    required this.animals,
    required this.onWeightAdded,
    this.isLoading = false,
  });

  @override
  State<WeightEntryCard> createState() => _WeightEntryCardState();
}

class _WeightEntryCardState extends State<WeightEntryCard> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  
  Animal? _selectedAnimal;
  WeightUnit _selectedUnit = WeightUnit.lb;
  MeasurementMethod _selectedMethod = MeasurementMethod.digitalScale;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _feedStatus = 'unknown';
  String? _waterStatus = 'unknown';
  int _confidenceLevel = 8;
  bool _isShowWeight = false;

  bool get _isFormValid {
    return _selectedAnimal != null && 
           _weightController.text.isNotEmpty &&
           _formKey.currentState?.validate() == true;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitWeight() async {
    if (!_isFormValid || widget.isLoading) return;

    final weight = Weight(
      animalId: _selectedAnimal!.id!,
      userId: '', // Will be set by service
      recordedBy: '', // Will be set by service
      weightValue: double.parse(_weightController.text),
      weightUnit: _selectedUnit,
      measurementDate: _selectedDate,
      measurementTime: _selectedTime,
      measurementMethod: _selectedMethod,
      feedStatus: _feedStatus,
      waterStatus: _waterStatus,
      confidenceLevel: _confidenceLevel,
      isShowWeight: _isShowWeight,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    widget.onWeightAdded(weight);
    
    // Reset form
    setState(() {
      _weightController.clear();
      _notesController.clear();
      _selectedAnimal = null;
      _selectedDate = DateTime.now();
      _selectedTime = null;
      _feedStatus = 'unknown';
      _waterStatus = 'unknown';
      _confidenceLevel = 8;
      _isShowWeight = false;
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.monitor_weight,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Record Weight',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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

              // Weight Input Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Weight',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter weight';
                        }
                        final weight = double.tryParse(value);
                        if (weight == null || weight <= 0) {
                          return 'Please enter valid weight';
                        }
                        final maxWeight = _selectedUnit == WeightUnit.lb ? 5000 : 2500;
                        if (weight > maxWeight) {
                          return 'Weight seems too high';
                        }
                        return null;
                      },
                      enabled: !widget.isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<WeightUnit>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                      ),
                      items: WeightUnit.values.map((unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit == WeightUnit.lb ? 'lbs' : 'kg'),
                      )).toList(),
                      onChanged: widget.isLoading ? null : (unit) {
                        setState(() {
                          _selectedUnit = unit!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date and Time Selection
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(
                        '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                      ),
                      onTap: widget.isLoading ? null : _selectDate,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('Time'),
                      subtitle: Text(
                        _selectedTime?.format(context) ?? 'Not set',
                      ),
                      onTap: widget.isLoading ? null : _selectTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Measurement Method
              DropdownButtonFormField<MeasurementMethod>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Measurement Method',
                  prefixIcon: Icon(Icons.scale),
                ),
                items: MeasurementMethod.values.map((method) => DropdownMenuItem(
                  value: method,
                  child: Text(_getMethodDisplayName(method)),
                )).toList(),
                onChanged: widget.isLoading ? null : (method) {
                  setState(() {
                    _selectedMethod = method!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Feeding Context
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _feedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Feed Status',
                        prefixIcon: Icon(Icons.grass),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fasted', child: Text('Fasted')),
                        DropdownMenuItem(value: 'fed', child: Text('Fed')),
                        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                      ],
                      onChanged: widget.isLoading ? null : (status) {
                        setState(() {
                          _feedStatus = status;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _waterStatus,
                      decoration: const InputDecoration(
                        labelText: 'Water Status',
                        prefixIcon: Icon(Icons.water_drop),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'watered', child: Text('Watered')),
                        DropdownMenuItem(value: 'restricted', child: Text('Restricted')),
                        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                      ],
                      onChanged: widget.isLoading ? null : (status) {
                        setState(() {
                          _waterStatus = status;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Confidence Level Slider
              Text(
                'Confidence Level: $_confidenceLevel/10',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                value: _confidenceLevel.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _confidenceLevel.toString(),
                onChanged: widget.isLoading ? null : (value) {
                  setState(() {
                    _confidenceLevel = value.round();
                  });
                },
              ),
              const SizedBox(height: 8),

              // Show Weight Toggle
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show/Competition Weight'),
                subtitle: const Text('Mark this as an official show weight'),
                value: _isShowWeight,
                onChanged: widget.isLoading ? null : (value) {
                  setState(() {
                    _isShowWeight = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                  hintText: 'Add any additional observations...',
                ),
                maxLines: 3,
                enabled: !widget.isLoading,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isFormValid && !widget.isLoading ? _submitWeight : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Record Weight',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMethodDisplayName(MeasurementMethod method) {
    switch (method) {
      case MeasurementMethod.digitalScale:
        return 'Digital Scale';
      case MeasurementMethod.mechanicalScale:
        return 'Mechanical Scale';
      case MeasurementMethod.tapeMeasure:
        return 'Tape Measure';
      case MeasurementMethod.visualEstimate:
        return 'Visual Estimate';
      case MeasurementMethod.veterinary:
        return 'Veterinary Scale';
      case MeasurementMethod.showOfficial:
        return 'Show Official';
    }
  }
}