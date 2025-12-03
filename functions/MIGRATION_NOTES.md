# Migration Notes: Venice AI → Gemini + Claude

## What Changed

### Removed
- ❌ `index.js` - Old Venice AI proxy function (archived as `index.js.old-venice`)
- ❌ Venice AI API integration
- ❌ `VENICE_API_KEY` secret dependency

### Added
- ✅ TypeScript backend (`src/` directory)
- ✅ Gemini Flash & Pro clients
- ✅ Claude Haiku & Sonnet clients
- ✅ Model router system
- ✅ Tier-based quota enforcement
- ✅ Firestore counter tracking
- ✅ Stripe webhook handler

## Breaking Changes

**None!** The API shape is preserved:
- `httpsCallable('analyzeJournalEntry')` - Still works
- `httpsCallable('sendChatMessage')` - Still works

## Frontend Updates Required

**None!** The frontend can continue using the same function calls.

However, you may want to:
1. Update error handling for new quota error codes
2. Display tier information in UI
3. Show upgrade prompts when limits reached

## Deployment Checklist

- [ ] Remove `VENICE_API_KEY` secret (no longer needed)
- [ ] Set `GEMINI_API_KEY` secret
- [ ] Set `ANTHROPIC_API_KEY` secret
- [ ] Build TypeScript: `npm run build`
- [ ] Deploy: `firebase deploy --only functions`
- [ ] Test with free tier user
- [ ] Test with paid tier user
- [ ] Verify old `veniceProxy` function is removed/disabled

## Rollback Plan

If needed, you can temporarily rollback:
1. Restore `index.js` from `index.js.old-venice`
2. Redeploy old function
3. Note: This requires Venice AI API key to still be valid

## Data Migration

No Firestore data migration needed. The new functions work with existing:
- `users/{userId}` documents (just add `subscriptionTier` field)
- `journalEntries/{entryId}` documents (add `analysisCount` field if missing)
- `chatThreads/{threadId}` documents (add `messageCount` field if missing)

Default values:
- `subscriptionTier: "FREE"` for existing users
- `analysisCount: 0` for existing entries
- `messageCount: 0` for existing threads

