#!/bin/bash
# Generate data and run basic validation
# Data Engineer II Challenge

echo "🚀 Retail Analytics Data Generation & Validation"
echo "================================================"

# Check Python dependencies
echo "📋 Checking Python dependencies..."
python3 -c "import faker, pandas, numpy; print('✅ All dependencies available')" || {
    echo "❌ Missing dependencies. Installing..."
    pip3 install -r requirements.txt
}

# Generate data
echo "🔄 Generating data..."
python3 00_generate_data.py

# Validate generated files
echo "🔍 Validating generated files..."
for file in data/*.csv; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        echo "✅ $file: $lines lines"
    else
        echo "❌ Missing: $file"
    fi
done

# Check file sizes
echo "📊 File sizes:"
du -h data/*.csv

echo "✅ Data generation and validation completed!"
