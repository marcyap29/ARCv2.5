# Stripe Webhook Setup - Visual Guide

## You're on the Right Page! ✅

You're currently on the **"Select events"** screen for setting up your webhook destination. This is exactly where you need to be!

---

## Step-by-Step Instructions

### Step 1: API Version (Top Section)

**You see:** A dropdown that says "2025-07-30.basil"

**What to do:**
- ✅ **Keep it on "2025-07-30.basil"** (or "2023-10-16" if that's an option)
- This is the stable version - perfect for your setup
- Don't change it unless you specifically need clover features

### Step 2: Events Section (Main Area)

**You see:** 
- Tabs: "All events" and "Selected events 0"
- Search bar: "Find event by name or description..."
- A long list of event types with arrows `>`

**What to do:**

1. **Make sure "All events" tab is selected** (it should be, with purple underline)

2. **Use the search bar** to find the specific events you need:
   - Type: `checkout.session.completed`
   - Type: `customer.subscription`
   - Type: `invoice.payment`

3. **Select these specific events** (click the checkbox next to each):
   - ✅ `checkout.session.completed`
   - ✅ `customer.subscription.created`
   - ✅ `customer.subscription.updated`
   - ✅ `customer.subscription.deleted`
   - ✅ `invoice.payment_succeeded`
   - ✅ `invoice.payment_failed`

### Step 3: How to Find Events

**Method 1: Search (Easiest)**
1. Click in the search bar
2. Type: `checkout.session.completed`
3. It will filter and show matching events
4. Check the box next to it
5. Repeat for each event

**Method 2: Browse Categories**
- Look for categories like:
  - **"Checkout Session"** → expand it → find `checkout.session.completed`
  - **"Customer Subscription"** → expand it → find the subscription events
  - **"Invoice"** → expand it → find payment events

### Step 4: After Selecting Events

1. You'll see the count in "Selected events" tab increase (e.g., "Selected events 6")
2. Click the **"Continue"** button (purple button, bottom right)
3. You'll be taken to the next screen to enter your endpoint URL

---

## What You'll See Next

After clicking "Continue", you'll see a screen asking for:
- **Endpoint URL**: This is where you'll paste:
  ```
  https://us-central1-arc-epi.cloudfunctions.net/stripeWebhook
  ```

---

## Quick Checklist

- [ ] API version: Keep on basil (2025-07-30.basil or 2023-10-16)
- [ ] Select these 6 events:
  - [ ] `checkout.session.completed`
  - [ ] `customer.subscription.created`
  - [ ] `customer.subscription.updated`
  - [ ] `customer.subscription.deleted`
  - [ ] `invoice.payment_succeeded`
  - [ ] `invoice.payment_failed`
- [ ] Click "Continue" button
- [ ] Enter endpoint URL on next screen

---

## Still Can't Find Events?

If you can't find the events by searching:

1. **Scroll down** - the list is long
2. **Look for these category names:**
   - "Checkout Session" (for checkout events)
   - "Customer Subscription" (for subscription events)
   - "Invoice" (for payment events)
3. **Click the arrow `>`** next to category names to expand them
4. **Check the boxes** next to the specific events you need

---

**You're doing great!** Just select those 6 events and click Continue. 🎯

