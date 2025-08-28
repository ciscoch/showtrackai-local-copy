import 'package:flutter/material.dart';
import 'dart:async';
import '../services/journal_content_templates.dart';
import '../theme/app_theme.dart';

/// AI-powered text field with real-time suggestions and auto-complete functionality
/// Shows suggestions as user types and provides "Generate with AI" capabilities
class AIAssistedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int maxLines;
  final String category;
  final String? animalType;
  final Map<String, dynamic>? context;
  final Function(List<String>)? onAETSkillsGenerated;
  final Function(int)? onDurationSuggested;
  final Function(List<String>)? onTagsGenerated;
  final bool enabled;
  final String? Function(String?)? validator;

  const AIAssistedTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLines = 5,
    required this.category,
    this.animalType,
    this.context,
    this.onAETSkillsGenerated,
    this.onDurationSuggested,
    this.onTagsGenerated,
    this.enabled = true,
    this.validator,
  }) : super(key: key);

  @override
  State<AIAssistedTextField> createState() => _AIAssistedTextFieldState();
}

class _AIAssistedTextFieldState extends State<AIAssistedTextField>
    with TickerProviderStateMixin {
  final JournalContentTemplateService _templateService = 
      JournalContentTemplateService();
  
  List<ContentSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _isGeneratingAI = false;
  Timer? _debounceTimer;
  
  late AnimationController _suggestionAnimationController;
  late AnimationController _aiLoadingController;
  late Animation<double> _suggestionSlideAnimation;
  late Animation<double> _aiPulseAnimation;
  
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _suggestionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _aiLoadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _suggestionSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _suggestionAnimationController,
      curve: Curves.easeOut,
    ));
    
    _aiPulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _aiLoadingController,
      curve: Curves.easeInOut,
    ));
    
    // Listen to text changes
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionAnimationController.dispose();
    _aiLoadingController.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (widget.controller.text.isNotEmpty && _focusNode.hasFocus) {
        _generateSuggestions();
      } else {
        _hideSuggestions();
      }
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  Future<void> _generateSuggestions() async {
    if (!mounted) return;
    
    try {
      final suggestions = await _templateService.generateSuggestions(
        category: widget.category,
        currentText: widget.controller.text,
        animalType: widget.animalType,
        context: widget.context,
      );
      
      if (mounted && suggestions.isNotEmpty) {
        setState(() {
          _suggestions = suggestions;
        });
        _showSuggestionsOverlay();
      }
    } catch (e) {
      debugPrint('Error generating suggestions: $e');
    }
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: _buildSuggestionsPanel(),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    _suggestionAnimationController.forward();
  }

  void _hideSuggestions() {
    _suggestionAnimationController.reverse().then((_) {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsPanel() {
    return AnimatedBuilder(
      animation: _suggestionSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _suggestionSlideAnimation.value) * 20),
          child: Opacity(
            opacity: _suggestionSlideAnimation.value,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_fix_high,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Suggestions',
                          style: TextStyle(
                            color: AppTheme.darkGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _hideSuggestions,
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  // Suggestions list
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return _buildSuggestionTile(suggestion);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionTile(ContentSuggestion suggestion) {
    return ListTile(
      dense: true,
      leading: _getSuggestionIcon(suggestion.type),
      title: Text(
        suggestion.title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.content.length > 100
                ? '${suggestion.content.substring(0, 100)}...'
                : suggestion.content,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildConfidenceChip(suggestion.confidence),
              if (suggestion.estimatedDuration != null) ...[
                const SizedBox(width: 8),
                _buildDurationChip(suggestion.estimatedDuration!),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _applySuggestion(suggestion, append: true),
            tooltip: 'Append to text',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () => _applySuggestion(suggestion, append: false),
            tooltip: 'Replace text',
          ),
        ],
      ),
      onTap: () => _applySuggestion(suggestion, append: true),
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

  Widget _buildConfidenceChip(double confidence) {
    final percentage = (confidence * 100).round();
    final color = confidence >= 0.8
        ? AppTheme.primaryGreen
        : confidence >= 0.6
            ? AppTheme.accentOrange
            : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDurationChip(int duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${duration}min',
        style: TextStyle(
          color: AppTheme.darkGreen,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _applySuggestion(ContentSuggestion suggestion, {required bool append}) {
    final currentText = widget.controller.text;
    final newText = append
        ? suggestion.type == SuggestionType.textCompletion
            ? currentText + suggestion.content
            : '$currentText\n\n${suggestion.content}'
        : suggestion.content;
    
    widget.controller.text = newText;
    
    // Trigger callbacks with suggested data
    if (suggestion.suggestedAETSkills.isNotEmpty) {
      widget.onAETSkillsGenerated?.call(suggestion.suggestedAETSkills);
    }
    
    if (suggestion.estimatedDuration != null) {
      widget.onDurationSuggested?.call(suggestion.estimatedDuration!);
    }
    
    if (suggestion.tags.isNotEmpty) {
      widget.onTagsGenerated?.call(suggestion.tags);
    }
    
    _hideSuggestions();
    
    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(append ? 'Content added' : 'Content replaced'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Future<void> _generateWithAI() async {
    if (_isGeneratingAI) return;
    
    setState(() {
      _isGeneratingAI = true;
    });
    
    _aiLoadingController.repeat();
    
    try {
      final aiSuggestion = await _templateService.generateAIContent(
        category: widget.category,
        prompt: widget.controller.text.isEmpty
            ? 'Generate content for ${widget.category} activity'
            : 'Complete this content: ${widget.controller.text}',
        context: widget.context,
      );
      
      if (mounted) {
        _applySuggestion(aiSuggestion, append: widget.controller.text.isNotEmpty);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI generation failed: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
        });
        _aiLoadingController.stop();
        _aiLoadingController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main text field
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled && !_isGeneratingAI,
            maxLines: widget.maxLines,
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              alignLabelWithHint: true,
              suffixIcon: _buildSuffixActions(),
              // Add visual indicator when AI is active
              prefixIcon: _suggestions.isNotEmpty
                  ? Icon(
                      Icons.auto_fix_high,
                      color: AppTheme.primaryGreen,
                    )
                  : null,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Action buttons
          Row(
            children: [
              // Generate with AI button
              ElevatedButton.icon(
                onPressed: _isGeneratingAI ? null : _generateWithAI,
                icon: _isGeneratingAI
                    ? AnimatedBuilder(
                        animation: _aiPulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _aiPulseAnimation.value,
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          );
                        },
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGeneratingAI ? 'Generating...' : 'AI Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Quick tips button
              OutlinedButton.icon(
                onPressed: _showQuickTips,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Tips'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildSuffixActions() {
    if (_isGeneratingAI) {
      return Container(
        width: 48,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
      );
    }
    
    if (widget.controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          widget.controller.clear();
          _hideSuggestions();
        },
        tooltip: 'Clear text',
      );
    }
    
    return null;
  }

  void _showQuickTips() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Writing Tips',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTipRow(Icons.edit_note, 'Start typing to see smart suggestions'),
            _buildTipRow(Icons.auto_awesome, 'Use "AI Generate" for complete content'),
            _buildTipRow(Icons.psychology, 'Include specific details and measurements'),
            _buildTipRow(Icons.school, 'Mention skills and learning outcomes'),
            _buildTipRow(Icons.timeline, 'Describe challenges and solutions'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}