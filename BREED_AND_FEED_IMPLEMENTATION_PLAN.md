# Implementation Plan: Breed Dropdown & Feed Tracking for Journal Entries

## Overview
This document provides a comprehensive implementation plan for adding two critical features to the ShowTrackAI journal entry form:
1. **Breed Dropdown** - Mandatory field with common show breeds per species
2. **Feed Tracking** - Allow recording feed by brand/product with "Use Last" functionality

## Current State Analysis

### Existing Infrastructure
- ✅ **Database Schema**: Already has all necessary tables:
  - `feed_brands` - Feed manufacturer data
  - `feed_products` - Product catalog with species filtering
  - `journal_feed_items` - Feed items linked to journal entries
  - `user_feed_recent` - "Use Last" functionality support
  
- ✅ **Feed Service**: Complete service at `/lib/services/feed_service.dart` with methods:
  - `getBrands()` - Fetch all feed brands
  - `getProducts(brandId, species)` - Get products for brand/species
  - `saveFeedItem()` - Save feed to journal
  - `getRecentFeedItems()` - Get user's recent feeds
  
- ✅ **Feed Widget**: `FeedDataCard` widget already integrated at line 1138

### Form Structure
The journal form (`journal_entry_form_page.dart`) has this layout:
```
1. Progress Card
2. Animal Selector (lines 1085-1087) ← Add breed dropdown here
3. Title & Date
4. Category & Duration  
5. Location & Weather
6. Description
7. FFA Standards
8. AET Skills
9. Learning Objectives
10. Feed Data Card (lines 1138-1145) ← Already exists, needs enhancement
11. Weight/Feeding Panel
12. Additional Fields
```

## Feature 1: Breed Dropdown Implementation

### 1.1 Create Breed Constants File
**Location**: `/lib/constants/livestock_breeds.dart`

```dart
/// Common show livestock breeds by species
class LivestockBreeds {
  static const Map<String, List<String>> breedsBySpecies = {
    'cattle': [
      'Angus',
      'Hereford',
      'Charolais',
      'Simmental',
      'Shorthorn',
      'Maine-Anjou',
      'Limousin',
      'Red Angus',
      'Chianina',
      'Crossbred',
      'Other',
    ],
    'swine': [
      'Yorkshire',
      'Hampshire',
      'Duroc',
      'Berkshire',
      'Spotted',
      'Poland China',
      'Chester White',
      'Landrace',
      'Crossbred',
      'Other',
    ],
    'sheep': [
      'Hampshire',
      'Suffolk',
      'Dorset',
      'Southdown',
      'Shropshire',
      'Columbia',
      'Corriedale',
      'Romney',
      'Market Lamb',
      'Crossbred',
      'Other',
    ],
    'goat': [
      'Boer',
      'Spanish',
      'Kiko',
      'Nubian',
      'Alpine',
      'LaMancha',
      'Oberhasli',
      'Saanen',
      'Toggenburg',
      'Market Goat',
      'Crossbred',
      'Other',
    ],
    'poultry': [
      'Cornish Cross',
      'Rhode Island Red',
      'Leghorn',
      'Plymouth Rock',
      'Orpington',
      'Australorp',
      'Wyandotte',
      'Brahma',
      'Silkie',
      'Mixed/Crossbred',
      'Other',
    ],
    'rabbit': [
      'New Zealand',
      'Californian',
      'Rex',
      'Flemish Giant',
      'Holland Lop',
      'Mini Rex',
      'Netherland Dwarf',
      'Lionhead',
      'Mixed/Crossbred',
      'Other',
    ],
  };

  /// Get breeds for a specific species
  static List<String> getBreedsForSpecies(String species) {
    return breedsBySpecies[species.toLowerCase()] ?? ['Other'];
  }

  /// Check if a breed is valid for a species
  static bool isValidBreed(String species, String breed) {
    final breeds = getBreedsForSpecies(species);
    return breeds.contains(breed);
  }
}
```

### 1.2 Add Breed State to Form
**Location**: `journal_entry_form_page.dart`

Add after line 66 (form state variables):
```dart
  // Breed selection
  String? _selectedBreed;
```

### 1.3 Modify Animal Selector Widget
**Location**: Replace `_buildAnimalSelector()` method (lines 1208-1277)

```dart
Widget _buildAnimalSelector() {
  // Get selected animal for breed dropdown
  Animal? selectedAnimal;
  if (_selectedAnimalId != null) {
    selectedAnimal = _animals.firstWhere(
      (a) => a.id == _selectedAnimalId,
      orElse: () => _animals.first,
    );
  }

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animal Selection
          const Text(
            'Animal *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_isLoadingAnimals)
            const Center(child: CircularProgressIndicator())
          else if (_animals.isEmpty)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('No animals found. Add an animal first to create journal entries.'),
                    ),
                  ],
                ),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedAnimalId,
              decoration: const InputDecoration(
                hintText: 'Select an animal',
                prefixIcon: Icon(Icons.pets),
              ),
              items: _animals.map((animal) {
                return DropdownMenuItem(
                  value: animal.id,
                  child: Row(
                    children: [
                      Icon(
                        _getAnimalIcon(animal.species),
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text('${animal.name} (${animal.speciesDisplay})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAnimalId = value;
                  // Reset breed when animal changes
                  _selectedBreed = null;
                  // Pre-fill breed if animal has one
                  final animal = _animals.firstWhere((a) => a.id == value);
                  if (animal.breed != null && animal.breed!.isNotEmpty) {
                    _selectedBreed = animal.breed;
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an animal';
                }
                return null;
              },
            ),
          
          // Breed Selection (NEW)
          if (selectedAnimal != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Breed *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedBreed,
              decoration: InputDecoration(
                hintText: 'Select breed',
                prefixIcon: Icon(
                  Icons.category_outlined,
                  color: AppTheme.primaryGreen,
                ),
                helperText: 'Select the breed for show classification',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
              items: LivestockBreeds.getBreedsForSpecies(
                selectedAnimal.species.toString().split('.').last,
              ).map((breed) {
                return DropdownMenuItem(
                  value: breed,
                  child: Row(
                    children: [
                      if (breed == 'Crossbred')
                        const Icon(Icons.shuffle, size: 18, color: Colors.orange)
                      else if (breed == 'Other')
                        const Icon(Icons.help_outline, size: 18, color: Colors.grey)
                      else
                        Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: Colors.green.shade600,
                        ),
                      const SizedBox(width: 8),
                      Text(breed),
                      if (breed == selectedAnimal.breed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBreed = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a breed';
                }
                return null;
              },
            ),
            
            // Show breed info if crossbred or other
            if (_selectedBreed == 'Crossbred' || _selectedBreed == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Breed Details (Optional)',
                  hintText: _selectedBreed == 'Crossbred' 
                      ? 'e.g., Angus x Hereford' 
                      : 'Specify the breed',
                  prefixIcon: const Icon(Icons.edit_note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSaved: (value) {
                  // Save to metadata
                  _breedDetails = value;
                },
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
```

### 1.4 Update Submit Method
**Location**: In `_performSubmission()` method

Add breed to the journal entry data:
```dart
'breed': _selectedBreed,
'breed_details': _breedDetails, // If crossbred or other
```

## Feature 2: Enhanced Feed Tracking

### 2.1 Current FeedDataCard Analysis
The `FeedDataCard` widget is already integrated at line 1138-1145. It appears to handle:
- Feed items list display
- Adding/removing feed items
- Basic quantity tracking

### 2.2 Enhancements Needed

#### Add "Use Last" Button
**Location**: In `FeedDataCard` widget

Add a button that loads the user's most recent feed entries:
```dart
IconButton(
  icon: const Icon(Icons.history),
  tooltip: 'Use last feed entries',
  onPressed: _loadRecentFeeds,
),
```

#### Implement Recent Feeds Loading
```dart
Future<void> _loadRecentFeeds() async {
  try {
    final recentFeeds = await FeedService.getRecentFeedItems(
      userId: currentUser.id,
      limit: 5,
    );
    
    if (recentFeeds.isNotEmpty) {
      // Show selection dialog
      final selected = await showDialog<List<FeedItem>>(
        context: context,
        builder: (context) => RecentFeedsDialog(feeds: recentFeeds),
      );
      
      if (selected != null) {
        setState(() {
          _feedItems.addAll(selected);
        });
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load recent feeds: $e')),
    );
  }
}
```

### 2.3 Create Recent Feeds Dialog
**Location**: `/lib/widgets/recent_feeds_dialog.dart`

```dart
class RecentFeedsDialog extends StatefulWidget {
  final List<FeedItem> feeds;
  
  const RecentFeedsDialog({Key? key, required this.feeds}) : super(key: key);
  
  @override
  State<RecentFeedsDialog> createState() => _RecentFeedsDialogState();
}

class _RecentFeedsDialogState extends State<RecentFeedsDialog> {
  final Set<int> _selectedIndexes = {};
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          const Text('Recent Feed Entries'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.feeds.length,
          itemBuilder: (context, index) {
            final feed = widget.feeds[index];
            return CheckboxListTile(
              value: _selectedIndexes.contains(index),
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIndexes.add(index);
                  } else {
                    _selectedIndexes.remove(index);
                  }
                });
              },
              title: Text('${feed.brand?.name ?? ""} - ${feed.product?.name ?? ""}'),
              subtitle: Text('${feed.quantity} ${feed.unit}'),
              secondary: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getFeedTypeIcon(feed.product?.type)),
                  Text(
                    feed.createdAt != null 
                        ? _formatRelativeDate(feed.createdAt!)
                        : '',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: Text('Add Selected (${_selectedIndexes.length})'),
          onPressed: _selectedIndexes.isEmpty ? null : () {
            final selected = _selectedIndexes
                .map((i) => widget.feeds[i])
                .toList();
            Navigator.pop(context, selected);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
```

### 2.4 Feed Entry Enhancement
**In FeedDataCard Widget**

Add improved feed entry with brand/product selection:
```dart
Widget _buildAddFeedSection() {
  return Card(
    color: Colors.grey.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add Feed Entry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Quick Actions
              TextButton.icon(
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Use Last'),
                onPressed: _loadRecentFeeds,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Brand Selection
          DropdownButtonFormField<String>(
            value: _selectedBrandId,
            decoration: const InputDecoration(
              labelText: 'Feed Brand',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            items: _brands.map((brand) {
              return DropdownMenuItem(
                value: brand.id,
                child: Row(
                  children: [
                    if (brand.logoUrl != null)
                      Image.network(
                        brand.logoUrl!,
                        width: 24,
                        height: 24,
                        errorBuilder: (_, __, ___) => 
                            const Icon(Icons.business, size: 20),
                      )
                    else
                      const Icon(Icons.business, size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(brand.name)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (brandId) {
              setState(() {
                _selectedBrandId = brandId;
                _selectedProductId = null;
                _loadProducts(brandId!);
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Product Selection
          if (_selectedBrandId != null) ...[
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              decoration: const InputDecoration(
                labelText: 'Feed Product',
                prefixIcon: Icon(Icons.inventory),
                border: OutlineInputBorder(),
              ),
              items: _products.map((product) {
                return DropdownMenuItem(
                  value: product.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name),
                      Text(
                        '${product.type} - ${product.proteinPercentage}% protein',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (productId) {
                setState(() {
                  _selectedProductId = productId;
                });
              },
            ),
            
            const SizedBox(height: 12),
          ],
          
          // Quantity Input
          if (_selectedProductId != null) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.scale),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final qty = double.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'oz', child: Text('oz')),
                      DropdownMenuItem(value: 'scoops', child: Text('scoops')),
                      DropdownMenuItem(value: 'flakes', child: Text('flakes')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Feed Entry'),
                onPressed: _canAddFeed() ? _addFeedEntry : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

## Implementation Steps

### Phase 1: Breed Dropdown (2 hours)
1. Create `livestock_breeds.dart` constants file (15 min)
2. Add breed state variable to form (5 min)
3. Modify `_buildAnimalSelector()` widget (45 min)
4. Update submission method to include breed (15 min)
5. Test with different species (30 min)
6. Add validation and edge cases (10 min)

### Phase 2: Feed Tracking Enhancement (3 hours)
1. Review existing `FeedDataCard` implementation (20 min)
2. Add "Use Last" functionality to feed service (30 min)
3. Create `RecentFeedsDialog` widget (45 min)
4. Enhance feed entry UI with brand/product dropdowns (45 min)
5. Implement quantity tracking improvements (30 min)
6. Test feed data persistence (30 min)
7. Add error handling and validation (20 min)

### Phase 3: Integration & Testing (1 hour)
1. Ensure breed saves with journal entry (15 min)
2. Verify feed items link to entries correctly (15 min)
3. Test "Use Last" with various scenarios (15 min)
4. Validate form submission with all new fields (15 min)

## Database Considerations

### Breed Storage
The breed will be stored in the journal entry's metadata or as a dedicated field. Consider adding:
```sql
ALTER TABLE journal_entries ADD COLUMN breed VARCHAR(100);
ALTER TABLE journal_entries ADD COLUMN breed_details TEXT;
```

### Feed Tracking
The existing schema supports all requirements:
- `journal_feed_items` links feeds to entries
- `user_feed_recent` enables "Use Last" feature
- No schema changes needed

## UI/UX Considerations

### Breed Selection
- **Auto-populate**: If animal profile has breed, pre-select it
- **Visual indicators**: Show "Profile" badge for pre-filled breeds
- **Flexibility**: Allow "Other" with text field for rare breeds
- **Validation**: Make breed required for journal submission

### Feed Tracking
- **Quick entry**: "Use Last" button for efficiency
- **Smart filtering**: Only show products for selected animal's species
- **Visual feedback**: Show feed costs and protein levels
- **Batch operations**: Select multiple recent feeds at once

## Error Handling

### Breed Selection
- Handle missing breed lists gracefully
- Default to "Other" if species not recognized
- Validate breed matches species

### Feed Tracking
- Handle API failures with offline fallback
- Cache recent feeds locally
- Validate quantities are positive numbers
- Show clear error messages for failed operations

## Performance Optimizations

### Breed Data
- Load breed lists once on form initialization
- Cache in memory for session
- Use const lists for better performance

### Feed Data
- Lazy load products only when brand selected
- Debounce API calls for search
- Cache recent feeds for 5 minutes
- Batch save feed items on form submission

## Success Metrics

### Breed Feature
- ✅ All journal entries have breed specified
- ✅ 90% use standard breeds (not "Other")
- ✅ Form validation prevents submission without breed

### Feed Feature
- ✅ 50% of entries use "Use Last" feature
- ✅ Average 3-5 feed items per entry
- ✅ <2 seconds to add feed entry
- ✅ Zero data loss on feed items

## Next Steps

1. **Immediate**: Implement Phase 1 (Breed Dropdown)
2. **Next Sprint**: Implement Phase 2 (Feed Enhancement)
3. **Future**: Add feed cost calculations and analytics
4. **Long-term**: Integrate with feed company APIs for pricing

## Notes

- The FeedDataCard is already handling basic feed functionality
- Focus on enhancing UX with "Use Last" and better dropdowns
- Ensure mobile-responsive design for all new elements
- Consider adding feed recommendations based on animal weight/age