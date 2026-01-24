#!/bin/bash
# Script to create tester account using Firebase CLI
# 
# Prerequisites:
# 1. Install Firebase CLI: npm install -g firebase-tools
# 2. Login: firebase login
# 3. Set project: firebase use <project-id>
#
# Usage: ./scripts/create_tester_account_firebase_cli.sh

EMAIL="tester1@tester1.com"
PASSWORD="tester1"

echo "Creating tester account: $EMAIL"

# Create user via Firebase CLI
firebase auth:users:create "$EMAIL" \
  --password "$PASSWORD" \
  --display-name "Apple Tester 1" \
  --email-verified true

if [ $? -eq 0 ]; then
  echo "✅ User created successfully"
  echo ""
  echo "📝 Next steps:"
  echo "1. The user will automatically get premium access via founder emails list in functions/index.js"
  echo "2. Optionally, update Firestore to set subscriptionTier: 'premium'"
  echo ""
  echo "To update Firestore, run this in Firebase Console or use Admin SDK:"
  echo "  db.collection('users').doc('<uid>').set({"
  echo "    subscriptionTier: 'premium',"
  echo "    subscriptionStatus: 'active',"
  echo "    isTestingAccount: true"
  echo "  }, { merge: true })"
else
  echo "❌ Failed to create user. User may already exist."
  echo "   If user exists, you can reset password with:"
  echo "   firebase auth:users:update $EMAIL --password $PASSWORD"
fi
