/**
 * Script to create tester account for Apple TestFlight
 * 
 * Run this script using Node.js with Firebase Admin SDK:
 * node scripts/create_tester_account.js
 * 
 * Or use Firebase CLI:
 * firebase auth:import scripts/tester_account.json
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
// Make sure you have GOOGLE_APPLICATION_CREDENTIALS set or initialize with service account
if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (e) {
    console.error('Failed to initialize Firebase Admin:', e);
    console.error('Make sure you have Firebase Admin SDK configured');
    process.exit(1);
  }
}

const auth = admin.auth();
const db = admin.firestore();

async function createTesterAccount() {
  const email = 'tester1@tester1.com';
  const password = 'tester1';
  
  try {
    console.log(`Creating tester account: ${email}`);
    
    // Check if user already exists
    let user;
    try {
      user = await auth.getUserByEmail(email);
      console.log(`User ${email} already exists with UID: ${user.uid}`);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        // User doesn't exist, create it
        user = await auth.createUser({
          email: email,
          password: password,
          emailVerified: true, // Mark as verified for easier testing
          displayName: 'Apple Tester 1',
        });
        console.log(`✅ Created user: ${email} with UID: ${user.uid}`);
      } else {
        throw e;
      }
    }
    
    // Set up Firestore user document with premium tier
    const userRef = db.collection('users').doc(user.uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      // Create user document
      await userRef.set({
        email: email,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        subscriptionTier: 'premium',
        subscriptionStatus: 'active',
        isTestingAccount: true,
        // Note: No stripeSubscriptionId needed for founder/test accounts
      }, { merge: true });
      console.log(`✅ Created Firestore user document with premium tier`);
    } else {
      // Update existing document to ensure premium tier
      await userRef.update({
        subscriptionTier: 'premium',
        subscriptionStatus: 'active',
        isTestingAccount: true,
      });
      console.log(`✅ Updated Firestore user document to premium tier`);
    }
    
    console.log('\n✅ Tester account setup complete!');
    console.log(`   Email: ${email}`);
    console.log(`   Password: ${password}`);
    console.log(`   UID: ${user.uid}`);
    console.log(`   Tier: premium`);
    console.log('\n📱 Testers can now sign in with these credentials in the app.');
    
  } catch (error) {
    console.error('❌ Error creating tester account:', error);
    process.exit(1);
  }
}

// Run the script
createTesterAccount()
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
