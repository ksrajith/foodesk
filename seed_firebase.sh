#!/bin/bash

# Script to seed Firebase with product data
# Make sure you have a vendor account created first

echo "🌱 Starting Firebase seeding process..."
echo ""
echo "Please provide your vendor credentials:"
read -p "Enter vendor email: " VENDOR_EMAIL
read -s -p "Enter vendor password: " VENDOR_PASSWORD
echo ""
read -p "Do you want to seed sample orders? (true/false): " SEED_ORDERS
echo ""

echo "🚀 Running seed script..."
flutter run -d macos -t lib/scripts/seed_firestore.dart \
  --dart-define=SEED_EMAIL="$VENDOR_EMAIL" \
  --dart-define=SEED_PASSWORD="$VENDOR_PASSWORD" \
  --dart-define=SEED_ORDERS="$SEED_ORDERS"

echo ""
echo "✅ Seeding complete! Check your Firebase console."
