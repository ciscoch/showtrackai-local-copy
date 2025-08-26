import 'dart:async';
import 'package:flutter/material.dart';

/// Toast notification types for different states
enum ToastType {
  loading,
  success,
  error,
  info,
  warning,
}

/// Toast action callback type
typedef ToastActionCallback = void Function();

/// Individual toast notification data model
class ToastNotification {
  final String id;
  final String message;
  final ToastType type;
  final Duration duration;
  final ToastActionCallback? onAction;
  final String? actionLabel;
  final bool isDismissible;
  final DateTime createdAt;

  ToastNotification({
    required this.id,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 3),
    this.onAction,
    this.actionLabel,
    this.isDismissible = true,
  }) : createdAt = DateTime.now();

  /// Create a loading toast
  static ToastNotification loading({
    required String message,
    Duration duration = const Duration(seconds: 10),
    bool isDismissible = false,
  }) {
    return ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: ToastType.loading,
      duration: duration,
      isDismissible: isDismissible,
    );
  }

  /// Create a success toast
  static ToastNotification success({
    required String message,
    Duration duration = const Duration(seconds: 4),
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: ToastType.success,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Create an error toast
  static ToastNotification error({
    required String message,
    Duration duration = const Duration(seconds: 6),
    ToastActionCallback? onAction,
    String? actionLabel = 'Retry',
  }) {
    return ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: ToastType.error,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Create an info toast
  static ToastNotification info({
    required String message,
    Duration duration = const Duration(seconds: 4),
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: ToastType.info,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Create a warning toast
  static ToastNotification warning({
    required String message,
    Duration duration = const Duration(seconds: 5),
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return ToastNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: ToastType.warning,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }
}

/// Global toast notification manager service
class ToastNotificationService {
  static final ToastNotificationService _instance = ToastNotificationService._internal();
  factory ToastNotificationService() => _instance;
  ToastNotificationService._internal();

  static ToastNotificationService get instance => _instance;

  final List<ToastNotification> _activeToasts = [];
  final StreamController<List<ToastNotification>> _toastController = 
      StreamController<List<ToastNotification>>.broadcast();
  final Map<String, Timer> _timers = {};

  /// Stream of active toasts for UI to listen to
  Stream<List<ToastNotification>> get toastStream => _toastController.stream;

  /// Get current active toasts
  List<ToastNotification> get activeToasts => List.unmodifiable(_activeToasts);

  /// Show a toast notification
  void show(ToastNotification toast) {
    // Remove any existing toast with the same ID
    dismiss(toast.id);

    // Add new toast
    _activeToasts.add(toast);
    _toastController.add(List.from(_activeToasts));

    // Set up auto-dismissal timer for non-loading toasts
    if (toast.type != ToastType.loading && toast.isDismissible) {
      _timers[toast.id] = Timer(toast.duration, () {
        dismiss(toast.id);
      });
    }
  }

  /// Dismiss a specific toast by ID
  void dismiss(String toastId) {
    _activeToasts.removeWhere((toast) => toast.id == toastId);
    _timers[toastId]?.cancel();
    _timers.remove(toastId);
    _toastController.add(List.from(_activeToasts));
  }

  /// Dismiss all toasts
  void dismissAll() {
    _activeToasts.clear();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _toastController.add(List.from(_activeToasts));
  }

  /// Replace an existing toast with a new one (useful for updating loading states)
  void replace(String oldToastId, ToastNotification newToast) {
    dismiss(oldToastId);
    show(newToast);
  }

  /// Show loading toast
  String showLoading(String message, {bool isDismissible = false}) {
    final toast = ToastNotification.loading(
      message: message,
      isDismissible: isDismissible,
    );
    show(toast);
    return toast.id;
  }

  /// Show success toast
  String showSuccess(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    final toast = ToastNotification.success(
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
    show(toast);
    return toast.id;
  }

  /// Show error toast
  String showError(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel = 'Retry',
  }) {
    final toast = ToastNotification.error(
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
    show(toast);
    return toast.id;
  }

  /// Show info toast
  String showInfo(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    final toast = ToastNotification.info(
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
    show(toast);
    return toast.id;
  }

  /// Show warning toast
  String showWarning(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    final toast = ToastNotification.warning(
      message: message,
      onAction: onAction,
      actionLabel: actionLabel,
    );
    show(toast);
    return toast.id;
  }

  /// Dispose of the service
  void dispose() {
    dismissAll();
    _toastController.close();
  }
}

/// Convenience methods for quick access to toast service
class Toast {
  static ToastNotificationService get _service => ToastNotificationService.instance;

  static String loading(String message, {bool isDismissible = false}) {
    return _service.showLoading(message, isDismissible: isDismissible);
  }

  static String success(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return _service.showSuccess(message, onAction: onAction, actionLabel: actionLabel);
  }

  static String error(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel = 'Retry',
  }) {
    return _service.showError(message, onAction: onAction, actionLabel: actionLabel);
  }

  static String info(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return _service.showInfo(message, onAction: onAction, actionLabel: actionLabel);
  }

  static String warning(
    String message, {
    ToastActionCallback? onAction,
    String? actionLabel,
  }) {
    return _service.showWarning(message, onAction: onAction, actionLabel: actionLabel);
  }

  static void dismiss(String toastId) {
    _service.dismiss(toastId);
  }

  static void dismissAll() {
    _service.dismissAll();
  }

  static void replace(String oldToastId, ToastNotification newToast) {
    _service.replace(oldToastId, newToast);
  }
}