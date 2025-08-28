# CSV Export Feature Documentation

## Overview

The CSV export functionality allows users to export their agricultural journal entries to CSV format for further analysis, reporting, and record-keeping. The feature supports comprehensive filtering options and customizable data fields to meet various agricultural education and FFA documentation requirements.

## Features

### 1. Comprehensive Data Export
Export all journal entry fields including:
- **Basic Information**: ID, date, title, category, duration, description
- **Animal Data**: Animal name, ID, species, breed information
- **Agricultural Education**: AET skills, learning objectives, outcomes, challenges, improvements
- **FFA Standards**: FFA standards, degree types, SAE types, evidence types
- **Financial Data**: Financial values, costs, feed expenses
- **Feed Management**: Feed brand, type, amount, cost, conversion ratios, weights
- **Weather Data**: Temperature, conditions, humidity, wind speed
- **Location Data**: GPS coordinates, address, city, state
- **Competency Tracking**: Demonstrated skills, completed standards, progress percentages
- **AI Analysis**: Quality scores, assessments, strengths, improvements, recommendations
- **Metadata**: Tags, notes, source, sync status, timestamps

### 2. Flexible Filtering Options
- **Date Range**: Export entries within a specific date range
- **Animal Filter**: Export entries for specific animals
- **Category Filter**: Export entries by category (health check, feeding, training, etc.)
- **Combined Filters**: Apply multiple filters simultaneously

### 3. Export Types

#### Full Export
Complete journal entries with all available data fields. Users can customize which field categories to include:
- AI Insights & Analysis
- Weather Data
- Location Data
- Feed & Nutrition Data
- Financial Data
- Competency Tracking

#### Summary Report
Statistical summary including:
- Total entries count
- Total hours logged
- Unique animals tracked
- Average quality scores
- FFA degree qualifying entries
- Total financial value
- Category breakdowns with hours per category

### 4. File Management
- **Custom Naming**: Specify custom file names or use auto-generated timestamps
- **Automatic Download**: Files download directly to the browser's download folder
- **CSV Format**: Standard CSV format compatible with Excel, Google Sheets, and other spreadsheet applications

## Implementation

### Core Components

#### 1. CSV Export Service (`/lib/services/csv_export_service.dart`)
Main service handling CSV generation and export logic:
- `exportJournalEntries()`: Export filtered journal entries
- `exportSummaryReport()`: Generate summary statistics
- `filterEntries()`: Apply filters to entry list
- CSV formatting with proper escaping for special characters

#### 2. Export Dialog Widget (`/lib/widgets/export_dialog.dart`)
User interface for configuring exports:
- Export type selection (full entries vs summary)
- Filter configuration
- Data field selection checkboxes
- File naming input
- Real-time filtered entry count

#### 3. Journal List Integration (`/lib/screens/journal_list_page.dart`)
Integration with main journal list:
- Export button in app bar
- Pre-populated filters from current view
- Access to all loaded entries and animals

### Technical Details

#### CSV Generation Process
1. **Data Collection**: Gather journal entries from local state
2. **Filtering**: Apply user-selected filters
3. **Animal Mapping**: Match animal IDs to names
4. **Header Generation**: Build dynamic headers based on selected fields
5. **Data Formatting**: Format each entry row with proper escaping
6. **File Creation**: Generate CSV string with UTF-8 encoding
7. **Download Trigger**: Use HTML5 blob and anchor element for browser download

#### Field Formatting
- **Dates**: ISO 8601 format (yyyy-MM-dd)
- **Date/Times**: Full format (yyyy-MM-dd HH:mm:ss)
- **Numbers**: Decimal formatting with appropriate precision
- **Lists**: Semi-colon separated values
- **Booleans**: "Yes"/"No" representation
- **Special Characters**: Proper CSV escaping with quotes

#### Browser Compatibility
- Uses `universal_html` package for web platform compatibility
- Creates downloadable blob URL
- Automatic cleanup of blob URLs after download
- Works with all modern browsers (Chrome, Firefox, Safari, Edge)

## Usage Guide

### Basic Export
1. Navigate to Journal List page
2. Click the export icon (⬇) in the app bar
3. Select export type and configure options
4. Click "Export" button

### Filtered Export
1. Apply filters in the journal list (search, category, animal, date range)
2. Click export icon - filters are pre-populated
3. Adjust additional options as needed
4. Export filtered entries

### Custom Field Selection
1. Choose "Full Journal Entries" export type
2. Check/uncheck data field categories:
   - AI Insights (quality scores, feedback, recommendations)
   - Weather Data (temperature, conditions)
   - Location Data (GPS, address)
   - Feed Data (nutrition information)
   - Financial Data (costs, values)
   - Competency Data (skills, standards)
3. Export with selected fields only

### Summary Report
1. Select "Summary Report" export type
2. Optionally set date range filter
3. Export statistical summary

## Data Privacy & Security

- **Local Processing**: All CSV generation happens client-side
- **No Server Upload**: Data never leaves the user's device during export
- **User Control**: Users choose exactly what data to include
- **Filtered Access**: Only exports entries the user has access to

## Use Cases

### 1. FFA Documentation
Export journal entries for FFA degree applications:
- Filter by "counts for degree" flag
- Include FFA standards and competencies
- Export evidence types and hours logged

### 2. Financial Records
Track agricultural project finances:
- Include financial and feed data
- Filter by date range for specific periods
- Calculate total investments and costs

### 3. Animal Health Records
Maintain comprehensive health documentation:
- Filter by specific animal
- Include veterinary category entries
- Export with AI health assessments

### 4. Educational Portfolio
Create learning portfolios:
- Export with learning objectives and outcomes
- Include AI feedback and recommendations
- Track competency progression

### 5. Weather Impact Analysis
Analyze weather effects on activities:
- Export with weather data
- Correlate with performance metrics
- Track seasonal patterns

## File Format Examples

### Full Export Headers
```csv
Entry ID,Date,Title,Category,Duration (minutes),Description,Animal Name,Animal ID,AET Skills,Learning Objectives,Learning Outcomes,Challenges Faced,Improvements Planned,FFA Standards,Educational Concepts,Competency Level,FFA Degree Type,Counts for Degree,SAE Type,Hours Logged,Evidence Type,Financial Value,Feed Brand,Feed Type,Feed Amount,Feed Cost,Feed Conversion Ratio,Current Weight,Target Weight,Weigh-In Date,Temperature (°F),Weather Condition,Humidity (%),Wind Speed (mph),Weather Description,Location Name,Address,City,State,Latitude,Longitude,Demonstrated Skills,Completed Standards,Progress Percentage,Last Assessment,Quality Score,AI Assessment Score,AI Assessment Justification,AI Strengths,AI Improvements,AI Suggestions,Recommended Activities,Tags,Notes,Source,Supervisor ID,Is Public,Is Synced,Created At,Updated At
```

### Summary Report Format
```csv
ShowTrackAI Journal Summary Report
Generated on: 2024-01-27 14:30:00
Date Range: 2024-01-01 to 2024-01-27

Summary Statistics
Metric,Value
Total Entries,47
Total Hours,62.5
Unique Animals,3
Entries with AI Analysis,42
Average Quality Score,7.8
FFA Degree Qualifying Entries,45
Total Financial Value,$3,250.00

Category Breakdown
Category,Count,Total Hours
Daily Care,15,18.5
Health Check,12,9.0
Feeding & Nutrition,10,12.5
Training & Handling,6,15.0
Veterinary Care,4,7.5
```

## Troubleshooting

### Export Button Not Working
- Ensure journal entries are loaded
- Check browser popup blocker settings
- Verify universal_html package is installed

### Missing Data in Export
- Confirm data exists in journal entries
- Check field selection checkboxes
- Verify filter settings aren't too restrictive

### File Not Downloading
- Check browser download settings
- Ensure sufficient disk space
- Try different browser if issue persists

### Special Characters Display Issues
- Open CSV in UTF-8 compatible application
- Use Excel's import wizard with UTF-8 encoding
- Google Sheets handles UTF-8 automatically

## Future Enhancements

- **Scheduled Exports**: Automatic periodic exports
- **Cloud Storage Integration**: Direct export to Google Drive/Dropbox
- **Custom Templates**: User-defined export templates
- **Batch Operations**: Export multiple date ranges separately
- **Data Visualization**: Generate charts from exported data
- **Email Integration**: Send exports via email
- **Compression**: ZIP compression for large exports
- **Print-Friendly Format**: PDF export option

## Dependencies

- `intl: ^0.19.0` - Date formatting
- `universal_html: ^2.2.4` - Web download functionality

## Testing

Run the example application to test export functionality:

```dart
import 'package:flutter/material.dart';
import 'lib/examples/csv_export_example.dart';

void main() {
  runApp(MaterialApp(
    home: CsvExportExample(),
  ));
}
```

## Support

For issues or questions regarding CSV export functionality:
1. Check this documentation
2. Review the example implementation
3. Verify all dependencies are installed
4. Test with sample data first