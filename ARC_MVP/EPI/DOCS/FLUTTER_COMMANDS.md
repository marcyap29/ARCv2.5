# Flutter commands:
- flutter build ios --release && flutter install -d 00008140-0008056E0893C01C
- flutter clean && flutter pub get

# Deploy Firebase Functions (from workspace root ARCv2.5, NOT from EPI):
  cd /Users/mymac/Software/Development/ARCv2.5
  cd functions && npm run build && firebase deploy --only functions:swarmspacePluginCatalog
# Or deploy all functions:
  cd functions && npm run build && firebase deploy --only functions       
# Verify Secrets:
  firebase functions:secrets:access 'API_KEY'     