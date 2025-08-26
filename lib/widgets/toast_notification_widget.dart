import 'package:flutter/material.dart';
import '../services/toast_notification_service.dart';

/// Individual toast notification widget
class ToastWidget extends StatefulWidget {
  final ToastNotification notification;
  final VoidCallback onDismiss;

  const ToastWidget({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.notification.type) {
      case ToastType.success:
        return Colors.green.shade600;
      case ToastType.error:
        return Colors.red.shade600;
      case ToastType.warning:
        return Colors.orange.shade600;
      case ToastType.info:
        return Colors.blue.shade600;
      case ToastType.loading:
        return Colors.grey.shade700;
    }
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.warning:
        return Icons.warning;
      case ToastType.info:
        return Icons.info;
      case ToastType.loading:
        return Icons.hourglass_empty;
    }
  }

  Widget _buildLoadingIndicator() {
    if (widget.notification.type != ToastType.loading) {
      return Icon(
        _getIcon(),
        color: Colors.white,
        size: 20,
      );
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: _getBackgroundColor(),
            child: Semantics(
              label: '${widget.notification.type.name} notification: ${widget.notification.message}',
              liveRegion: true,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minHeight: 48,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon or loading indicator
                    _buildLoadingIndicator(),
                    const SizedBox(width: 12),

                    // Message text
                    Flexible(
                      child: Text(
                        widget.notification.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Action button or dismiss button
                    if (widget.notification.actionLabel != null &&
                        widget.notification.onAction != null) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: widget.notification.onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.notification.actionLabel!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    // Dismiss button
                    if (widget.notification.isDismissible) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _dismiss,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        tooltip: 'Dismiss notification',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toast container that displays all active toasts
class ToastContainer extends StatefulWidget {
  const ToastContainer({super.key});

  @override
  State<ToastContainer> createState() => _ToastContainerState();
}

class _ToastContainerState extends State<ToastContainer> {
  late final ToastNotificationService _toastService;

  @override
  void initState() {
    super.initState();
    _toastService = ToastNotificationService.instance;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ToastNotification>>(
      stream: _toastService.toastStream,
      initialData: _toastService.activeToasts,
      builder: (context, snapshot) {
        final toasts = snapshot.data ?? [];

        if (toasts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 80, // Above bottom navigation if present
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: toasts.map((toast) {
                return ToastWidget(
                  key: ValueKey(toast.id),
                  notification: toast,
                  onDismiss: () => _toastService.dismiss(toast.id),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay wrapper that can be used to add toast container to the app
class ToastOverlay extends StatelessWidget {
  final Widget child;

  const ToastOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const ToastContainer(),
      ],
    );
  }
}

/// Extension for easy integration into MaterialApp
extension ToastMaterialAppExtension on MaterialApp {
  Widget withToasts() {
    return ToastOverlay(child: this);
  }
}

/// Utility mixin for widgets that need toast notifications
mixin ToastMixin<T extends StatefulWidget> on State<T> {
  ToastNotificationService get toast => ToastNotificationService.instance;

  String showLoading(String message, {bool isDismissible = false}) {
    return toast.showLoading(message, isDismissible: isDismissible);
  }

  String showSuccess(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return toast.showSuccess(message, onAction: onAction, actionLabel: actionLabel);
  }

  String showError(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel = 'Retry',
  }) {
    return toast.showError(message, onAction: onAction, actionLabel: actionLabel);
  }

  String showInfo(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return toast.showInfo(message, onAction: onAction, actionLabel: actionLabel);
  }

  String showWarning(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return toast.showWarning(message, onAction: onAction, actionLabel: actionLabel);
  }

  void dismissToast(String toastId) {
    toast.dismiss(toastId);
  }

  void dismissAllToasts() {
    toast.dismissAll();
  }

  void replaceToast(String oldToastId, ToastNotification newToast) {
    toast.replace(oldToastId, newToast);
  }
}