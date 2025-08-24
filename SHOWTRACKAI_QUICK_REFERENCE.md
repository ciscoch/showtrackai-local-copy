# ShowTrackAI - Quick Reference Guide

## 🎯 What is ShowTrackAI?
An AI-powered agricultural education platform for FFA students to track livestock projects, manage finances, maintain digital journals, and progress through FFA degrees.

## 📱 Main Features

### 1. **Dashboard** (`/dashboard`)
- Overview cards for all major features
- Quick stats and insights
- Navigation hub

### 2. **Digital Journaling** (`/journals`)
- **Create Entry**: Text, photos, location (now text-based)
- **AI Analysis**: Automatic skill detection and quality scoring
- **Educational Insights**: Competency mapping to FFA standards
- **Export Options**: PDF, Excel reports

### 3. **Animal Management** (`/animals`)
- **Animal Profile**: Name, breed, age, weight tracking
- **Health Records**: Vaccinations, treatments, vet visits
- **Weight Tracking**: Growth charts and projections
- **Photo Gallery**: Visual progress documentation

### 4. **Financial Tracking** (`/financial`)
- **Expenses**: Feed, medical, equipment costs
- **Income**: Sales, prizes, sponsorships
- **ROI Analysis**: Profit/loss calculations
- **Budget Planning**: Cost projections

### 5. **FFA Progress** (`/ffa`)
- **Discovery Degree**: Entry-level requirements
- **Greenhand Degree**: First-year progress
- **Chapter Degree**: Advanced requirements
- **State Degree**: Highest level tracking
- **SAE Hours**: Supervised Agricultural Experience tracking

## 🗂️ Data Models

### Core Tables
```
- users (authentication)
- user_profiles (student info)
- animals (livestock records)
- journal_entries (daily logs)
- weights (growth tracking)
- health_records (medical history)
- financial_transactions (income/expenses)
- ffa_progress (degree tracking)
- n8n_learning_events (AI analysis)
```

## 🔧 Technical Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL)
- **AI Processing**: n8n workflows
- **Hosting**: Netlify
- **Authentication**: Supabase Auth

## 🚀 Key User Flows

### Journal Entry Flow
1. User creates journal entry
2. Adds text, photos, location
3. Submits to n8n webhook
4. AI analyzes for skills/competencies
5. Quality score generated
6. Results saved to database
7. Dashboard updated

### Animal Management Flow
1. Add animal profile
2. Regular weight entries
3. Health record tracking
4. Photo documentation
5. Growth analysis
6. Show preparation tracking

### Financial Flow
1. Log expenses/income
2. Categorize transactions
3. View reports/analytics
4. Calculate ROI
5. Export for taxes/records

## 🌐 API Endpoints

### n8n Webhook
```
POST https://showtrackai.app.n8n.cloud/webhook/4b52c2de-4d37-4752-aa5c-5741bd9e493d
```

### Supabase
```
URL: https://zifbuzsdhparxlhsifdi.supabase.co
```

## 📊 Key Metrics Tracked
- Journal entries per week
- Animal weight gain rate
- Financial ROI percentage
- FFA degree completion %
- Skill development progress
- Educational quality scores

## 🔐 User Roles
- **Student**: Full access to personal data
- **Educator**: View student progress (with consent)
- **Parent**: Limited view of student data
- **Admin**: System management

## 🎓 Educational Standards
- FFA National Standards alignment
- AET (Agricultural Experience Tracker) compatible
- SAE (Supervised Agricultural Experience) compliant
- State-specific agricultural curriculum support

## 📱 Responsive Design
- Mobile-first approach
- Tablet optimization
- Desktop compatibility
- Offline capability (partial)

## 🚦 Current Status
- ✅ Core features complete
- ✅ AI integration working
- ✅ Database schema stable
- ⚠️ Geolocation removed (text input instead)
- ⚠️ Web deployment issues being resolved

## 🔮 Next Steps
1. Fix Flutter web loading issues
2. Optimize performance
3. Add offline sync
4. Expand AI capabilities
5. Mobile app deployment

---

**Version**: 1.0.0  
**Last Updated**: August 2024  
**Platform**: Web (Flutter)  
**Target Users**: FFA Students (ages 13-18)