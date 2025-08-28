import 'package:flutter/material.dart';
import '../models/timeline_item.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../models/journal_entry.dart';

/// Filter options for timeline view
class TimelineFilters extends StatefulWidget {
  final Set<TimelineItemType> selectedTypes;
  final String? selectedAnimalId;
  final DateTimeRange? selectedDateRange;
  final String? selectedCategory;
  final List<Animal> animals;
  final Function(
    Set<TimelineItemType> types,
    String? animalId,
    DateTimeRange? dateRange,
    String? category,
  ) onApplyFilters;

  const TimelineFilters({
    super.key,
    required this.selectedTypes,
    required this.selectedAnimalId,
    required this.selectedDateRange,
    required this.selectedCategory,
    required this.animals,
    required this.onApplyFilters,
  });

  @override
  State<TimelineFilters> createState() => _TimelineFiltersState();
}

class _TimelineFiltersState extends State<TimelineFilters> {
  late Set<TimelineItemType> _types;
  String? _animalId;
  DateTimeRange? _dateRange;
  String? _category;

  @override
  void initState() {
    super.initState();
    _types = Set.from(widget.selectedTypes);
    _animalId = widget.selectedAnimalId;
    _dateRange = widget.selectedDateRange;
    _category = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            child: Row(
              children: [
                const Text(
                  'Filter Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          
          // Filter options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item types
                  _buildSectionTitle('Item Types'),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.book,
                                size: 16,
                                color: _types.contains(TimelineItemType.journal)
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              const Text('Journals'),
                            ],
                          ),
                          selected: _types.contains(TimelineItemType.journal),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _types.add(TimelineItemType.journal);
                              } else {
                                _types.remove(TimelineItemType.journal);
                              }
                            });
                          },
                          selectedColor: Colors.blue,
                          checkmarkColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: _types.contains(TimelineItemType.expense)
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              const Text('Expenses'),
                            ],
                          ),
                          selected: _types.contains(TimelineItemType.expense),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _types.add(TimelineItemType.expense);
                              } else {
                                _types.remove(TimelineItemType.expense);
                              }
                            });
                          },
                          selectedColor: Colors.green,
                          checkmarkColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Date range
                  _buildSectionTitle('Date Range'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDateChip('All Time', null),
                        const SizedBox(width: 8),
                        _buildDateChip(
                          'Today',
                          DateTimeRange(
                            start: DateTime.now().copyWith(
                              hour: 0,
                              minute: 0,
                              second: 0,
                            ),
                            end: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDateChip(
                          'This Week',
                          DateTimeRange(
                            start: DateTime.now().subtract(
                              Duration(days: DateTime.now().weekday - 1),
                            ).copyWith(hour: 0, minute: 0, second: 0),
                            end: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDateChip(
                          'This Month',
                          DateTimeRange(
                            start: DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              1,
                            ),
                            end: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDateChip(
                          'Last 30 Days',
                          DateTimeRange(
                            start: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            end: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_dateRange != null
                              ? _formatDateRange(_dateRange!)
                              : 'Custom'),
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: _dateRange,
                            );
                            if (range != null) {
                              setState(() {
                                _dateRange = range;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Animal filter
                  if (widget.animals.isNotEmpty) ...[
                    _buildSectionTitle('Animal'),
                    DropdownButtonFormField<String?>(
                      value: _animalId,
                      decoration: InputDecoration(
                        hintText: 'All Animals',
                        prefixIcon: const Icon(Icons.pets),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Animals'),
                        ),
                        ...widget.animals.map((animal) => DropdownMenuItem(
                              value: animal.id,
                              child: Text('${animal.name} (${animal.species})'),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _animalId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Category filter
                  _buildSectionTitle('Category'),
                  DropdownButtonFormField<String?>(
                    value: _category,
                    decoration: InputDecoration(
                      hintText: 'All Categories',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      if (_types.contains(TimelineItemType.journal))
                        ...JournalCategories.categories.map((cat) =>
                            DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  const Icon(Icons.book, size: 16),
                                  const SizedBox(width: 8),
                                  Text(JournalCategories.getDisplayName(cat)),
                                ],
                              ),
                            )),
                      if (_types.contains(TimelineItemType.expense))
                        ...ExpenseCategories.categories.map((cat) =>
                            DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_money, size: 16),
                                  const SizedBox(width: 8),
                                  Text(ExpenseCategories.getDisplayName(cat)),
                                ],
                              ),
                            )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _category = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Apply button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApplyFilters(
                    _types,
                    _animalId,
                    _dateRange,
                    _category,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, DateTimeRange? range) {
    final isSelected = _dateRange == range ||
        (range == null && _dateRange == null) ||
        (_dateRange != null &&
            range != null &&
            _dateRange!.start.isAtSameMomentAs(range.start) &&
            _dateRange!.end.isAtSameMomentAs(range.end));

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _dateRange = range;
        });
      },
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
      ),
    );
  }

  String _formatDateRange(DateTimeRange range) {
    final start = '${range.start.month}/${range.start.day}';
    final end = '${range.end.month}/${range.end.day}';
    return '$start - $end';
  }

  void _resetFilters() {
    setState(() {
      _types = {TimelineItemType.journal, TimelineItemType.expense};
      _animalId = null;
      _dateRange = null;
      _category = null;
    });
  }
}