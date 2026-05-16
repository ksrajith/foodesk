#!/bin/bash

# Script to seed Firebase with product data
# Make sure you have a supplier account created first

echo "🌱 Starting Firebase seeding process..."
echo ""
echo "Please provide your supplier credentials:"
read -p "Enter supplier email: " SUPPLIER_EMAIL
read -s -p "Enter supplier password: " SUPPLIER_PASSWORD
echo ""
read -p "Do you want to seed sample orders? (true/false): " SEED_ORDERS
echo ""

echo "🚀 Running seed script..."
flutter run -d macos -t lib/scripts/seed_firestore.dart \
  --dart-define=SEED_EMAIL="$SUPPLIER_EMAIL" \
  --dart-define=SEED_PASSWORD="$SUPPLIER_PASSWORD" \
  --dart-define=SEED_ORDERS="$SEED_ORDERS"

echo ""
echo "✅ Seeding complete! Check your Firebase console."
