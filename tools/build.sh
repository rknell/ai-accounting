#!/bin/bash

# This script runs build_runner to generate code and handles conflicts

# Display help information
show_help() {
  echo "Usage: ./build.sh [OPTIONS]"
  echo ""
  echo "This script runs build_runner to generate JSON serialization code and other generated files."
  echo ""
  echo "Options:"
  echo "  --clean    Clean previous build artifacts before generating new code"
  echo "  --help     Display this help message and exit"
  echo ""
  echo "Examples:"
  echo "  ./build.sh             # Run build_runner with conflict resolution"
  echo "  ./build.sh --clean     # Clean previous artifacts and run build_runner"
}

# Check if help flag is provided
if [[ "$@" == *"--help"* ]]; then
  show_help
  exit 0
fi


echo "Running build_runner for code generation..."

# Check if --clean flag is provided
if [[ "$@" == *"--clean"* ]]; then
  # Clean any previous build artifacts first
  echo "Cleaning previous build artifacts..."
  dart run build_runner clean
fi

# Run build_runner with automatic conflict resolution
echo "Generating code with conflict resolution..."
dart run build_runner build --delete-conflicting-outputs

# Check if the build was successful
if [ $? -eq 0 ]; then
  echo "✅ Code generation completed successfully!"
else
  echo "❌ Code generation failed. Please check the errors above."
  exit 1
fi

echo "Done! Generated files are ready."
