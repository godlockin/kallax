/**
 * KALLAX Process Cleanup
 * Graceful shutdown handling with resource cleanup
 */

import { logger } from './logger.js';

type CleanupHandler = () => Promise<void> | void;

interface CleanupRegistry {
  readonly handlers: Map<string, CleanupHandler>;
  isShuttingDown: boolean;
}

const registry: CleanupRegistry = {
  handlers: new Map(),
  isShuttingDown: false,
};

/**
 * Register a cleanup handler
 */
export function registerCleanupHandler(name: string, handler: CleanupHandler): void {
  if (registry.handlers.has(name)) {
    logger.warn({ handlerName: name }, 'cleanup handler already registered, replacing');
  }
  registry.handlers.set(name, handler);
  logger.debug({ handlerName: name }, 'cleanup handler registered');
}

/**
 * Unregister a cleanup handler
 */
export function unregisterCleanupHandler(name: string): boolean {
  const removed = registry.handlers.delete(name);
  if (removed) {
    logger.debug({ handlerName: name }, 'cleanup handler unregistered');
  }
  return removed;
}

/**
 * Execute all cleanup handlers
 */
async function executeCleanup(signal: string): Promise<void> {
  if (registry.isShuttingDown) {
    logger.warn({ signal }, 'cleanup already in progress');
    return;
  }

  registry.isShuttingDown = true;
  logger.info({ signal, handlerCount: registry.handlers.size }, 'executing cleanup handlers');

  const errors: Array<{ name: string; error: unknown }> = [];

  // Execute handlers in reverse registration order
  const handlersArray = Array.from(registry.handlers.entries()).reverse();

  for (const [name, handler] of handlersArray) {
    try {
      logger.debug({ handlerName: name }, 'executing cleanup handler');
      await handler();
      logger.debug({ handlerName: name }, 'cleanup handler completed');
    } catch (error: unknown) {
      errors.push({ name, error });
      logger.error(
        { handlerName: name, error: error instanceof Error ? error.message : String(error) },
        'cleanup handler failed'
      );
    }
  }

  if (errors.length > 0) {
    logger.warn({ errorCount: errors.length }, 'some cleanup handlers failed');
  } else {
    logger.info({}, 'all cleanup handlers completed successfully');
  }
}

/**
 * Setup process signal handlers
 */
export function setupProcessCleanup(): void {
  const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM', 'SIGHUP'];

  for (const signal of signals) {
    process.on(signal, () => {
      logger.info({ signal }, 'received shutdown signal');
      void executeCleanup(signal).finally(() => {
        process.exit(0);
      });
    });
  }

  // Handle uncaught exceptions
  process.on('uncaughtException', (error: Error) => {
    logger.fatal({ error: error.message, stack: error.stack }, 'uncaught exception');
    void executeCleanup('uncaughtException').finally(() => {
      process.exit(1);
    });
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason: unknown) => {
    logger.fatal(
      { reason: reason instanceof Error ? reason.message : String(reason) },
      'unhandled promise rejection'
    );
    void executeCleanup('unhandledRejection').finally(() => {
      process.exit(1);
    });
  });

  logger.debug({}, 'process cleanup handlers installed');
}

/**
 * Check if shutdown is in progress
 */
export function isShuttingDown(): boolean {
  return registry.isShuttingDown;
}

/**
 * Create a cleanup scope for automatic resource management
 */
export function createCleanupScope(scopeName: string): {
  register: (name: string, handler: CleanupHandler) => void;
  cleanup: () => Promise<void>;
} {
  const scopeHandlers = new Map<string, CleanupHandler>();

  return {
    register(name: string, handler: CleanupHandler): void {
      const fullName = `${scopeName}:${name}`;
      scopeHandlers.set(fullName, handler);
      registerCleanupHandler(fullName, handler);
    },

    async cleanup(): Promise<void> {
      for (const name of scopeHandlers.keys()) {
        const handler = scopeHandlers.get(name);
        if (handler !== undefined) {
          try {
            await handler();
          } catch (error: unknown) {
            logger.error(
              { handlerName: name, error: error instanceof Error ? error.message : String(error) },
              'scope cleanup handler failed'
            );
          }
          unregisterCleanupHandler(name);
        }
      }
      scopeHandlers.clear();
    },
  };
}
