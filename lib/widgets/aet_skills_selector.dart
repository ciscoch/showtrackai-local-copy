import 'package:flutter/material.dart';
import '../models/journal_entry.dart';

/// Widget for selecting AET (Agricultural Experience Tracker) Skills
class AETSkillsSelector extends StatefulWidget {
  final List<String> selectedSkills;
  final Function(List<String>) onChanged;

  const AETSkillsSelector({
    Key? key,
    required this.selectedSkills,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<AETSkillsSelector> createState() => _AETSkillsSelectorState();
}

class _AETSkillsSelectorState extends State<AETSkillsSelector> {
  late List<String> _selectedSkills;
  String? _expandedCategory;

  @override
  void initState() {
    super.initState();
    _selectedSkills = List.from(widget.selectedSkills);
  }

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
    widget.onChanged(_selectedSkills);
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategory == category) {
        _expandedCategory = null;
      } else {
        _expandedCategory = category;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instructions
        const Text(
          'Select skills demonstrated in this journal entry:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),

        // Selected skills summary
        if (_selectedSkills.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Skills (${_selectedSkills.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D3A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedSkills.map((skill) {
                    return Chip(
                      label: Text(
                        skill,
                        style: const TextStyle(fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _toggleSkill(skill),
                      backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                      deleteIconColor: const Color(0xFF2E7D3A),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Skill categories
        ...AETSkills.categories.entries.map((categoryEntry) {
          final categoryName = categoryEntry.key;
          final skills = categoryEntry.value;
          final isExpanded = _expandedCategory == categoryName;
          final selectedInCategory = skills.where((skill) => _selectedSkills.contains(skill)).length;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                // Category header
                ListTile(
                  leading: Icon(
                    _getCategoryIcon(categoryName),
                    color: const Color(0xFF4CAF50),
                  ),
                  title: Text(
                    categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: selectedInCategory > 0
                      ? Text(
                          '$selectedInCategory skill${selectedInCategory == 1 ? '' : 's'} selected',
                          style: const TextStyle(
                            color: Color(0xFF2E7D3A),
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  trailing: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => _toggleCategory(categoryName),
                ),
                
                // Skills list (expanded)
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: skills.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) => _toggleSkill(skill),
                          title: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected 
                                  ? FontWeight.w500 
                                  : FontWeight.normal,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: const Color(0xFF4CAF50),
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 12),

        // Quick selection buttons
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSkills.clear();
                });
                widget.onChanged(_selectedSkills);
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[600],
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Select common skills for cattle/livestock projects
                final commonSkills = [
                  'Feeding Management',
                  'Health Monitoring',
                  'Record Keeping',
                  'Financial Planning',
                  'Problem Solving',
                ];
                setState(() {
                  _selectedSkills.clear();
                  _selectedSkills.addAll(commonSkills);
                });
                widget.onChanged(_selectedSkills);
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Common'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Animal Care':
        return Icons.pets;
      case 'Business Management':
        return Icons.business;
      case 'Leadership':
        return Icons.group;
      case 'Technical Skills':
        return Icons.build;
      default:
        return Icons.star;
    }
  }
}