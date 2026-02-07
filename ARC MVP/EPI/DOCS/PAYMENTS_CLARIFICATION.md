# Payments Clarification

**Last Updated:** February 7, 2026

---

## Where purchases happen

- **Stripe purchases** are made on the **web** (Stripe Checkout and Customer Portal in the browser).
- **In-app purchases** are made **in the app** (Apple App Store / Google Play, via RevenueCat).

Both channels can grant premium access (e.g. ARC Pro). The app should treat a user as premium if they have an active subscription from **either** Stripe (web) or in-app (RevenueCat).

---

## Related docs

- **Stripe (web):** [DOCS/stripe/README.md](stripe/README.md)
- **In-app (RevenueCat):** [DOCS/revenuecat/README.md](revenuecat/README.md)
