#!/bin/bash

# Navigate to root if currently in build/web
if [[ $(basename "$PWD") == "web" && $(basename "$(dirname "$PWD")") == "build" ]]; then
  cd ../..
fi

# Prompt for commit message
echo "📝 Enter your commit message:"
read commitMessage

# Build Flutter web app
echo "🔨 Building Flutter web..."
flutter build web || { echo "❌ Build failed"; exit 1; }

# Navigate to build/web
cd build/web || { echo "❌ Could not navigate to build/web"; exit 1; }

# Git add, commit, and force push
echo "📤 Deploying to GitHub with commit: \"$commitMessage\""
git add .
git commit -m "$commitMessage"
git push -u origin main --force

echo "✅ Redeployment complete!"