# Debugging: Organization Names Not Showing

## 🔍 Problem
Organization names are not displaying in the search results.

---

## 🎯 Diagnosis Steps

### Step 1: Check Console Logs

When you run the app and navigate to "Find Nearby Y2Y Organizations", look for these logs:

#### Expected Logs:
```
TypesenseManager: Configured for local search
TypesenseManager: Loaded X organizations from Firestore
✓ Result: [Name] ([Type]) - [Address]
TypesenseManager: Local search for '' returned X results
```

#### Problem Indicators:
```
⚠️ TypesenseManager: Organization with ID [ID] has no name set!
   - restaurantName: nil
   - farmName: nil
   - facilityName: nil
   - userType: Restaurant
```

This means organizations in Firestore don't have their name fields populated!

---

## 🔧 Common Causes & Solutions

### Cause 1: Organizations Missing Name Fields

**Symptom:** Console shows "Organization with ID XXX has no name set!"

**Root Cause:** Organizations in Firestore have empty or nil name fields:
- `restaurantName` is nil for Restaurant type
- `farmName` is nil for Farm type
- `facilityName` is nil for Facility type

**Solution:** Update organization profiles in Firestore

#### Option A: Via Firebase Console
1. Open Firebase Console
2. Go to Firestore Database
3. Open `users` collection
4. For each organization user:
   - If `userType` = "Restaurant", add/update `restaurantName` field
   - If `userType` = "Farm", add/update `farmName` field
   - If `userType` = "Composting Facility", add/update `facilityName` field

#### Option B: Via App
Make sure users complete their profile setup:
- Restaurants must set their restaurant name
- Farms must set their farm name
- Facilities must set their facility name

---

### Cause 2: Field Names Don't Match

**Symptom:** Names show as "Unknown" but fields exist in Firestore

**Root Cause:** Field names in Firestore don't match what the code expects

**Check:** In Firestore, verify field names are:
- `restaurantName` (not `restaurant_name` or `RestaurantName`)
- `farmName` (not `farm_name` or `FarmName`)
- `facilityName` (not `facility_name` or `FacilityName`)

**Solution:** Rename fields in Firestore to match exactly (case-sensitive!)

---

### Cause 3: Empty Strings Instead of Nil

**Symptom:** Names show as empty/blank but not "Unknown"

**Root Cause:** Name fields are set to empty strings (`""`) instead of having actual names

**Solution:** Update Firestore documents to have actual names, not empty strings

---

### Cause 4: Wrong UserType

**Symptom:** Some organizations show, others don't

**Root Cause:** `userType` field doesn't match expected values

**Check:** `userType` must be exactly:
- `"Restaurant"`
- `"Farm"`  
- `"Composting Facility"`

Not:
- `"restaurant"` (lowercase)
- `"RESTAURANT"` (uppercase)
- `"Restaurants"` (plural)
- etc.

**Solution:** Fix `userType` field in Firestore to match exactly

---

## 🧪 Quick Test

### Test in Firebase Console

1. Open Firebase Console → Firestore
2. Find a user with `userType: "Restaurant"`
3. Check if `restaurantName` field exists and has a value
4. If not, add it: `restaurantName: "Test Restaurant"`
5. Run your app again
6. "Test Restaurant" should now appear in search

---

## 💡 How It Works

The code extracts names like this:

```swift
let name = profile.restaurantName ?? profile.farmName ?? profile.facilityName ?? "Unknown"
```

This means:
1. Try `restaurantName` first
2. If nil, try `farmName`
3. If nil, try `facilityName`
4. If all nil, use "Unknown"

**So a Restaurant MUST have `restaurantName` set!**

---

## 📊 Data Structure Check

### Correct Firestore Document (Restaurant):
```
users/[userId]
{
  userID: "abc123",
  username: "john_doe",
  email: "john@example.com",
  userType: "Restaurant",
  restaurantName: "John's Pizza Place",  ← MUST HAVE THIS
  restaurantType: "Italian",
  address: "123 Main St",
  latitude: 40.7128,
  longitude: -74.0060
}
```

### Correct Firestore Document (Farm):
```
users/[userId]
{
  userID: "def456",
  username: "mary_farm",
  email: "mary@example.com",
  userType: "Farm",
  farmName: "Mary's Organic Farm",  ← MUST HAVE THIS
  farmLocation: "Rural Area",
  address: "456 Farm Rd",
  latitude: 40.7128,
  longitude: -74.0060
}
```

### Correct Firestore Document (Facility):
```
users/[userId]
{
  userID: "ghi789",
  username: "green_facility",
  email: "green@example.com",
  userType: "Composting Facility",
  facilityName: "Green Compost Center",  ← MUST HAVE THIS
  address: "789 Green Ave",
  latitude: 40.7128,
  longitude: -74.0060
}
```

---

## 🔍 Debug Checklist

Run through this checklist:

- [ ] Opened Firebase Console
- [ ] Navigated to Firestore → users collection
- [ ] Found organizations (userType = "Restaurant", "Farm", or "Composting Facility")
- [ ] Verified each organization has:
  - [ ] `address` field (not empty)
  - [ ] `latitude` field (not 0)
  - [ ] `longitude` field (not 0)
  - [ ] Name field matching their type:
    - [ ] Restaurant → `restaurantName`
    - [ ] Farm → `farmName`
    - [ ] Facility → `facilityName`
- [ ] Name fields contain actual text (not empty strings)
- [ ] Ran app and checked console logs
- [ ] Looked for ⚠️ warning messages
- [ ] Organizations now appear in search results

---

## 🚀 Quick Fix Script

If you have many organizations without names, you can update them programmatically:

```swift
// Run this ONCE to fix missing names
Task {
    let db = Firestore.firestore()
    let snapshot = try await db.collection("users").getDocuments()
    
    for doc in snapshot.documents {
        let data = doc.data()
        guard let userType = data["userType"] as? String else { continue }
        
        var updates: [String: Any] = [:]
        
        switch userType {
        case "Restaurant":
            if data["restaurantName"] as? String == nil || (data["restaurantName"] as? String)?.isEmpty == true {
                updates["restaurantName"] = "\(data["username"] as? String ?? "Unknown") Restaurant"
            }
        case "Farm":
            if data["farmName"] as? String == nil || (data["farmName"] as? String)?.isEmpty == true {
                updates["farmName"] = "\(data["username"] as? String ?? "Unknown") Farm"
            }
        case "Composting Facility":
            if data["facilityName"] as? String == nil || (data["facilityName"] as? String)?.isEmpty == true {
                updates["facilityName"] = "\(data["username"] as? String ?? "Unknown") Facility"
            }
        default:
            break
        }
        
        if !updates.isEmpty {
            try await db.collection("users").document(doc.documentID).updateData(updates)
            print("✓ Updated \(doc.documentID)")
        }
    }
    
    print("✅ Done! All organizations now have names")
}
```

---

## ✅ Verification

After fixing, you should see:

### Console:
```
TypesenseManager: Loaded 5 organizations from Firestore
✓ Result: John's Pizza Place (Restaurant) - 123 Main St
✓ Result: Mary's Organic Farm (Farm) - 456 Farm Rd
✓ Result: Green Compost Center (Composting Facility) - 789 Green Ave
TypesenseManager: Local search for '' returned 5 results
```

### UI:
- Organization names displayed clearly
- Each card shows the actual name
- Map markers labeled with names
- Search filtering works

---

## 🆘 Still Not Working?

### Additional Debug Code

Add this to `loadOrganizations()` for more details:

```swift
organizations = profiles.map { profile in
    print("🔍 Processing: userID=\(profile.userID), userType=\(profile.userType)")
    print("   restaurantName: \(profile.restaurantName ?? "nil")")
    print("   farmName: \(profile.farmName ?? "nil")")
    print("   facilityName: \(profile.facilityName ?? "nil")")
    
    let name = profile.restaurantName ?? profile.farmName ?? profile.facilityName ?? "Unknown"
    print("   → Final name: \(name)")
    
    return OrganizationDocument(...)
}
```

This will show exactly what's being read from Firestore.

---

## 📝 Summary

**Most likely cause:** Organizations in Firestore don't have their name fields set.

**Quick fix:** 
1. Go to Firebase Console
2. Check each organization document
3. Add the appropriate name field
4. Reload the app

**The code is working correctly** - it's just displaying what's in Firestore!

---

## 🎯 Prevention

To prevent this in the future:

1. **Require names during signup**
   - Don't let users skip profile completion
   - Validate that name fields are not empty

2. **Add validation in update functions**
   ```swift
   guard !name.isEmpty else {
       throw ValidationError.nameRequired
   }
   ```

3. **Show warnings in UI**
   - If profile is incomplete, show "Complete your profile" banner
   - Highlight missing required fields

---

Good luck debugging! The console logs with `⚠️` symbols will tell you exactly which organizations are missing names. 🚀
