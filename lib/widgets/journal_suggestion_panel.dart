import 'package:flutter/material.dart';
import 'dart:async';
import '../services/journal_content_templates.dart';
import '../theme/app_theme.dart';

/// Three-level suggestion panel: Quick Fill, Smart Suggest, and AI Generate
/// Provides visual feedback, loading states, and confidence indicators
class JournalSuggestionPanel extends StatefulWidget {
  final String category;
  final String currentText;
  final String? animalType;
  final Map<String, dynamic>? context;
  final Function(ContentSuggestion) onSuggestionSelected;
  final Function(List<String>)? onAETSkillsUpdated;
  final Function(int)? onDurationUpdated;
  final Function(List<String>)? onTagsUpdated;
  final bool isVisible;
  final VoidCallback? onClose;

  const JournalSuggestionPanel({
    Key? key,
    required this.category,
    required this.currentText,
    this.animalType,
    this.context,
    required this.onSuggestionSelected,
    this.onAETSkillsUpdated,
    this.onDurationUpdated,
    this.onTagsUpdated,
    this.isVisible = true,
    this.onClose,
  }) : super(key: key);

  @override
  State<JournalSuggestionPanel> createState() => _JournalSuggestionPanelState();
}

class _JournalSuggestionPanelState extends State<JournalSuggestionPanel>
    with TickerProviderStateMixin {
  final JournalContentTemplateService _templateService = 
      JournalContentTemplateService();
  
  List<ContentSuggestion> _quickFillSuggestions = [];
  List<ContentSuggestion> _smartSuggestions = [];
  ContentSuggestion? _aiSuggestion;
  
  bool _isLoadingSuggestions = false;
  bool _isGeneratingAI = false;
  String _selectedTab = 'quick';
  
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isVisible) {
      _slideController.forward();
      _loadSuggestions();
    }
  }

  @override
  void didUpdateWidget(JournalSuggestionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
        _loadSuggestions();
      } else {
        _slideController.reverse();
      }
    }
    
    if (widget.currentText != oldWidget.currentText ||
        widget.category != oldWidget.category) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), _loadSuggestions);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    if (!mounted || widget.currentText.isEmpty) return;
    
    setState(() {
      _isLoadingSuggestions = true;
    });
    
    try {
      final suggestions = await _templateService.generateSuggestions(
        category: widget.category,
        currentText: widget.currentText,
        animalType: widget.animalType,
        context: widget.context,
      );
      
      if (mounted) {
        setState(() {
          // Separate suggestions by type
          _quickFillSuggestions = suggestions
              .where((s) => s.type == SuggestionType.quickFill)
              .toList();
          
          _smartSuggestions = suggestions
              .where((s) => s.type == SuggestionType.smartSuggest || 
                          s.type == SuggestionType.textCompletion)
              .toList();
          
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
        debugPrint('Error loading suggestions: $e');
      }
    }
  }

  Future<void> _generateAISuggestion() async {
    if (_isGeneratingAI) return;
    
    setState(() {
      _isGeneratingAI = true;
      _aiSuggestion = null;
    });
    
    _pulseController.repeat();
    
    try {
      final aiSuggestion = await _templateService.generateAIContent(
        category: widget.category,
        prompt: widget.currentText.isEmpty
            ? 'Generate detailed ${widget.category} journal entry content'
            : 'Enhance and complete this content: ${widget.currentText}',
        context: widget.context,
      );
      
      if (mounted) {
        setState(() {
          _aiSuggestion = aiSuggestion;
          _isGeneratingAI = false;
        });
        _pulseController.stop();
        _pulseController.reset();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
        });
        _pulseController.stop();
        _pulseController.reset();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI generation failed: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_fix_high,
            color: AppTheme.primaryGreen,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Writing Assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.darkGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Get help with your ${widget.category} journal entry',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          _buildTab('quick', 'Quick Fill', Icons.flash_on, AppTheme.accentOrange),
          _buildTab('smart', 'Smart Suggest', Icons.psychology, AppTheme.accentBlue),
          _buildTab('ai', 'AI Generate', Icons.auto_awesome, AppTheme.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildTab(String tabId, String label, IconData icon, Color color) {
    final isSelected = _selectedTab == tabId;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
          
          if (tabId == 'ai' && _aiSuggestion == null && !_isGeneratingAI) {
            _generateAISuggestion();
          }
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              if (tabId == 'quick' && _quickFillSuggestions.isNotEmpty) ...[
                const SizedBox(width: 4),
                _buildBadge(_quickFillSuggestions.length),
              ],
              if (tabId == 'smart' && _smartSuggestions.isNotEmpty) ...[
                const SizedBox(width: 4),
                _buildBadge(_smartSuggestions.length),
              ],
              if (tabId == 'ai' && _aiSuggestion != null) ...[
                const SizedBox(width: 4),
                _buildBadge(1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'quick':
        return _buildQuickFillTab();
      case 'smart':
        return _buildSmartSuggestTab();
      case 'ai':
        return _buildAIGenerateTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuickFillTab() {
    if (_isLoadingSuggestions) {
      return _buildLoadingState('Finding quick templates...');
    }
    
    if (_quickFillSuggestions.isEmpty) {
      return _buildEmptyState(
        'No quick templates available',
        'Start typing to get suggestions',
        Icons.flash_on,
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _quickFillSuggestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildSuggestionCard(_quickFillSuggestions[index]);
      },
    );
  }

  Widget _buildSmartSuggestTab() {
    if (_isLoadingSuggestions) {
      return _buildLoadingState('Analyzing your content...');
    }
    
    if (_smartSuggestions.isEmpty) {
      return _buildEmptyState(
        'No smart suggestions yet',
        'Write more content to get contextual help',
        Icons.psychology,
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _smartSuggestions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildSuggestionCard(_smartSuggestions[index]);
      },
    );
  }

  Widget _buildAIGenerateTab() {
    if (_isGeneratingAI) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: _buildLoadingState('AI is crafting your content...'),
          );
        },
      );
    }
    
    if (_aiSuggestion == null) {
      return _buildGeneratePrompt();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildSuggestionCard(_aiSuggestion!, isAI: true),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratePrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: AppTheme.primaryGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Content Generation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Get AI-powered assistance to write comprehensive journal entries with proper agricultural terminology and structure.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateAISuggestion,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Content'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ContentSuggestion suggestion, {bool isAI = false}) {
    return Card(
      elevation: isAI ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAI
            ? BorderSide(color: AppTheme.primaryGreen, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _selectSuggestion(suggestion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _getSuggestionIcon(suggestion.type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isAI ? AppTheme.primaryGreen : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _buildConfidenceIndicator(suggestion.confidence),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Content
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAI ? AppTheme.lightGreen : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suggestion.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Metadata
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (suggestion.estimatedDuration != null)
                    _buildInfoChip(
                      Icons.schedule,
                      '${suggestion.estimatedDuration}min',
                      AppTheme.accentBlue,
                    ),
                  if (suggestion.suggestedAETSkills.isNotEmpty)
                    _buildInfoChip(
                      Icons.school,
                      '${suggestion.suggestedAETSkills.length} skills',
                      AppTheme.accentOrange,
                    ),
                  if (suggestion.tags.isNotEmpty)
                    _buildInfoChip(
                      Icons.local_offer,
                      '${suggestion.tags.length} tags',
                      AppTheme.primaryGreen,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _previewSuggestion(suggestion),
                    icon: const Icon(Icons.preview, size: 18),
                    label: const Text('Preview'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _selectSuggestion(suggestion),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Use This'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAI ? AppTheme.primaryGreen : AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getSuggestionIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.quickFill:
        return Icon(Icons.flash_on, color: AppTheme.accentOrange, size: 20);
      case SuggestionType.smartSuggest:
        return Icon(Icons.psychology, color: AppTheme.accentBlue, size: 20);
      case SuggestionType.aiGenerated:
        return Icon(Icons.auto_awesome, color: AppTheme.primaryGreen, size: 20);
      case SuggestionType.textCompletion:
        return Icon(Icons.edit, color: Colors.grey, size: 20);
    }
  }

  Widget _buildConfidenceIndicator(double confidence) {
    final percentage = (confidence * 100).round();
    final color = confidence >= 0.8
        ? AppTheme.primaryGreen
        : confidence >= 0.6
            ? AppTheme.accentOrange
            : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _selectSuggestion(ContentSuggestion suggestion) {
    widget.onSuggestionSelected(suggestion);
    
    // Update form data if callbacks provided
    if (suggestion.suggestedAETSkills.isNotEmpty) {
      widget.onAETSkillsUpdated?.call(suggestion.suggestedAETSkills);
    }
    
    if (suggestion.estimatedDuration != null) {
      widget.onDurationUpdated?.call(suggestion.estimatedDuration!);
    }
    
    if (suggestion.tags.isNotEmpty) {
      widget.onTagsUpdated?.call(suggestion.tags);
    }
    
    // Close panel
    widget.onClose?.call();
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied: ${suggestion.title}'),
        backgroundColor: AppTheme.primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _previewSuggestion(ContentSuggestion suggestion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  children: [
                    _getSuggestionIcon(suggestion.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.lightGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            suggestion.content,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Metadata
                        if (suggestion.suggestedAETSkills.isNotEmpty) ...[
                          Text(
                            'Suggested AET Skills:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: suggestion.suggestedAETSkills.map((skill) {
                              return Chip(
                                label: Text(skill),
                                backgroundColor: AppTheme.lightGreen,
                                labelStyle: const TextStyle(fontSize: 12),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        if (suggestion.tags.isNotEmpty) ...[
                          Text(
                            'Tags:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: suggestion.tags.map((tag) {
                              return Chip(
                                label: Text(tag),
                                backgroundColor: Colors.grey[100],
                                labelStyle: const TextStyle(fontSize: 12),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _selectSuggestion(suggestion);
                        },
                        child: const Text('Use This'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}