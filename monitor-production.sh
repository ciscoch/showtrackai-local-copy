#!/bin/bash

# Configuration - UPDATE THESE VALUES FOR YOUR ACTUAL SITE
SITE_URL="https://your-actual-site-name.netlify.app"  # UPDATE THIS
SITE_NAME="your-actual-site-name"                    # UPDATE THIS  
DEPLOY_LOG_URL="https://app.netlify.com/sites/$SITE_NAME/deploys"

echo "⚠️  IMPORTANT: Update SITE_URL and SITE_NAME in this script with your actual Netlify site details"

echo "🔍 Monitoring production deployment..."
echo "📊 Deploy logs: $DEPLOY_LOG_URL"
echo "🌐 Site URL: $SITE_URL"
echo "⏱️  Starting monitoring at: $(date)"
echo ""

# Function to check HTTP response
check_site_health() {
    local url=$1
    local response=$(curl -s -w "%{http_code}" -o /dev/null --max-time 10 "$url")
    
    if [ "$response" = "200" ]; then
        echo "✅ Site responding (HTTP $response)"
        return 0
    else
        echo "❌ Site not responding (HTTP $response)"
        return 1
    fi
}

# Function to check for Flutter app initialization
check_flutter_init() {
    local url=$1
    local content=$(curl -s --max-time 10 "$url")
    
    if echo "$content" | grep -q "flutter-view\|flt-renderer\|Flutter"; then
        echo "✅ Flutter app structure detected"
        return 0
    else
        echo "❌ Flutter app structure not found"
        return 1
    fi
}

# Function to check for specific content
check_app_content() {
    local url=$1
    local content=$(curl -s --max-time 10 "$url")
    
    # Check for ShowTrackAI specific content
    if echo "$content" | grep -q -i "showtrackai\|agricultural\|dashboard"; then
        echo "✅ ShowTrackAI app content detected"
        return 0
    else
        echo "❌ ShowTrackAI app content not found"
        return 1
    fi
}

# Function to check for common errors
check_for_errors() {
    local url=$1
    local content=$(curl -s --max-time 10 "$url")
    
    if echo "$content" | grep -q -i "error\|failed\|exception\|404\|500"; then
        echo "⚠️ Potential errors detected in page content"
        echo "$content" | grep -i "error\|failed\|exception" | head -3
        return 1
    else
        echo "✅ No obvious errors in page content"
        return 0
    fi
}

# Function to perform comprehensive health check
comprehensive_health_check() {
    local url=$1
    echo "🏥 Running comprehensive health check..."
    
    local health_score=0
    local total_checks=4
    
    if check_site_health "$url"; then
        ((health_score++))
    fi
    
    if check_flutter_init "$url"; then
        ((health_score++))
    fi
    
    if check_app_content "$url"; then
        ((health_score++))
    fi
    
    if check_for_errors "$url"; then
        ((health_score++))
    fi
    
    echo "📊 Health Score: $health_score/$total_checks"
    
    if [ $health_score -ge 3 ]; then
        echo "✅ Site is healthy"
        return 0
    else
        echo "❌ Site has issues"
        return 1
    fi
}

# Monitor deployment for 10 minutes (20 checks, 30 seconds apart)
echo "⏱️  Starting 10-minute monitoring period..."
echo "Will check every 30 seconds for healthy deployment..."
echo ""

for i in {1..20}; do
    echo "🔍 Check $i/20 ($(date '+%H:%M:%S'))..."
    
    if comprehensive_health_check "$SITE_URL"; then
        echo ""
        echo "🎉 DEPLOYMENT SUCCESSFUL!"
        echo "========================"
        echo "✅ Site is responding properly"
        echo "✅ Flutter app initialized"
        echo "✅ Content loading correctly"
        echo "✅ No obvious errors detected"
        echo ""
        echo "🧪 Manual Testing Required:"
        echo "1. Open: $SITE_URL"
        echo "2. Check browser console for errors"
        echo "3. Test login functionality"
        echo "4. Verify dashboard loads"
        echo "5. Test journal entry creation"
        echo "6. Check mobile responsiveness"
        echo ""
        echo "📋 Use the testing checklist:"
        echo "   ./production-testing-checklist.md"
        echo ""
        
        # Additional automated checks
        echo "🔧 Additional Checks:"
        
        # Check if login page is accessible
        LOGIN_CHECK=$(curl -s -w "%{http_code}" -o /dev/null "$SITE_URL/login" 2>/dev/null || echo "000")
        if [ "$LOGIN_CHECK" = "200" ] || [ "$LOGIN_CHECK" = "404" ]; then
            echo "✅ Routing appears to be working"
        else
            echo "⚠️ Routing may have issues (check SPA configuration)"
        fi
        
        # Check for mobile viewport
        MOBILE_CHECK=$(curl -s "$SITE_URL" | grep -i "viewport")
        if [ -n "$MOBILE_CHECK" ]; then
            echo "✅ Mobile viewport configuration found"
        else
            echo "⚠️ Mobile viewport configuration not detected"
        fi
        
        break
    else
        if [ $i -eq 20 ]; then
            echo ""
            echo "❌ DEPLOYMENT FAILED"
            echo "==================="
            echo "Site did not become healthy after 10 minutes"
            echo ""
            echo "🔧 Troubleshooting Steps:"
            echo "1. Check Netlify deploy logs: $DEPLOY_LOG_URL"
            echo "2. Check browser console at: $SITE_URL"
            echo "3. Review recent commits for issues"
            echo ""
            echo "🔄 Rollback Options:"
            echo "- Quick rollback: ./rollback-with-revert.sh"
            echo "- Hard rollback: ./rollback-deployment.sh"
            echo "- Netlify UI rollback: $DEPLOY_LOG_URL"
            echo ""
            echo "📞 Debug Information:"
            echo "- Last HTTP response: $(curl -s -w "%{http_code}" -o /dev/null "$SITE_URL" 2>/dev/null || echo "No response")"
            echo "- Deploy time: $(date)"
            echo "- Monitoring duration: 10 minutes"
            
            exit 1
        fi
        
        echo "⏳ Waiting 30 seconds before next check..."
        sleep 30
    fi
done

echo ""
echo "📈 Monitoring completed successfully!"
echo "🎯 Next steps: Run comprehensive manual testing"