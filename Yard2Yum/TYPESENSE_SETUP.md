# Typesense Search Integration Setup Guide

## Overview
This guide explains how to integrate Typesense search into the Yard2Yum app for the "Find Nearby Y2Y Organizations" feature.

---

## Part 1: Typesense Cloud Setup

### Step 1: Create a Typesense Cloud Account

1. Go to [https://cloud.typesense.org/](https://cloud.typesense.org/)
2. Click "Sign Up" and create a free account
3. Verify your email address

### Step 2: Create a Cluster

1. After logging in, click "Create Cluster"
2. Choose your configuration:
   - **Cluster Name**: `yard2yum-production` (or your preference)
   - **Region**: Choose the closest to your users
   - **Plan**: Start with the free tier (Development)
3. Click "Create Cluster"
4. Wait for the cluster to provision (usually 2-3 minutes)

### Step 3: Get Your API Credentials

Once your cluster is ready:

1. Click on your cluster name
2. Go to the "API Keys" section
3. You'll see your credentials:
   - **Host**: `xxxxx.a1.typesense.net` (your unique host)
   - **Port**: `443`
   - **Protocol**: `https`
   - **API Key**: A long string like `xyz123abc456...`

**⚠️ Important:** Keep your API key secure! Never commit it to version control.

---

## Part 2: Xcode Project Setup

### Step 1: Add Swift Package Dependencies

1. **Open your Xcode project** (`Yard2Yum.xcworkspace`)

2. **Add Typesense Swift Package:**
   - Go to **File → Add Package Dependencies...**
   - In the search bar, paste: `https://github.com/typesense/typesense-swift`
   - Click "Add Package"
   - Select "Typesense" and click "Add Package"

### Step 2: Add New Files to Project

1. **Add TypesenseManager.swift:**
   - In Xcode, right-click on the "Yard2Yum" folder
   - Select **New File...** → **Swift File**
   - Name it `TypesenseManager.swift`
   - Copy the contents from the provided `TypesenseManager.swift` file

2. **Add NearbyOrganizationsView.swift:**
   - Repeat the process above
   - Name it `NearbyOrganizationsView.swift`
   - Copy the contents from the provided `NearbyOrganizationsView.swift` file

### Step 3: Store API Credentials Securely

**Option A: Using Environment Variables (Recommended for Development)**

1. In Xcode, select your scheme (top bar near Run button)
2. Choose **Edit Scheme...**
3. Select **Run → Arguments**
4. Under "Environment Variables", click **+** and add:
   - Name: `TYPESENSE_API_KEY`
   - Value: Your API key from Typesense Cloud
5. Add another:
   - Name: `TYPESENSE_HOST`
   - Value: Your host (e.g., `xxxxx.a1.typesense.net`)
6. Click "Close"

**Option B: Using UserDefaults (Alternative)**

Add this code to your `Yard2YumApp.swift` or app initialization:

```swift
// ONLY FOR DEVELOPMENT - DO NOT USE IN PRODUCTION
UserDefaults.standard.set("your-api-key-here", forKey: "typesense_api_key")
UserDefaults.standard.set("xxxxx.a1.typesense.net", forKey: "typesense_host")
```

**Option C: Using a Configuration File (Best for Production)**

1. Create a new file: `Config.plist`
2. Add it to your project (make sure "Copy items if needed" is checked)
3. Add your keys:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>TypesenseAPIKey</key>
    <string>your-api-key-here</string>
    <key>TypesenseHost</key>
    <string>xxxxx.a1.typesense.net</string>
</dict>
</plist>
```

4. Add `Config.plist` to your `.gitignore`:
```
Config.plist
```

5. Create a template file `Config.example.plist` with placeholder values for other developers

---

## Part 3: Update ContentView.swift

### Replace Y2YMapView References

Find all instances of `.sheet(isPresented: $showMap) { Y2YMapView()` in `ContentView.swift` and replace with:

```swift
.sheet(isPresented: $showMap) {
    NearbyOrganizationsView()
        .environmentObject(appState)
        .environmentObject(firestoreManager)
}
```

**Locations to update:**
1. `RestaurantPage2` (around line 1540)
2. `FarmPage2` (around line 1906)
3. `FacilityPage2` (around line 2381)

### Optional: Update Button Text

You can also update the button text for clarity:

```swift
Text("🔍  Find Nearby Y2Y Organizations")
```

---

## Part 4: Initialize Typesense Collection

### Create the Collection Schema

You need to create the Typesense collection schema **once** before first use. You have two options:

**Option A: Automatic Creation (Recommended)**

The schema is automatically created when you first open the "Find Organizations" screen. The app will attempt to create it and silently fail if it already exists.

**Option B: Manual Creation via Typesense Dashboard**

1. Go to your Typesense Cloud dashboard
2. Click on your cluster
3. Go to "Collections" tab
4. Click "Create Collection"
5. Use this schema:

```json
{
  "name": "organizations",
  "fields": [
    {
      "name": "id",
      "type": "string"
    },
    {
      "name": "name",
      "type": "string"
    },
    {
      "name": "type",
      "type": "string",
      "facet": true
    },
    {
      "name": "address",
      "type": "string"
    },
    {
      "name": "latitude",
      "type": "float",
      "optional": true
    },
    {
      "name": "longitude",
      "type": "float",
      "optional": true
    }
  ]
}
```

---

## Part 5: Index Existing Organizations

### Sync Firestore Data to Typesense

You need to index your existing organizations from Firestore into Typesense. Add this function to your `FirestoreManager.swift`:

```swift
import FirebaseFirestore

extension FirestoreManager {
    /// Index all organizations from Firestore into Typesense
    func syncOrganizationsToTypesense(typesenseManager: TypesenseManager) async throws {
        let organizations = try await getAllOrganizations()
        
        for org in organizations {
            let name = org.restaurantName ?? org.farmName ?? org.facilityName ?? "Unknown"
            
            try await typesenseManager.indexOrganization(
                id: org.userID,
                name: name,
                type: org.userType,
                address: org.address ?? "",
                latitude: org.latitude,
                longitude: org.longitude
            )
        }
        
        print("Synced \(organizations.count) organizations to Typesense")
    }
}
```

### Run Initial Sync

Add this code to run **once** when you first set up the feature (you can put it in a debug menu or run it manually):

```swift
Task {
    let typesenseManager = TypesenseManager()
    typesenseManager.configure(
        apiKey: "your-api-key",
        host: "your-host"
    )
    
    do {
        try await firestoreManager.syncOrganizationsToTypesense(typesenseManager: typesenseManager)
        print("✅ Initial sync completed!")
    } catch {
        print("❌ Sync failed: \(error.localizedDescription)")
    }
}
```

---

## Part 6: Keep Typesense in Sync

### Index New Organizations Automatically

Update your organization creation/update methods to also index in Typesense:

**In FirestoreManager.swift**, after creating or updating an organization:

```swift
func updateRestaurantInfo(userID: String, name: String, type: String, address: String, latitude: Double, longitude: Double, typesenseManager: TypesenseManager) async throws {
    // Existing Firestore code...
    
    // Also index in Typesense
    try await typesenseManager.indexOrganization(
        id: userID,
        name: name,
        type: "Restaurant",
        address: address,
        latitude: latitude,
        longitude: longitude
    )
}
```

Do the same for `updateFarmInfo()` and `updateFacilityInfo()`.

---

## Part 7: Testing

### Test the Search Feature

1. **Build and Run** the app (⌘R)
2. Sign in as any user type
3. Navigate to the page with "Find Nearby Y2Y Organizations" button
4. Tap the button
5. You should see:
   - A map with organization markers
   - A search bar at the top
   - A list of nearby organizations with distance

### Test Search Functionality

1. Type in the search bar (e.g., "Green")
2. Results should filter in real-time
3. Tap a result to see it highlighted on the map
4. Tap "Get Directions" to open Apple Maps

### Common Issues

**Issue: "Typesense is not configured" error**
- Solution: Check that environment variables are set correctly in scheme settings

**Issue: No search results**
- Solution: Make sure you've run the initial sync to index organizations

**Issue: Search is slow**
- Solution: Check your Typesense cluster status and ensure it's running

**Issue: Build errors about Typesense**
- Solution: Make sure you added the Swift Package dependency correctly

---

## Part 8: Production Deployment

### Security Best Practices

1. **Never commit API keys to Git:**
   ```bash
   # Add to .gitignore
   Config.plist
   *.xcconfig
   ```

2. **Use separate keys for development and production:**
   - Create two Typesense clusters: dev and prod
   - Use different API keys for each environment

3. **Use search-only API keys:**
   - In Typesense Cloud, create a "Search API Key" with limited permissions
   - Never expose your admin API key in the app

4. **Implement backend proxy (recommended for production):**
   - Create a backend endpoint that proxies search requests
   - Store API keys on your backend, not in the app
   - This prevents API key exposure

### Example Backend Proxy (Node.js)

```javascript
// server.js
const express = require('express');
const Typesense = require('typesense');

const app = express();
const client = new Typesense.Client({
  nodes: [{
    host: process.env.TYPESENSE_HOST,
    port: '443',
    protocol: 'https'
  }],
  apiKey: process.env.TYPESENSE_API_KEY,
  connectionTimeoutSeconds: 2
});

app.get('/api/search', async (req, res) => {
  const { q, lat, lon } = req.query;
  
  try {
    const result = await client.collections('organizations')
      .documents()
      .search({
        q: q || '*',
        query_by: 'name,type'
      });
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

Then update your app to call this endpoint instead of Typesense directly.

---

## Part 9: Monitoring & Maintenance

### Monitor Search Performance

1. **Typesense Cloud Dashboard:**
   - View search analytics
   - Monitor query performance
   - Check error rates

2. **Add Analytics in App:**
```swift
func performSearch() async {
    let startTime = Date()
    
    do {
        let results = try await typesenseManager.searchOrganizations(...)
        let duration = Date().timeIntervalSince(startTime)
        
        // Log to analytics
        print("Search completed in \(duration)s with \(results.count) results")
    } catch {
        // Log errors
        print("Search failed: \(error)")
    }
}
```

### Update Collection Schema

If you need to add new fields:

1. Create a new collection with the updated schema
2. Re-index all organizations
3. Update your app to use the new collection
4. Delete the old collection

---

## Summary Checklist

- [ ] Created Typesense Cloud account and cluster
- [ ] Obtained API key and host
- [ ] Added Typesense Swift Package to Xcode
- [ ] Added `TypesenseManager.swift` and `NearbyOrganizationsView.swift`
- [ ] Configured API credentials (environment variables or config file)
- [ ] Updated `ContentView.swift` to use `NearbyOrganizationsView`
- [ ] Created Typesense collection schema
- [ ] Ran initial sync to index existing organizations
- [ ] Updated organization CRUD methods to sync with Typesense
- [ ] Tested search functionality
- [ ] Added `.gitignore` entries for sensitive files
- [ ] Implemented production security measures

---

## Additional Resources

- [Typesense Documentation](https://typesense.org/docs/)
- [Typesense Swift Client](https://github.com/typesense/typesense-swift)
- [Typesense Cloud Console](https://cloud.typesense.org/)

---

## Support

If you encounter issues:

1. Check the Xcode console for error messages
2. Verify your Typesense cluster is running in the dashboard
3. Test your API key with curl:
   ```bash
   curl -H "X-TYPESENSE-API-KEY: your-key" \
        https://your-host/collections
   ```
4. Check the Typesense community forum: [https://github.com/typesense/typesense/discussions](https://github.com/typesense/typesense/discussions)
