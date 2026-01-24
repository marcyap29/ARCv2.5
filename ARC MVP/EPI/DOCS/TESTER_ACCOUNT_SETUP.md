# Tester Account Setup for Apple TestFlight

## Tester Account Credentials

**Email:** `tester1@tester1.com`  
**Password:** `tester1`  
**Tier:** Premium (full access)

## Automatic Premium Access

The tester account automatically receives premium access through the founder emails list in `functions/index.js`. No Stripe subscription is required.

## Creating the Account

### Option 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Users**
4. Click **Add user**
5. Enter:
   - Email: `tester1@tester1.com`
   - Password: `tester1`
   - Check "Email verified" (optional, for easier testing)
6. Click **Add user**

The account will automatically get premium access via the founder emails list.

### Option 2: Firebase CLI

```bash
# Make sure you're logged in and have the correct project selected
firebase login
firebase use <your-project-id>

# Create the user
firebase auth:users:create tester1@tester1.com \
  --password tester1 \
  --display-name "Apple Tester 1" \
  --email-verified true
```

Or use the provided script:
```bash
chmod +x scripts/create_tester_account_firebase_cli.sh
./scripts/create_tester_account_firebase_cli.sh
```

### Option 3: Node.js Script (Most Complete)

```bash
cd functions
npm install  # If not already installed
node ../scripts/create_tester_account.js
```

This script will:
- Create the user account
- Set up Firestore user document with premium tier
- Mark account as testing account

## Verifying Premium Access

After creating the account, the user will automatically receive premium access because:
1. `tester1@tester1.com` is in the `founderEmails` array in `functions/index.js`
2. The `getUserSubscription` function checks this list and returns `tier: 'premium'`

## Testing the Account

1. Open the app
2. Go to Sign In screen
3. Enter:
   - Email: `tester1@tester1.com`
   - Password: `tester1`
4. Sign in
5. Verify premium features are accessible (no throttling, full phase history, etc.)

## Notes

- The account is marked as `isTestingAccount: true` in Firestore
- No Stripe subscription is required
- Premium access is granted via founder emails list (not subscription-based)
- Password can be changed if needed via Firebase Console

## Additional Testers

To add more tester accounts, add them to the `founderEmails` array in `functions/index.js`:

```javascript
const founderEmails = [
  'marcyap@orbitalai.net',
  'tester1@tester1.com',
  'tester2@tester2.com', // Add more as needed
];
```
