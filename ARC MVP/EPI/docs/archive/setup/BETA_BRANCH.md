# Beta Branch Workflow

This document explains how to manage the **dev branch** for testing features while keeping a stable **main branch** in production.

---

## 🎯 **Overview**

We maintain **two installable versions** of the ARC app:

| Branch | App Name | Bundle ID | Purpose |
|--------|----------|-----------|---------|
| `main` | **ARC** | `com.epi.arcmvp` | Stable, production-ready |
| `dev-*` | **ARC P2** | `com.epi.arcmvp.priority2` | Testing new features |

Because the bundle IDs are different, **both apps can be installed simultaneously** on the same device.

---

## 📱 **Branch Naming Convention**

- **Current feature branch:** `dev-priority-2-api-refactor`
- **After merging Priority 2:** Rename to just `dev`
- **For Priority 3:** Keep using `dev` (or rename to `dev-priority-3`)

The pattern: Start with `dev-` followed by a descriptive name, then simplify to `dev` after merging.

---

## 🔄 **Complete Workflow**

### **1. Working on a New Feature (e.g., Priority 2)**

```bash
# You're on: dev-priority-2-api-refactor
git checkout dev-priority-2-api-refactor

# Make changes, commit normally
git add .
git commit -m "Your changes"

# Install test version
flutter run
# → Installs "ARC P2" on your device
```

### **2. Testing Phase**

```bash
# Switch between versions anytime:
git checkout main && flutter run           # Install stable "ARC"
git checkout dev-priority-2-api-refactor && flutter run  # Install test "ARC P2"

# Or just launch from home screen - both apps are installed!
```

### **3. Feature is Complete - Merge to Main**

```bash
# Make sure everything is committed
git checkout dev-priority-2-api-refactor
git status  # Should be clean

# Switch to main and merge
git checkout main
git merge dev-priority-2-api-refactor

# Push to remote (if applicable)
git push origin main
```

### **4. Clean Up and Prepare for Next Feature**

```bash
# Rename dev branch to generic "dev"
git branch -m dev-priority-2-api-refactor dev

# Switch to dev branch
git checkout dev

# Reset to match main (clears old commits, keeps bundle ID config!)
git reset --hard main

# Verify bundle ID changes are still there
# Check: ios/Runner.xcodeproj/project.pbxproj
# Should still have: com.epi.arcmvp.priority2
```

**Important:** The `git reset --hard main` command:
- ✅ Clears all feature-specific commits
- ✅ Brings in latest code from `main`
- ✅ **Preserves** the bundle ID changes in the files (because they're part of the branch's files)
- ✅ Gives you a clean slate for the next feature

### **5. Start Next Feature (e.g., Priority 3)**

```bash
# Option A: Keep it as "dev"
git checkout dev
# Continue working...

# Option B: Rename to be more specific
git branch -m dev dev-priority-3
# Continue working...
```

---

## 🎨 **Bundle ID Configuration**

The following files define the separate app identity:

### **iOS:**

**File:** `ios/Runner.xcodeproj/project.pbxproj`
```
PRODUCT_BUNDLE_IDENTIFIER = com.epi.arcmvp.priority2;
```

**File:** `ios/Runner/Info.plist`
```xml
<key>CFBundleDisplayName</key>
<string>ARC P2</string>
```

### **Android** (if configured):

**File:** `android/app/build.gradle`
```gradle
applicationId "com.epi.arcmvp.priority2"
```

---

## 📋 **Quick Reference Commands**

```bash
# See current branch
git branch --show-current

# Install stable version
git checkout main && flutter run

# Install test version
git checkout dev && flutter run  # (or dev-priority-X)

# Rename current branch
git branch -m old-name new-name

# Reset branch to match main (after merge)
git checkout dev
git reset --hard main

# Check if bundle ID is correct
grep -r "com.epi.arcmvp.priority2" ios/Runner.xcodeproj/project.pbxproj
```

---

## 🚨 **Important Notes**

1. **Never delete the dev branch after merging** - Just reset it and reuse it
2. **Always verify bundle ID** after `git reset --hard main` - The changes should persist
3. **Both apps use the same Firebase project** - They share the same backend
4. **Don't push to production with `.priority2` bundle ID** - That's for testing only
5. **The dev branch should never be deployed to App Store/TestFlight**

---

## 🛠️ **Troubleshooting**

### **Problem:** After `git reset --hard main`, bundle ID reverted to `com.epi.arcmvp`

**Solution:**
```bash
# Re-apply bundle ID changes
git checkout dev
# Manually edit:
# - ios/Runner.xcodeproj/project.pbxproj
# - ios/Runner/Info.plist
git add ios/
git commit -m "Restore dev bundle ID configuration"
```

### **Problem:** Both apps have the same name on home screen

**Solution:**
Check `ios/Runner/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>ARC P2</string>  <!-- Should be "ARC P2", not "ARC" -->
```

### **Problem:** Can't install both apps - "App already exists"

**Solution:**
Verify bundle IDs are different:
```bash
# Main branch should have:
com.epi.arcmvp

# Dev branch should have:
com.epi.arcmvp.priority2
```

---

## 📝 **Version History**

- **2025-12-06:** Initial setup for Priority 2 API refactor
- Branch created as `priority-2-api-refactor`
- Renamed to `dev-priority-2-api-refactor` for clarity
- Bundle ID changed to `com.epi.arcmvp.priority2`
- App display name changed to "ARC P2"

---

## 🎯 **Future Improvements**

Consider setting up **Flutter Flavors** for automatic environment management:

```bash
flutter run --flavor dev    # Automatically uses priority2 bundle ID
flutter run --flavor prod   # Automatically uses production bundle ID
```

This would eliminate the need for branch-specific bundle ID changes entirely. See Flutter documentation for flavor setup.

---

**Last Updated:** 2025-12-06
**Maintained By:** Development Team

