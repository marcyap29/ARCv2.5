# Stripe Success/Cancel Pages Setup

## Problem

When users complete Stripe checkout, they're redirected to success/cancel URLs. Currently, these URLs use deep links (`arc://subscription/success`) which don't work in browsers, causing "page not found" errors.

## Solution

Create simple HTML pages that:
1. Show a success/cancel message
2. Optionally redirect back to the app
3. Work in any browser

## Quick Fix: Simple HTML Pages

### Option 1: Host Simple Pages

Create two simple HTML files and host them:

**success.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Subscription Successful</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-top: 0; }
        p { font-size: 1.1rem; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>✅ Subscription Successful!</h1>
        <p>Thank you for subscribing to ARC Premium.</p>
        <p>You can close this window and return to the app.</p>
        <p><small>Your subscription will be activated automatically.</small></p>
    </div>
</body>
</html>
```

**cancel.html:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Subscription Cancelled</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-top: 0; }
        p { font-size: 1.1rem; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Subscription Cancelled</h1>
        <p>You cancelled the subscription process.</p>
        <p>You can close this window and return to the app.</p>
    </div>
</body>
</html>
```

### Option 2: Use GitHub Pages (Free)

1. Create a GitHub repository
2. Add the HTML files
3. Enable GitHub Pages
4. Use URLs like: `https://yourusername.github.io/repo/success.html`

### Option 3: Use Firebase Hosting (If You Have It)

1. Add files to `public/` directory
2. Deploy: `firebase deploy --only hosting`
3. Use URLs like: `https://your-project.web.app/subscription/success`

### Option 4: Use a Simple Redirect Service

Use a service like:
- `https://yourdomain.com/subscription/success` → Shows message
- Or use a redirect service that redirects to app

## Update URLs in Code

After hosting the pages, update the URLs in:

1. **Flutter App** (`lib/services/subscription_service.dart`):
```dart
'successUrl': 'https://yourdomain.com/subscription/success?session_id={CHECKOUT_SESSION_ID}',
'cancelUrl': 'https://yourdomain.com/subscription/cancel',
```

2. **Firebase Functions** (`functions/index.js`):
The fallback URLs will be used if not provided by the app.

## Important Notes

- **Webhook handles subscription**: The actual subscription activation is handled by the Stripe webhook, not these pages
- **These pages are for UX**: They just provide user feedback
- **Deep links don't work in browsers**: That's why we need web URLs
- **Session ID in URL**: The `{CHECKOUT_SESSION_ID}` placeholder is automatically replaced by Stripe

## Testing

1. Complete a test checkout
2. You should be redirected to your success page
3. Check that the webhook updated the subscription in Firestore
4. Verify subscription status in the app

## Current Status

Currently using:
- Success: `https://arc-app.com/subscription/success?session_id={CHECKOUT_SESSION_ID}`
- Cancel: `https://arc-app.com/subscription/cancel`

**If `arc-app.com` is not set up, you'll get "page not found" errors.**
