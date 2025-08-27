# Animal Edit Functionality - Testing & Verification Guide

## 🧪 Comprehensive Test Plan

### Pre-Test Setup
1. **Ensure Development Environment Ready**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
2. **Create Test Animals** (if not already existing)
3. **Verify User Authentication** (logged in state)
4. **Check COPPA Compliance Status** (ensure access to animal management)

## 📋 Test Cases

### 1. Navigation Tests

#### 1.1 From Animal List Screen
**Test Steps:**
1. Open Animals tab from main navigation
2. Locate any animal card in the list
3. Tap the three-dot menu (⋮) on animal card
4. Select "Edit" from popup menu

**Expected Results:**
- ✅ Popup menu appears with Edit and Delete options
- ✅ Edit option is enabled (not grayed out)
- ✅ Tapping Edit navigates to AnimalEditScreen
- ✅ Screen title shows "Edit [Animal Name]"

#### 1.2 From Animal Detail Screen  
**Test Steps:**
1. Open Animals tab from main navigation
2. Tap on any animal card to open detail view
3. Look for Edit icon (pencil) in app bar
4. Tap the Edit icon

**Expected Results:**
- ✅ Edit icon is visible in app bar
- ✅ Edit icon is enabled and tappable
- ✅ Tapping Edit navigates to AnimalEditScreen
- ✅ Screen title shows "Edit [Animal Name]"

### 2. Form Loading Tests

#### 2.1 Data Pre-Population
**Test Steps:**
1. Navigate to edit an existing animal with complete data
2. Verify all fields are pre-populated correctly

**Expected Results:**
- ✅ Name field shows existing animal name
- ✅ Tag field shows existing tag (or empty if none)
- ✅ Species dropdown shows correct species
- ✅ Breed field shows existing breed (or empty if none)  
- ✅ Gender dropdown shows correct gender (or "Not specified")
- ✅ Birth date shows correct date (or "Select Birth Date")
- ✅ Purchase date shows correct date (or "Select Purchase Date")
- ✅ Purchase weight shows correct value (or empty)
- ✅ Current weight shows correct value (or empty)
- ✅ Purchase price shows correct value (or empty)
- ✅ Description shows existing notes (or empty)

#### 2.2 Change Detection
**Test Steps:**
1. Open edit screen for any animal
2. Make a small change to name field
3. Observe UI changes

**Expected Results:**
- ✅ "Modified" badge appears in app bar
- ✅ Orange edit icon (📝) appears next to changed field
- ✅ Save button changes from "No Changes" to "Save Changes"
- ✅ Save button becomes enabled (blue color)

### 3. Form Validation Tests

#### 3.1 Required Field Validation
**Test Steps:**
1. Clear the animal name field completely
2. Try to save the form

**Expected Results:**
- ✅ Form validation prevents saving
- ✅ Error message appears: "Name is required"
- ✅ Name field shows error state (red border)

#### 3.2 Name Field Validation
**Test Animal Names:**
- ✅ "A" → Error: "Name must be at least 2 characters"
- ✅ "AB" → Valid
- ✅ "Very Long Animal Name That Exceeds Fifty Characters Limit" → Error: "Name must be less than 50 characters"
- ✅ "Test@123" → Error: "Name contains invalid characters"
- ✅ "Test Animal-2" → Valid
- ✅ "O'Malley" → Valid

#### 3.3 Tag Field Validation
**Test Tags:**
- ✅ "" (empty) → Valid
- ✅ "123" → Valid  
- ✅ "ABC-123" → Valid
- ✅ "This-Is-A-Very-Long-Tag-Name" → Error: "Tag must be less than 20 characters"
- ✅ "test@123" → Error: "Tag can only contain letters, numbers, and hyphens"

#### 3.4 Weight Field Validation
**Test Weights:**
- ✅ "" (empty) → Valid
- ✅ "100" → Valid
- ✅ "100.5" → Valid  
- ✅ "-50" → Error: "Weight must be greater than 0"
- ✅ "0" → Error: "Weight must be greater than 0"
- ✅ "6000" → Error: "Weight seems too high. Please verify."
- ✅ "abc" → Error: "Please enter a valid number"

#### 3.5 Price Field Validation  
**Test Prices:**
- ✅ "" (empty) → Valid
- ✅ "500" → Valid
- ✅ "500.99" → Valid
- ✅ "-100" → Error: "Price cannot be negative"
- ✅ "150000" → Error: "Price seems too high. Please verify."

### 4. Tag Uniqueness Tests

#### 4.1 Duplicate Tag Detection
**Test Steps:**
1. Edit an animal and change tag to one that's already used
2. Wait for async validation (spinner appears)
3. Observe validation result

**Expected Results:**
- ✅ Spinner appears in tag field suffix
- ✅ After validation: Error icon (❌) appears
- ✅ Error message: "This tag is already in use"  
- ✅ Form cannot be saved with duplicate tag

#### 4.2 Current Animal Tag Exception
**Test Steps:**
1. Edit an animal with existing tag
2. Don't change the tag field
3. Observe validation

**Expected Results:**
- ✅ No error for existing tag (animal can keep its own tag)
- ✅ Green checkmark if tag is valid and available
- ✅ No validation spinner for unchanged tag

### 5. Species and Gender Logic Tests

#### 5.1 Species Change Updates Gender Options
**Test Steps:**
1. Select "Cattle" species
2. Set gender to "Heifer"  
3. Change species to "Sheep"
4. Check gender dropdown options

**Expected Results:**
- ✅ Gender options update to: Ewe, Ram, Wether
- ✅ Previous selection "Heifer" resets to "Not specified"
- ✅ Change tracking detects species and gender changes

#### 5.2 Species-Specific Gender Options
**Verify Correct Options:**
- ✅ **Cattle:** Heifer, Steer, Male, Female
- ✅ **Swine:** Gilt, Barrow, Male, Female  
- ✅ **Sheep:** Ewe, Ram, Wether
- ✅ **Goat:** Doe, Buck, Wether
- ✅ **Other Species:** Male, Female

### 6. Date Picker Tests

#### 6.1 Birth Date Selection
**Test Steps:**
1. Tap "Select Birth Date" tile
2. Choose a date from picker
3. Clear the date using clear button

**Expected Results:**
- ✅ Date picker opens with reasonable default
- ✅ Selected date displays correctly
- ✅ Age calculation appears and is accurate
- ✅ Clear button removes date
- ✅ Change tracking detects date changes

#### 6.2 Purchase Date Selection
**Test Steps:**
1. Tap "Select Purchase Date" tile  
2. Choose a date from picker
3. Clear the date using clear button

**Expected Results:**
- ✅ Date picker opens with reasonable default
- ✅ Selected date displays correctly
- ✅ Clear button removes date
- ✅ Change tracking detects date changes

### 7. Save Functionality Tests

#### 7.1 Successful Save
**Test Steps:**
1. Make valid changes to an animal
2. Tap "Save Changes" button
3. Observe results

**Expected Results:**
- ✅ Loading indicator appears on save button
- ✅ Success message appears: "[Animal Name] has been updated!"
- ✅ Navigation back to previous screen
- ✅ Updated data visible in animal list/detail
- ✅ Database updated correctly

#### 7.2 Save Without Changes
**Test Steps:**
1. Open edit screen without making changes
2. Try to tap save button

**Expected Results:**
- ✅ Save button shows "No Changes" and is disabled/grayed
- ✅ Tapping does nothing or navigates back without API call

#### 7.3 Authentication Check
**Test Steps:**
1. Simulate logged out state (if possible)
2. Try to save changes

**Expected Results:**
- ✅ Error message: "You must be logged in to update an animal"
- ✅ No API request sent
- ✅ Form remains open for re-authentication

### 8. Unsaved Changes Warning Tests

#### 8.1 Back Navigation Warning
**Test Steps:**
1. Make changes to any field
2. Tap system back button or app bar back arrow
3. Test both dialog options

**Expected Results:**
- ✅ Warning dialog appears: "Discard Changes?"
- ✅ Dialog shows: "You have unsaved changes. Are you sure you want to discard them?"
- ✅ "Keep Editing" → Returns to form
- ✅ "Discard" → Navigates back without saving

#### 8.2 No Warning When No Changes
**Test Steps:**
1. Open edit screen without making changes
2. Tap back button

**Expected Results:**
- ✅ No warning dialog appears
- ✅ Immediate navigation back to previous screen

### 9. Error Handling Tests

#### 9.1 Network Error Handling
**Test Steps:**
1. Simulate network error during save
2. Observe error handling

**Expected Results:**
- ✅ Error message displayed in snackbar
- ✅ Form remains open
- ✅ Loading state clears
- ✅ User can retry

#### 9.2 Server Error Handling
**Test Steps:**
1. Simulate server error (500) during save
2. Observe error handling

**Expected Results:**
- ✅ Meaningful error message displayed
- ✅ Form remains open for retry
- ✅ Loading state clears properly

### 10. COPPA Compliance Tests

#### 10.1 Minor User Restrictions
**Test Steps:**
1. Test with user under 13 without parental consent
2. Try to access edit functionality

**Expected Results:**
- ✅ Edit options are hidden or disabled
- ✅ Appropriate restriction message shown
- ✅ COPPA compliance respected

#### 10.2 Consented Minor Access
**Test Steps:**
1. Test with user under 13 WITH parental consent
2. Access edit functionality

**Expected Results:**
- ✅ Full edit functionality available
- ✅ All features work normally

### 11. UI/UX Polish Tests

#### 11.1 Visual Feedback
**Verify These Elements:**
- ✅ "Modified" badge appears when changes exist
- ✅ Orange edit icons (📝) next to changed fields
- ✅ Loading spinners during async operations
- ✅ Success/error color coding
- ✅ Proper field focus management

#### 11.2 Responsive Design
**Test Screen Sizes:**
- ✅ Phone portrait orientation
- ✅ Phone landscape orientation  
- ✅ Tablet portrait orientation
- ✅ Tablet landscape orientation

#### 11.3 Keyboard Navigation
**Test Steps:**
1. Use Tab key to navigate between fields
2. Use keyboard to interact with dropdowns
3. Test keyboard submission

**Expected Results:**
- ✅ Logical tab order through form fields
- ✅ Dropdowns accessible via keyboard
- ✅ Form submittable via keyboard

## 🚨 Critical Issues to Watch For

### High Priority Issues
1. **Data Loss:** Changes not saved to database
2. **Navigation Failure:** Edit screen doesn't load
3. **Validation Bypass:** Invalid data gets saved
4. **Tag Conflicts:** Duplicate tags allowed
5. **COPPA Violations:** Restricted users gain access

### Medium Priority Issues  
1. **Poor Error Messages:** Unclear validation feedback
2. **Missing Change Detection:** UI doesn't show modifications
3. **Performance:** Slow tag validation or save operations
4. **Date Handling:** Incorrect date calculations or display

### Low Priority Issues
1. **Visual Glitches:** Minor UI inconsistencies
2. **Accessibility:** Missing screen reader support
3. **Animation:** Choppy transitions

## 🔧 Common Issues & Solutions

### Issue: "Edit option missing from popup menu"
**Possible Causes:**
- COPPA restrictions for minor users
- Authentication issues
- Missing import of AnimalEditScreen

**Debug Steps:**
```dart
// Add debug print in popup menu builder
print('Can access animal management: $_canAccessAnimalManagement');
print('COPPA status: $_coppaStatus');
```

### Issue: "Tag validation not working"
**Possible Causes:**
- Network connectivity issues
- Incorrect debouncing logic
- API endpoint problems

**Debug Steps:**
```dart
// Add debug prints in _validateTag method
print('Validating tag: $value');
print('Exclude animal ID: ${widget.animal.id}');
```

### Issue: "Changes not detected"
**Possible Causes:**
- Controller listeners not set up correctly
- Comparison logic errors
- Missing change tracking calls

**Debug Steps:**
```dart
// Add debug print in _checkForChanges
print('Has changes: $hasChanges');
print('Name changed: ${_nameController.text != _originalAnimal.name}');
```

### Issue: "Form not pre-populating"
**Possible Causes:**
- Animal data not passed correctly
- Controller initialization issues
- Date/time formatting problems

**Debug Steps:**
```dart
// Add debug prints in initState
print('Original animal: ${widget.animal.toJson()}');
print('Controllers initialized with data');
```

## ✅ Success Criteria

**Testing is successful when:**
- ✅ All navigation paths work correctly
- ✅ Form pre-populates with existing data
- ✅ All validation rules work properly  
- ✅ Tag uniqueness is enforced
- ✅ Changes save to database correctly
- ✅ UI provides clear feedback
- ✅ COPPA compliance is maintained
- ✅ Error handling works gracefully
- ✅ Performance is acceptable (<3 seconds for saves)

## 📊 Test Results Template

```
## Test Execution Results

**Date:** [Current Date]  
**Tester:** [Your Name]
**Environment:** Flutter [Version] on [Device/Platform]

### Navigation Tests
- [ ] List screen edit navigation: PASS/FAIL
- [ ] Detail screen edit navigation: PASS/FAIL

### Form Loading Tests  
- [ ] Data pre-population: PASS/FAIL
- [ ] Change detection: PASS/FAIL

### Validation Tests
- [ ] Required fields: PASS/FAIL
- [ ] Name validation: PASS/FAIL  
- [ ] Tag validation: PASS/FAIL
- [ ] Weight validation: PASS/FAIL
- [ ] Price validation: PASS/FAIL

### Tag Uniqueness Tests
- [ ] Duplicate detection: PASS/FAIL
- [ ] Current animal exception: PASS/FAIL

### Species/Gender Tests
- [ ] Options update correctly: PASS/FAIL
- [ ] All species have correct genders: PASS/FAIL

### Date Picker Tests
- [ ] Birth date selection: PASS/FAIL
- [ ] Purchase date selection: PASS/FAIL

### Save Tests
- [ ] Successful save: PASS/FAIL
- [ ] No changes handling: PASS/FAIL
- [ ] Authentication check: PASS/FAIL

### Warning Tests
- [ ] Unsaved changes warning: PASS/FAIL
- [ ] No warning when no changes: PASS/FAIL

### Error Handling Tests
- [ ] Network errors: PASS/FAIL
- [ ] Server errors: PASS/FAIL

### COPPA Tests
- [ ] Minor restrictions: PASS/FAIL
- [ ] Consented access: PASS/FAIL

### UI/UX Tests
- [ ] Visual feedback: PASS/FAIL
- [ ] Responsive design: PASS/FAIL
- [ ] Keyboard navigation: PASS/FAIL

**Overall Result:** PASS/FAIL  
**Critical Issues Found:** [List any critical issues]
**Notes:** [Any additional observations]
```

## 🎯 Next Steps After Testing

1. **Fix Critical Issues** - Address any blocking problems
2. **Optimize Performance** - Improve slow operations  
3. **Enhanced Error Messages** - Make validation clearer
4. **Accessibility Audit** - Add screen reader support
5. **User Acceptance Testing** - Get feedback from actual users
6. **Documentation Update** - Document any discovered behaviors

---

This comprehensive test plan ensures the animal edit functionality is robust, user-friendly, and compliant with all requirements. Execute these tests systematically to verify the implementation works correctly end-to-end.