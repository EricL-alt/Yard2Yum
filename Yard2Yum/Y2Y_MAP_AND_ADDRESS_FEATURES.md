# Y2Y Map and Address Features

## Overview
This document describes the new address and map features added to the Yard2Yum application.

## Features Implemented

### 1. Required Address Field
All organizations (Restaurants, Farms, and Composting Facilities) are now **required** to enter their physical street address during sign-up or profile completion.

#### Implementation Details:
- Added `address`, `latitude`, and `longitude` fields to `UserProfile` struct in Firestore
- Address is automatically geocoded using Apple's `CLGeocoder` to obtain coordinates
- Validation ensures address cannot be empty before proceeding
- Error handling displays user-friendly messages if geocoding fails

#### User Experience:
- **Restaurant Page 1**: Added "Street Address" field with placeholder "e.g. 123 Main St, Springfield, CA 12345"
- **Farm Page 1**: Added "Street Address" field with placeholder "e.g. 789 County Rd, Springfield, CA 12345"
- **Facility Page 1**: Added "Street Address" field with placeholder "e.g. 456 Industrial Dr, Springfield, CA 12345"
- Geocoding error messages appear in a styled card if address cannot be found

### 2. Interactive Map View
A new map view accessible from all user types shows nearby Yard2Yum organizations with pins.

#### Features:
- **Custom Map Pins**: Each organization type has a unique colored pin:
  - 🍴 Restaurants: Orange accent
  - 🌿 Farms: Green accent
  - ♻️ Composting Facilities: Tan/brown accent
- **User Location**: Blue pin shows "You are here"
- **Organization Details**: Tap any pin to see:
  - Organization name
  - Organization type
  - Street address
  - "Visit Now in Maps" button

#### Accessing the Map:
Users can access the map from the following pages:
- **Restaurants**: RestaurantPage2 (Schedule Pickup page) via "🗺️ View Nearby Y2Y Organizations" button
- **Farms**: FarmPage2 (Compost Marketplace page) via "🗺️ View Nearby Y2Y Organizations" button
- **Facilities**: FacilityPage2 (Dashboard page) via "🗺️ View Nearby Y2Y Organizations" button

### 3. "Visit Now" Apple Maps Integration
When viewing an organization's details on the map, users can tap the "Visit Now in Maps" button to:
- Open Apple Maps with the organization's address
- Get turn-by-turn directions
- View estimated travel time
- Choose transportation mode (driving, walking, transit, etc.)

#### Implementation:
- Uses `MKMapItem` and `openInMaps()` for seamless integration
- Launches with driving directions by default
- Geocodes the address to ensure accuracy

## Technical Details

### Files Modified:
1. **FirestoreManager.swift**
   - Updated `UserProfile` struct with address fields
   - Modified `createUserProfile()` to save address data
   - Modified `getUserProfile()` to load address data
   - Updated `updateRestaurantInfo()`, `updateFarmInfo()`, and `updateFacilityInfo()` with address parameters
   - Added `getAllOrganizations()` method to fetch all organizations with addresses for map display

2. **ContentView.swift**
   - Added `address`, `latitude`, `longitude` to `AppState`
   - Imported `MapKit` and `CoreLocation`
   - Updated sign-in logic to load address from Firestore
   - Modified onboarding flow to require address completion
   - Added `Y2YMapView` component with map display
   - Added `MapPinView` for custom map markers
   - Added `OrganizationDetailCard` for showing organization info
   - Updated `RestaurantPage1`, `FarmPage1`, `FacilityPage1` with address fields and geocoding
   - Added map navigation buttons to `RestaurantPage2`, `FarmPage2`, `FacilityPage2`

### New SwiftUI Components:

#### Y2YMapView
Main map view that displays all Y2Y organizations.
- Loads organizations from Firestore
- Displays custom annotations for each type
- Centers on user's location initially
- Animates to selected organization

#### MapPinView
Custom map pin with organization type icon and color.

#### OrganizationDetailCard
Bottom card showing organization details when pin is tapped.
- Organization name and type
- Address
- "Visit Now in Maps" button with Apple Maps integration

### Firestore Schema Updates:
```
users/{userID}
├── userID: String
├── username: String
├── email: String
├── userType: String
├── address: String (NEW - required)
├── latitude: Double (NEW)
├── longitude: Double (NEW)
├── restaurantName: String (optional)
├── restaurantType: String (optional)
├── farmName: String (optional)
├── farmLocation: String (optional)
├── facilityName: String (optional)
├── totalDonatedLbs: Double
├── totalPoints: Int
├── createdAt: Timestamp
└── updatedAt: Timestamp
```

## User Flow

### New User Sign-Up:
1. Create account with username, email, password
2. Select user type (Restaurant, Farm, or Facility)
3. Complete profile with **required address field**
4. Address is geocoded and coordinates are saved
5. User can now access map to see other organizations

### Existing User Sign-In:
1. Sign in with email and password
2. If address is missing, user is prompted to complete profile
3. Once address is added, full access is granted

### Using the Map:
1. Navigate to any main page (Restaurant Schedule, Farm Marketplace, or Facility Dashboard)
2. Tap "🗺️ View Nearby Y2Y Organizations"
3. Map opens showing all organizations
4. Tap any pin to see details
5. Tap "Visit Now in Maps" to get directions

## Privacy & Security
- Addresses are stored securely in Firestore
- Only organization addresses are shared on the map
- No personal user information is exposed
- Geocoding happens on-device using Apple's CoreLocation

## Future Enhancements
Potential improvements for future versions:
- Filter map by organization type
- Search for organizations by name or location
- Distance calculation and sorting
- Favorite organizations
- Check-in or review system
- Real-time location updates for deliveries
