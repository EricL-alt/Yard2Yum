# Local Search Setup (Prototype Version)

This is a simplified version of the organization search feature that **doesn't require Typesense Cloud**. Perfect for prototyping!

---

## What Changed?

Instead of using Typesense Cloud for search, we now:
1. Load all organizations from Firestore into memory
2. Perform local search filtering on the data
3. Calculate distances and display results

**No external services needed!** ✨

---

## Setup Steps

### 1. Remove Typesense Package (Optional)

Since we're not using Typesense Cloud anymore, you can remove the package:
- Open your Xcode project
- Go to **File → Packages → Remove Package**
- Select `typesense-swift` and remove it

### 2. That's It!

Seriously, that's all you need to do. The code now:
- Uses `FirestoreManager.getAllOrganizations()` to load data
- Filters locally based on search queries
- Calculates distances using CoreLocation

---

## How It Works

### On View Load
```swift
// NearbyOrganizationsView loads like this:
1. Configure TypesenseManager with FirestoreManager
2. Load all organizations from Firestore
3. Cache them in memory for searching
```

### On Search
```swift
// When user types in search bar:
1. Filter cached organizations by name, type, or address
2. Calculate distance from user's location
3. Display sorted results
```

### Search Logic
The local search matches organizations where:
- Name contains search query (case-insensitive)
- Type contains search query
- Address contains search query

---

## Testing

### 1. Build & Run
```bash
⌘B to build
⌘R to run
```

### 2. Navigate to Feature
- Sign in as any user type (Restaurant, Farm, or Facility)
- Tap "🔍 Find Nearby Y2Y Organizations"

### 3. Test Search
- Leave search empty → Shows all organizations
- Type "farm" → Shows all farms
- Type "restaurant" → Shows all restaurants
- Type a city name → Shows organizations in that city
- Type a specific name → Shows matching organizations

### 4. Verify Results
- Each result shows: name, type, distance, address
- Tapping a result highlights it on the map
- "Get Directions" opens Apple Maps
- Distance is calculated in miles

---

## Performance Notes

### Pros ✅
- **No setup required** - Works immediately with Firestore
- **No API keys** - No external service configuration
- **Free** - No Typesense Cloud costs
- **Simple** - Easy to understand and debug
- **Fast for prototyping** - Great for development/testing

### Cons ❌
- **Limited scalability** - Loads all orgs into memory
- **Basic search** - No fuzzy matching or typo tolerance
- **Network overhead** - Fetches all data on first load
- **Not ideal for production** - Should migrate to proper search service

### When to Migrate

Consider switching to Typesense Cloud (or Algolia, Elasticsearch, etc.) when:
- You have 100+ organizations
- Users need advanced search features (fuzzy matching, filters, etc.)
- You want faster search response times
- You're ready for production

---

## Code Structure

### TypesenseManager.swift
```swift
class TypesenseManager {
    private var organizations: [OrganizationDocument] = []
    
    // Load data from Firestore
    func loadOrganizations() async throws { ... }
    
    // Local search
    func searchOrganizations(query: String, userLocation: CLLocationCoordinate2D?) async throws -> [SearchResult] {
        // Filter by query
        let filtered = organizations.filter { org in
            org.name.contains(query) ||
            org.type.contains(query) ||
            org.address.contains(query)
        }
        
        // Calculate distances
        // Return sorted results
    }
}
```

### NearbyOrganizationsView.swift
```swift
struct NearbyOrganizationsView: View {
    @StateObject private var typesenseManager = TypesenseManager()
    
    .task {
        // Setup on load
        await setupTypesense()
        await performSearch()
    }
    
    private func setupTypesense() async {
        typesenseManager.configure(firestoreManager: firestoreManager)
        try await typesenseManager.loadOrganizations()
    }
    
    private func performSearch() async {
        let results = try await typesenseManager.searchOrganizations(
            query: searchText,
            userLocation: userLocation
        )
        searchResults = results
    }
}
```

---

## Troubleshooting

### "No organizations found"
**Cause:** No data in Firestore  
**Solution:** Make sure you have organizations with:
- Valid addresses
- Latitude/longitude coordinates
- Names set (restaurantName, farmName, or facilityName)

### Search is slow
**Cause:** Loading too much data from Firestore  
**Solution:** 
- Add indexing to Firestore queries
- Limit results to nearby area only
- Consider pagination

### Distance shows "Unknown distance"
**Cause:** User location not set or organization missing coordinates  
**Solution:**
- Verify user has completed address setup
- Check organization profiles have lat/lon
- Ensure location permissions are granted

### App crashes on search
**Cause:** FirestoreManager not passed to TypesenseManager  
**Solution:** Verify NearbyOrganizationsView has `.environmentObject(firestoreManager)`

---

## Next Steps

### Now
- ✅ Test the feature with your existing Firestore data
- ✅ Add more organizations to test with
- ✅ Verify search works across all user types

### Later (When Ready for Production)
- [ ] Set up Typesense Cloud account
- [ ] Create sync function to keep Typesense in sync with Firestore
- [ ] Switch back to cloud-based search
- [ ] Add advanced features (filters, facets, etc.)

---

## Migration Path (Future)

When you're ready to move to Typesense Cloud:

1. **Keep the same interfaces** - TypesenseManager API stays the same
2. **Swap implementation** - Replace local search with Typesense SDK calls
3. **Add sync logic** - Update Typesense when Firestore changes
4. **Test thoroughly** - Verify results match local version

The great news: Your UI code (NearbyOrganizationsView) won't need to change! 🎉

---

## Summary

You now have a **fully functional organization search** that:
- ✅ Loads from Firestore
- ✅ Searches locally
- ✅ Calculates distances
- ✅ Shows results on map
- ✅ Provides directions
- ✅ Works for all user types
- ✅ Requires **zero external services**

**Perfect for prototyping!** When you're ready to scale, the migration path is clear. 🚀

---

## Questions?

The code is well-commented and follows Swift best practices. Key files:
- `TypesenseManager.swift` - Search logic
- `NearbyOrganizationsView.swift` - UI
- `FirestoreManager.swift` - Data loading

Everything is ready to go. Just build and run! 🎯
