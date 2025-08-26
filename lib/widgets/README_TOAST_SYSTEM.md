# ShowTrackAI Toast Notification System

A comprehensive toast notification system implemented for ShowTrackAI journal submission flow with Material Design 3 support.

## Features

### 🎯 Multiple Toast Types
- **Loading**: For ongoing operations (spinning indicator)
- **Success**: For completed operations (checkmark icon)
- **Error**: For failures (error icon with retry action)
- **Info**: For informational messages (info icon)
- **Warning**: For warnings (warning icon)

### 📱 Responsive Design
- **Position**: Bottom-center on all screen sizes
- **Stacking**: Multiple toasts stack vertically
- **Animations**: Smooth slide-up and fade animations
- **Max Width**: 400px constraint for readability

### ♿ Accessibility Features
- **Semantics**: Proper ARIA labels and roles
- **Screen Reader**: Compatible with screen readers
- **Color Contrast**: WCAG compliant color schemes
- **Focus Management**: Keyboard navigation support

### 🔄 Journal Submission Flow
- **Stage 1**: "Submitting journal entry..." (loading)
- **Stage 2**: "Journal entry submitted successfully!" (success)
- **Stage 3**: "Processing with AI analysis..." (info)
- **Stage 4**: "Journal stored in database" (success)
- **Stage 5**: "AI processing complete!" (success with action)

## File Structure

```
lib/
├── services/
│   ├── toast_notification_service.dart    # Core toast service
│   └── journal_toast_service.dart         # Journal-specific toasts
├── widgets/
│   ├── toast_notification_widget.dart     # UI components
│   └── README_TOAST_SYSTEM.md             # This documentation
└── main.dart                              # ToastOverlay integration
```

## Usage Examples

### Basic Toast Usage

```dart
import '../services/toast_notification_service.dart';

// Using convenience class
Toast.success('Entry saved successfully!');
Toast.error('Network connection failed', onAction: () => retry());
Toast.loading('Processing...', isDismissible: false);
Toast.info('AI analysis started');
Toast.warning('Check your internet connection');

// Using service directly
final toastService = ToastNotificationService.instance;
final toastId = toastService.showLoading('Uploading file...');
// Later...
toastService.dismiss(toastId);
```

### Journal-Specific Usage

```dart
import '../services/journal_toast_service.dart';

// Complete submission flow
await JournalToast.showSubmissionFlow(
  onSubmit: () => performSubmission(),
  onViewEntry: () => navigateToEntry(),
  onRetry: () => retrySubmission(),
);

// Individual states
JournalToast.submitting();
JournalToast.submissionSuccess(onViewEntry: () => navigate());
JournalToast.aiProcessing();
JournalToast.databaseStored();
JournalToast.aiComplete(onViewResults: () => showResults());

// Error handling
JournalToast.submissionError(error: 'Network failed', onRetry: retry);
JournalToast.networkError(onRetry: retry);
JournalToast.validationError('title');
```

### Widget Mixin Usage

```dart
class MyWidget extends StatefulWidget {
  // ...
}

class _MyWidgetState extends State<MyWidget> with ToastMixin<MyWidget> {
  void handleAction() {
    showLoading('Processing...');
    // Later...
    showSuccess('Done!');
  }
}
```

## Integration Guide

### 1. Add to MaterialApp

```dart
// main.dart
import 'widgets/toast_notification_widget.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ToastOverlay(
      child: MaterialApp(
        // Your app configuration
      ),
    );
  }
}
```

### 2. Use in Pages/Widgets

```dart
import '../services/journal_toast_service.dart';
import '../widgets/toast_notification_widget.dart';

class MyPage extends StatefulWidget {
  // ...
}

class _MyPageState extends State<MyPage> with ToastMixin<MyPage> {
  // Use toast methods directly or through JournalToast
}
```

## Toast States and Timing

### Default Durations
- **Loading**: 10 seconds (or until dismissed)
- **Success**: 4 seconds
- **Error**: 6 seconds
- **Info**: 4 seconds
- **Warning**: 5 seconds

### Journal Flow Timing
- **Submitting**: Until completion
- **Success**: 4 seconds
- **AI Processing**: 1 second delay + processing time
- **Database Stored**: 2 second display + 2 second delay
- **AI Complete**: 4 seconds with action button

## Customization

### Colors (Material Design 3)
- **Success**: `Colors.green.shade600`
- **Error**: `Colors.red.shade600`
- **Warning**: `Colors.orange.shade600`
- **Info**: `Colors.blue.shade600`
- **Loading**: `Colors.grey.shade700`

### Animation Curves
- **Slide In**: `Curves.easeOutBack` (300ms)
- **Fade In**: `Curves.easeOut` (300ms)
- **Slide Out**: `Curves.easeIn` (300ms)

### Positioning
- **Bottom**: 80px from bottom (above nav bars)
- **Horizontal**: 16px margins
- **Max Width**: 400px
- **Stack Spacing**: 8px between toasts

## Error Handling

### Network Errors
```dart
JournalToast.networkError(onRetry: () {
  // Retry logic
});
```

### Validation Errors
```dart
JournalToast.validationError('required fields');
```

### AI Processing Errors (Non-blocking)
```dart
JournalToast.aiError(onRetry: () {
  // Retry AI processing
});
```

## Testing Considerations

### Flutter Web Canvas Limitations
- Toast interactions work well with mouse/touch
- Keyboard navigation supported via tab order
- Screen reader compatibility maintained

### Device Testing
- **Mobile**: Portrait/landscape orientations
- **Tablet**: Various screen sizes
- **Desktop**: Wide screen layouts
- **Web**: Browser compatibility

## Performance Optimizations

### Memory Management
- Automatic cleanup of dismissed toasts
- Timer cancellation on disposal
- Stream controller proper disposal

### Animation Performance
- Hardware acceleration enabled
- Efficient widget rebuilding
- Minimal state updates

## Future Enhancements

### Planned Features
- [ ] Push notification integration
- [ ] Email notification fallbacks
- [ ] Sound/vibration feedback
- [ ] Custom toast themes
- [ ] Position customization
- [ ] Queue management improvements

### Integration Points
- [ ] File upload progress bars
- [ ] Network status indicators
- [ ] Background sync notifications
- [ ] Achievement/milestone toasts

## Troubleshooting

### Common Issues

**Toasts not showing:**
- Verify ToastOverlay is wrapping MaterialApp
- Check that toast service is imported correctly

**Multiple toasts overlapping:**
- Use dismissAll() before showing new toasts
- Implement proper toast queueing if needed

**Animation issues:**
- Ensure SingleTickerProviderStateMixin is used
- Check animation controller disposal

**Memory leaks:**
- Call dispose() on ToastNotificationService
- Cancel timers properly

### Debug Mode
```dart
// Enable debug mode for detailed logging
const bool kDebugMode = true;
```

## Best Practices

### Do's ✅
- Use specific toast types for different states
- Provide retry actions for error states
- Keep messages concise and actionable
- Test with screen readers
- Handle edge cases (network failures, etc.)

### Don'ts ❌
- Don't show too many toasts simultaneously
- Don't use loading toasts for instant operations
- Don't ignore accessibility requirements
- Don't use toasts for critical confirmations
- Don't forget to handle toast dismissal

---

*Implementation completed: January 2025*  
*Compatible with Flutter 3.x and Material Design 3*  
*Accessibility compliant (WCAG 2.1)*