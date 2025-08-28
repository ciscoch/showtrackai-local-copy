# Timeline Feature Implementation (APP-125)

## Overview
The Timeline feature provides a unified chronological view combining journal entries and financial expenses, giving students a comprehensive overview of their agricultural project progress and costs.

## Features Implemented

### 1. **Unified Timeline View**
- Combined display of journal entries and expenses in chronological order
- Date-grouped organization for better readability
- Visual indicators for different item types

### 2. **Three View Modes**
- **Timeline**: Chronological list of all activities
- **Calendar**: (Placeholder for future calendar view)
- **Analytics**: Financial and activity statistics

### 3. **Advanced Filtering**
- Filter by item type (Journal/Expense)
- Filter by animal
- Filter by date range (Today, This Week, This Month, Last 30 Days, Custom)
- Filter by category
- Search functionality across titles, descriptions, and tags

### 4. **Visual Design**
- Color-coded categories for easy identification
- Icon indicators for location, weather, AI insights
- Amount display for financial items
- Quality scores for journal entries
- Payment status indicators for unpaid expenses

### 5. **Analytics Dashboard**
- Total expenses summary
- Journal entry count
- Transaction statistics
- Average expense calculations
- Category breakdown with visual charts

## File Structure

### Models
- `/lib/models/expense.dart` - Expense data model
- `/lib/models/timeline_item.dart` - Unified timeline item model

### Services
- `/lib/services/expense_service.dart` - Expense CRUD operations and statistics

### Screens
- `/lib/screens/timeline_view_screen.dart` - Main timeline screen with tabs

### Widgets
- `/lib/widgets/timeline_item_card.dart` - Individual timeline item display
- `/lib/widgets/timeline_filters.dart` - Filter bottom sheet
- `/lib/widgets/timeline_stats_card.dart` - Statistics summary card

### Database
- `/supabase/migrations/20250128_add_expenses_table.sql` - Expense table schema

## Database Schema

### Expenses Table
```sql
expenses
├── id (UUID, Primary Key)
├── user_id (UUID, Foreign Key)
├── title (VARCHAR)
├── description (TEXT)
├── amount (DECIMAL)
├── date (TIMESTAMP)
├── category (VARCHAR)
├── animal_id (UUID, Foreign Key, Optional)
├── vendor_name (VARCHAR, Optional)
├── payment_method (VARCHAR)
├── is_paid (BOOLEAN)
├── tags (TEXT[])
└── ... (additional fields)
```

## Usage

### Accessing Timeline
1. From Dashboard: Tap the "Timeline" card
2. Direct navigation: Route to `/timeline`

### Adding Items
- Journal Entry: Use existing journal form or FAB
- Expense: (To be implemented) Click + button and select "Add Expense"

### Filtering
1. Tap filter icon in app bar
2. Select desired filters
3. Apply to see filtered results

### Analytics
1. Switch to Analytics tab
2. View expense summaries
3. See category breakdowns

## Integration Points

### With Journal System
- Journal entries automatically appear in timeline
- Financial values from journals can be linked to expenses
- Shared animal associations

### With Animal Management
- Both journals and expenses can be linked to specific animals
- Animal names displayed in timeline items
- Filter by animal for focused view

## Performance Considerations

### Pagination
- Loads 20 items at a time
- Infinite scroll with automatic loading
- Separate queries for journals and expenses run in parallel

### Caching
- Animal names cached for quick display
- Statistics calculated server-side when possible

## Security

### Row Level Security
- Users can only view their own expenses
- Enforced at database level
- Same security model as journal entries

## Future Enhancements

### Planned Features
1. **Calendar View**: Visual calendar with events
2. **Expense Form**: Add/edit expense functionality  
3. **Receipt Upload**: Attach receipts to expenses
4. **Recurring Expenses**: Automatic expense generation
5. **Budget Tracking**: Compare actual vs budgeted amounts
6. **Export**: CSV/PDF export functionality
7. **Bulk Operations**: Select and manage multiple items

### Technical Improvements
1. Add offline support for expenses
2. Implement real-time updates
3. Add data visualization charts
4. Optimize queries with materialized views
5. Add expense categories customization

## Testing

### Manual Testing Checklist
- [ ] Timeline loads with mixed content
- [ ] Filtering works correctly
- [ ] Search returns relevant results
- [ ] Pagination loads more items
- [ ] Statistics calculate correctly
- [ ] Navigation to detail views works
- [ ] Empty state displays properly
- [ ] Error states handle gracefully

### Key Test Scenarios
1. User with no data sees empty state
2. User with only journals sees journal-only timeline
3. User with mixed data sees combined timeline
4. Date filtering returns correct range
5. Animal filtering shows only related items

## API Endpoints Used

### Supabase Tables
- `journal_entries` - Existing journal data
- `expenses` - New expense tracking
- `animals` - For name associations

### RPC Functions
- `get_expense_summary` - Calculate expense statistics

## Dependencies Added
- `intl: ^0.19.0` - Date formatting

## Migration Instructions

1. Run database migration:
```bash
supabase db push
```

2. Update Flutter dependencies:
```bash
flutter pub get
```

3. Navigate to `/timeline` to test

## Notes for Developers

### Adding New Timeline Item Types
1. Add new type to `TimelineItemType` enum
2. Create factory method in `TimelineItem`
3. Update filtering logic in `TimelineFilters`
4. Add icon/color mapping in `TimelineItemCard`

### Customizing Timeline Display
- Modify `TimelineItemCard` for item appearance
- Update `_formatDateHeader` for date grouping
- Adjust `_pageSize` for pagination

### Performance Tips
- Keep parallel queries when loading multiple data types
- Use indexes on commonly filtered columns
- Consider implementing virtual scrolling for large datasets