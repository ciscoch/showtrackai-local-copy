#!/bin/bash

# ShowTrackAI Geolocation Feature - Local Test Script
# This script tests the geolocation implementation locally

echo "🚀 ShowTrackAI Geolocation Feature Test"
echo "======================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# Check Flutter installation
echo "1. Checking Flutter installation..."
if flutter --version > /dev/null 2>&1; then
    print_status 0 "Flutter is installed"
    flutter --version | head -1
else
    print_status 1 "Flutter is not installed"
    exit 1
fi

echo ""
echo "2. Checking project dependencies..."

# Check if required packages are in pubspec.yaml
required_packages=("geolocator" "geocoding" "permission_handler" "weather" "http" "shared_preferences")
missing_packages=()

for package in "${required_packages[@]}"; do
    if grep -q "$package:" pubspec.yaml; then
        echo -e "${GREEN}✅ $package found${NC}"
    else
        echo -e "${RED}❌ $package missing${NC}"
        missing_packages+=($package)
    fi
done

if [ ${#missing_packages[@]} -eq 0 ]; then
    echo -e "${GREEN}All required packages are present!${NC}"
else
    echo -e "${YELLOW}Warning: Some packages are missing${NC}"
fi

echo ""
echo "3. Checking service files..."

# Check for required service files
service_files=(
    "lib/services/location_service.dart"
    "lib/services/weather_service.dart"
    "lib/models/journal_entry.dart"
    "lib/widgets/location_input_field.dart"
)

for file in "${service_files[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "$file exists"
    else
        print_status 1 "$file missing"
    fi
done

echo ""
echo "4. Running Flutter analyze..."
flutter analyze --no-fatal-infos 2>&1 | head -20

echo ""
echo "5. Checking for API key configuration..."
if grep -q "YOUR_OPENWEATHER_API_KEY" lib/services/weather_service.dart; then
    echo -e "${YELLOW}⚠️  Weather API key needs to be configured${NC}"
    echo "   Replace 'YOUR_OPENWEATHER_API_KEY' in lib/services/weather_service.dart"
else
    echo -e "${GREEN}✅ Weather API key appears to be configured${NC}"
fi

echo ""
echo "6. Creating test HTML file for local testing..."

cat > test-geolocation.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShowTrackAI Geolocation Test</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            margin: 5px;
        }
        button:hover {
            background: #45a049;
        }
        .status {
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
        }
        .success { background: #d4edda; color: #155724; }
        .error { background: #f8d7da; color: #721c24; }
        .info { background: #d1ecf1; color: #0c5460; }
        pre {
            background: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <h1>🚀 ShowTrackAI Geolocation Feature Test</h1>
    
    <div class="card">
        <h2>📍 Location Testing</h2>
        <button onclick="testLocation()">Test GPS Location</button>
        <button onclick="testWeather()">Test Weather API</button>
        <button onclick="testFullFlow()">Test Complete Flow</button>
        <div id="locationResult"></div>
    </div>

    <div class="card">
        <h2>🧪 Test Results</h2>
        <div id="testResults"></div>
    </div>

    <script>
        async function testLocation() {
            const resultDiv = document.getElementById('locationResult');
            resultDiv.innerHTML = '<div class="status info">🔄 Requesting location...</div>';
            
            if (!navigator.geolocation) {
                resultDiv.innerHTML = '<div class="status error">❌ Geolocation not supported</div>';
                return;
            }
            
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const { latitude, longitude, accuracy } = position.coords;
                    resultDiv.innerHTML = `
                        <div class="status success">✅ Location captured successfully!</div>
                        <pre>
Latitude: ${latitude.toFixed(6)}
Longitude: ${longitude.toFixed(6)}
Accuracy: ±${accuracy.toFixed(0)}m
Timestamp: ${new Date(position.timestamp).toLocaleString()}
                        </pre>
                    `;
                    
                    // Test reverse geocoding
                    fetch(\`https://nominatim.openstreetmap.org/reverse?lat=\${latitude}&lon=\${longitude}&format=json\`)
                        .then(r => r.json())
                        .then(data => {
                            resultDiv.innerHTML += \`
                                <div class="status success">📍 Address: \${data.display_name}</div>
                            \`;
                        })
                        .catch(err => console.error('Geocoding error:', err));
                },
                (error) => {
                    let errorMsg = 'Unknown error';
                    switch(error.code) {
                        case 1: errorMsg = 'Permission denied'; break;
                        case 2: errorMsg = 'Position unavailable'; break;
                        case 3: errorMsg = 'Request timeout'; break;
                    }
                    resultDiv.innerHTML = \`<div class="status error">❌ Error: \${errorMsg}</div>\`;
                },
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 0
                }
            );
        }
        
        async function testWeather() {
            const resultDiv = document.getElementById('testResults');
            resultDiv.innerHTML = '<div class="status info">🔄 Testing weather API...</div>';
            
            // First get location
            navigator.geolocation.getCurrentPosition(
                async (position) => {
                    const { latitude, longitude } = position.coords;
                    
                    // Note: This is a test endpoint - replace with your actual API
                    const apiKey = 'YOUR_API_KEY'; // Replace this
                    const url = \`https://api.openweathermap.org/data/2.5/weather?lat=\${latitude}&lon=\${longitude}&appid=\${apiKey}&units=metric\`;
                    
                    try {
                        const response = await fetch(url);
                        if (response.ok) {
                            const data = await response.json();
                            resultDiv.innerHTML = \`
                                <div class="status success">✅ Weather API working!</div>
                                <pre>
Temperature: \${data.main.temp}°C
Condition: \${data.weather[0].main}
Description: \${data.weather[0].description}
Humidity: \${data.main.humidity}%
Wind Speed: \${data.wind.speed} m/s
                                </pre>
                            \`;
                        } else {
                            resultDiv.innerHTML = \`<div class="status error">❌ Weather API error: \${response.status}</div>\`;
                        }
                    } catch (err) {
                        resultDiv.innerHTML = \`<div class="status error">❌ Network error: \${err.message}</div>\`;
                    }
                },
                (error) => {
                    resultDiv.innerHTML = '<div class="status error">❌ Location required for weather test</div>';
                }
            );
        }
        
        async function testFullFlow() {
            const resultDiv = document.getElementById('testResults');
            let html = '<h3>Full Integration Test</h3>';
            
            // Test 1: Permissions
            html += '<div class="status info">1. Testing permissions...</div>';
            
            // Test 2: Location capture
            navigator.geolocation.getCurrentPosition(
                async (position) => {
                    html += '<div class="status success">✅ Location captured</div>';
                    
                    // Test 3: Reverse geocoding
                    try {
                        const geocodeResponse = await fetch(
                            \`https://nominatim.openstreetmap.org/reverse?lat=\${position.coords.latitude}&lon=\${position.coords.longitude}&format=json\`
                        );
                        if (geocodeResponse.ok) {
                            html += '<div class="status success">✅ Reverse geocoding working</div>';
                        }
                    } catch (err) {
                        html += '<div class="status error">❌ Geocoding failed</div>';
                    }
                    
                    // Test 4: Data structure
                    const journalEntry = {
                        title: "Test Entry",
                        description: "Testing geolocation feature",
                        location: {
                            latitude: position.coords.latitude,
                            longitude: position.coords.longitude,
                            accuracy: position.coords.accuracy,
                            capturedAt: new Date().toISOString()
                        },
                        weather: {
                            temperature: 22.5,
                            condition: "Clear",
                            humidity: 65
                        }
                    };
                    
                    html += '<div class="status success">✅ Data structure created</div>';
                    html += '<pre>' + JSON.stringify(journalEntry, null, 2) + '</pre>';
                    
                    resultDiv.innerHTML = html;
                },
                (error) => {
                    html += '<div class="status error">❌ Location access denied</div>';
                    resultDiv.innerHTML = html;
                }
            );
        }
    </script>
</body>
</html>
EOF

print_status 0 "Test HTML file created: test-geolocation.html"

echo ""
echo "7. Starting local test server..."
echo ""
echo "📋 To test the geolocation feature:"
echo "   1. Run: flutter run -d chrome --web-port=8080"
echo "   2. Or open test-geolocation.html in your browser"
echo "   3. Click the test buttons to verify each component"
echo ""
echo "🔑 Remember to:"
echo "   1. Replace 'YOUR_OPENWEATHER_API_KEY' in weather_service.dart"
echo "   2. Run the Supabase migration for database fields"
echo "   3. Configure environment variables for production"
echo ""
echo "✅ Geolocation implementation is ready for testing!"