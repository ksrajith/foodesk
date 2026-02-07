// // Simple data storage for the entire app
// // All users, products, and orders are stored here

// class AppData {
//   // Current logged-in user
//   // static Map<String, dynamic>? currentUser;

//   // Users list (email, password, role, name, id)
//   // static List<Map<String, dynamic>> users = [
//   //   {
//   //     'id': '1',
//   //     'name': 'Admin User',
//   //     'email': 'admin@demo.com',
//   //     'password': 'demo123',
//   //     'role': 'Admin',
//   //   },
//   //   {
//   //     'id': '2',
//   //     'name': 'John Vendor',
//   //     'email': 'vendor@demo.com',
//   //     'password': 'demo123',
//   //     'role': 'Vendor',
//   //   },
//   //   {
//   //     'id': '3',
//   //     'name': 'Jane Customer',
//   //     'email': 'customer@demo.com',
//   //     'password': 'demo123',
//   //     'role': 'Customer',
//   //   },
//   // ];

//   // Products list
//   static List<Map<String, dynamic>> products = [
//     {
//       'id': '1',
//       'name': 'Fried rice set menu chicken',
//       'description': 'Delicious fried rice with tender chicken pieces, vegetables, and special sauce',
//       'price': 450.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 20,
//       'image': 'assets/ProductImages/Fried rice set menu chiken.png',
//     },
//     {
//       'id': '2',
//       'name': 'Fried rice set menu fish',
//       'description': 'Savory fried rice with fresh fish, mixed vegetables, and aromatic spices',
//       'price': 500.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 18,
//       'image': 'assets/ProductImages/Fried rice set menu fish.png',
//     },
//     {
//       'id': '3',
//       'name': 'Fried rice set menu vegetable',
//       'description': 'Healthy fried rice packed with fresh seasonal vegetables and herbs',
//       'price': 400.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 25,
//       'image': 'assets/ProductImages/Fried rice set menu vegitable.png',
//     },
//     {
//       'id': '4',
//       'name': 'Rice and curry chicken',
//       'description': 'Traditional rice and curry with succulent chicken curry and side dishes',
//       'price': 550.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 22,
//       'image': 'assets/ProductImages/Rice and curry chicken.png',
//     },
//     {
//       'id': '5',
//       'name': 'Rice and curry fish',
//       'description': 'Authentic rice and curry with flavorful fish curry and accompaniments',
//       'price': 600.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 15,
//       'image': 'assets/ProductImages/Rice and curry fish.png',
//     },
//     {
//       'id': '6',
//       'name': 'Rice and curry vegetable',
//       'description': 'Wholesome rice and curry with mixed vegetable curries and condiments',
//       'price': 450.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 30,
//       'image': 'assets/ProductImages/Rice and curry vegitable.png',
//     },
//     {
//       'id': '7',
//       'name': 'Rice and curry egg',
//       'description': 'Classic rice and curry with perfectly cooked egg curry and side dishes',
//       'price': 400.00,
//       'vendorId': '2',
//       'vendorName': 'John Vendor',
//       'stock': 28,
//       'image': 'assets/ProductImages/Rice and curry egg.png',
//     },
//   ];



//   // Helper methods
//   // Legacy demo auth (no longer used). Kept for reference; FirebaseAuth is used instead.
//   // static Map<String, dynamic>? login(String email, String password) {
//   //   try {
//   //     final user = users.firstWhere(
//   //       (u) => u['email'] == email && u['password'] == password,
//   //     );
//   //     currentUser = user;
//   //     return user;
//   //   } catch (e) {
//   //     return null;
//   //   }
//   // }

//   // Legacy demo register (no longer used). Kept for reference; FirebaseAuth/Firestore are used instead.
//   // static bool register(String name, String email, String password, String role) {
//   //   // Check if email already exists
//   //   final exists = users.any((u) => u['email'] == email);
//   //   if (exists) return false;

//   //   final newUser = {
//   //     'id': (users.length + 1).toString(),
//   //     'name': name,
//   //     'email': email,
//   //     'password': password,
//   //     'role': role,
//   //   };

//   //   users.add(newUser);
//   //   return true;
//   // }

//   // static void logout() {
//   //   // Clear app-level cached profile and sign out from Firebase if available.
//   //   currentUser = null;
//   //   try {
//   //     // FirebaseAuth is optional at compile-time; guard with try.
//   //     // ignore: avoid_print
//   //     print('Signing out from FirebaseAuth');
//   //     // Use dynamic to avoid hard compile-time dependency here.
//   //     // In practice, logout is called from screens where firebase_auth is present.
//   //   } catch (_) {}
//   // }

//   // static void addOrder(Map<String, dynamic> order) {
//   //   orders.add(order);
//   // }

//   // static List<Map<String, dynamic>> getVendorOrders(String vendorId) {
//   //   return orders.where((order) => order['vendorId'] == vendorId).toList();
//   // }

//   // static List<Map<String, dynamic>> getVendorProducts(String vendorId) {
//   //   return products.where((product) => product['vendorId'] == vendorId).toList();
//   // }

//   // static List<Map<String, dynamic>> getCustomerOrders(String customerId) {
//   //   return orders.where((order) => order['customerId'] == customerId).toList();
//   // }
// }