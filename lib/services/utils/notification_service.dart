class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Basic notification service without chat functionality
  // This can be expanded for other types of notifications in the future
  
  void showNotification(String message) {
    // Placeholder for future notification implementation
  }
}