# Shared Configuration and Utilities

This directory contains shared configuration files, utilities, and constants used across the message publisher system.

## Structure

```
shared/
├── config/           # Configuration files
├── utils/           # Utility functions
├── constants/       # Application constants
└── types/           # Type definitions (if using TypeScript)
```

## Usage

Import shared utilities in your services:

```javascript
// API Service
import { validateMessage } from '../shared/utils/validation.js';
import { MESSAGE_TYPES } from '../shared/constants/messageTypes.js';

// Workers
import { processMessage } from '../shared/utils/messageProcessor.js';
```

## Configuration

Shared configuration helps maintain consistency across services while allowing service-specific overrides.
