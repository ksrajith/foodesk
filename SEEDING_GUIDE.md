# Firebase Seeding Instructions

## Product Data Overview

The following food products have been added to the app:

1. **Fried rice set menu chicken** - Rs. 450.00
2. **Fried rice set menu fish** - Rs. 500.00
3. **Fried rice set menu vegetable** - Rs. 400.00
4. **Rice and curry chicken** - Rs. 550.00
5. **Rice and curry fish** - Rs. 600.00
6. **Rice and curry vegetable** - Rs. 450.00
7. **Rice and curry egg** - Rs. 400.00

All products include:
- Product images stored in `assets/ProductImages/`
- Detailed descriptions
- Stock quantities
- Pricing in Sri Lankan Rupees (Rs.)

## How to Seed Firebase

### Method 1: Using the Shell Script (Recommended)

1. Open a terminal in the project directory
2. Run the seed script:
   ```bash
   ./seed_firebase.sh
   ```
3. Enter your vendor credentials when prompted
4. Wait for the seeding process to complete

### Method 2: Manual Command

Run the following command, replacing the placeholders with your actual credentials:

```bash
flutter run -d macos -t lib/scripts/seed_firestore.dart \
  --dart-define=SEED_EMAIL=vendor@demo.com \
  --dart-define=SEED_PASSWORD=demo123 \
  --dart-define=SEED_ORDERS=false
```

**Note:** 
- Use `vendor@demo.com` / `demo123` for the demo vendor account
- Set `SEED_ORDERS=true` if you want to create sample orders
- The script will automatically assign the products to the logged-in vendor

## Viewing the Products

### As a Vendor:
1. Login with vendor credentials
2. Navigate to "My Products"
3. You'll see all 7 food products with images

### As an Admin:
1. Login with admin credentials (admin@demo.com / demo123)
2. Navigate to "All Products"
3. You'll see all products from all vendors

### As a Customer:
1. Login with customer credentials (customer@demo.com / demo123)
2. Browse the product grid on the home screen
3. Click on any product to place an order

## Product Images

All product images are stored locally in the `assets/ProductImages/` folder and are displayed using Flutter's `Image.asset()` widget. This means:
- ✅ No Firebase Storage needed
- ✅ Faster loading times
- ✅ No additional costs
- ✅ Works offline

The images are automatically matched with their respective products based on the filename.
