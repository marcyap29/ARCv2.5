# Setting Up API Keys for Firebase Functions

## Correct Way to Set Gemini API Key

### Step 1: Run the command with the SECRET NAME (not the key value)

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

### Step 2: When prompted, paste your API key value

```
Enter a value for GEMINI_API_KEY: [paste: AIzaSyD0EqMv1xzdU4QkvRUTJ48Xgo7dA1A8Qpw]
```

### Step 3: Verify it was set correctly

```bash
# Access the secret (will prompt for confirmation)
firebase functions:secrets:access GEMINI_API_KEY
```

## Common Mistakes

❌ **WRONG**: `firebase functions:secrets:set AIzaSyD0EqMv1xzdU4QkvRUTJ48Xgo7dA1A8Qpw`
- This uses the API key VALUE as the secret NAME
- Creates a secret with a weird auto-generated name

✅ **CORRECT**: `firebase functions:secrets:set GEMINI_API_KEY`
- Uses the proper secret NAME
- Then prompts you to enter the API key VALUE

## Complete Setup

```bash
# 1. Set Gemini API key
firebase functions:secrets:set GEMINI_API_KEY
# [Enter: AIzaSyD0EqMv1xzdU4QkvRUTJ48Xgo7dA1A8Qpw when prompted]

# 2. (Optional) Set Claude API key for failover
firebase functions:secrets:set ANTHROPIC_API_KEY
# [Enter your Claude API key when prompted]

# 3. Build and deploy
cd functions
npm run build
cd ..
firebase deploy --only functions
```

## Secret Names Used in Code

The backend code expects these exact secret names:
- `GEMINI_API_KEY` - Your Gemini API key
- `ANTHROPIC_API_KEY` - Your Claude API key (optional)

These are defined in `functions/src/config.ts`:
```typescript
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
```

## Troubleshooting

If you accidentally created a secret with the wrong name:
```bash
# Delete the incorrect secret
firebase functions:secrets:delete [WRONG_SECRET_NAME]

# Then set it correctly
firebase functions:secrets:set GEMINI_API_KEY
```
