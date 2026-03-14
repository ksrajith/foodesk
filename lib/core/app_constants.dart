/// Centralized route names and Firestore collection names.
class AppConstants {
  AppConstants._();

  // Firestore collections
  static const String collectionProducts = 'products';
  static const String collectionOrders = 'orders';
  static const String collectionUsers = 'users';
  static const String collectionRegistrationRequests = 'registration_requests';
  static const String collectionAppSettings = 'app_settings';

  // Route names (match main.dart routes)
  static const String routeSplash = '/splash';
  static const String routeLogin = '/';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeAdminDashboard = '/admin-dashboard';
  static const String routeAdminPendingRegistrations = '/admin-pending-registrations';
  static const String routeAdminApprovedRegistrations = '/admin-approved-registrations';
  static const String routeAdminSettings = '/admin-settings';
  static const String routeAdminProducts = '/admin-products';
  static const String routeAdminOrders = '/admin-orders';
  static const String routeAdminTotalOrders = '/admin-total-orders';
  static const String routeSupplierDashboard = '/supplier-dashboard';
  static const String routeSupplierProducts = '/supplier-products';
  static const String routeSupplierOrders = '/supplier-orders';
  static const String routeSupplierLateOrders = '/supplier-late-orders';
  static const String routeSupplierOrderSummary = '/supplier-order-summary';
  static const String routeCustomerHome = '/customer-home';
  static const String routeCustomerOrderHistory = '/customer-order-history';
  static const String routePool = '/pool';
}
