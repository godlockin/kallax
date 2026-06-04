# @kallax/sdk

JavaScript/TypeScript SDK for KALLAX multi-agent orchestration API.

## Install
```bash
npm install @kallax/sdk
```

## Usage
```typescript
import { KallaxClient } from '@kallax/sdk';

const kallax = new KallaxClient({ baseUrl: 'http://localhost:9877' });

// Create ticket
const ticket = await kallax.createTicket('Implement feature X', { priority: 'P1' });

// Claim task  
const task = await kallax.claimTask('task-123');

// Health check
const health = await kallax.health();
```
