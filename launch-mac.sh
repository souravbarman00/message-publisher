#!/bin/bash

# Message Publisher Launcher for macOS
# Double-click this file or run it to launch the application

cd "$(dirname "$0")"

echo "🚀 Message Publisher Launcher for macOS"
echo "======================================"
echo ""
echo "Choose an option:"
echo "1. Setup project (first time)"
echo "2. Start all services"
echo "3. Start API only"
echo "4. Start frontend only"
echo "5. Check system status"
echo "6. Open project in browser"
echo "7. Exit"
echo ""

while true; do
    read -p "Enter your choice (1-7): " choice
    case $choice in
        1)
            echo "Running setup..."
            ./setup-mac.sh setup
            break
            ;;
        2)
            echo "Starting all services..."
            ./setup-mac.sh start
            break
            ;;
        3)
            echo "Starting API service..."
            ./setup-mac.sh start-api
            break
            ;;
        4)
            echo "Starting frontend..."
            ./setup-mac.sh start-frontend
            break
            ;;
        5)
            echo "Checking system status..."
            ./setup-mac.sh check
            read -p "Press Enter to continue..."
            ;;
        6)
            echo "Opening in browser..."
            ./setup-mac.sh open
            read -p "Press Enter to continue..."
            ;;
        7)
            echo "Goodbye! 👋"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please enter 1-7."
            ;;
    esac
done