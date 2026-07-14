/**
 * KALLAX DI Container — simple IoC with singleton/transient lifetimes.
 */

import type { KallaxResult } from '../types/index.js';
import { ok, err } from 'neverthrow';
import { KallaxError, KallaxErrorCode } from '../types/index.js';
import { logger } from '../utils/logger.js';

export type Lifetime = 'singleton' | 'transient';

export interface ServiceDescriptor<T = unknown> {
  readonly name: string;
  readonly lifetime: Lifetime;
  readonly factory: (container: DIContainer) => T;
  instance?: T;
}

export interface DIContainer {
  register: <T>(name: string, factory: (c: DIContainer) => T, lifetime?: Lifetime) => KallaxResult<void>;
  resolve: <T>(name: string) => KallaxResult<T>;
  has: (name: string) => boolean;
  remove: (name: string) => void;
  reset: () => void;
  getStats: () => ContainerStats;
  createChild: (name: string) => DIContainer;
}

export interface ContainerStats {
  readonly totalServices: number;
  readonly singletons: number;
  readonly transients: number;
  readonly instantiatedSingletons: number;
  readonly serviceNames: string[];
}

function buildChildContainer(parent: DIContainer, childName: string): DIContainer {
  const childServices = new Map<string, ServiceDescriptor>();
  let cSingleton = 0;
  let cTransient = 0;
  let cInstantiated = 0;

  const child: DIContainer = {
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-type-parameters
    register<T>(svcName: string, factory: (c: DIContainer) => T, lifetime: Lifetime = 'singleton'): KallaxResult<void> {
      if (childServices.has(svcName)) {
        return err(new KallaxError(KallaxErrorCode.INSTANCE_ALREADY_EXISTS, `Service ${svcName} already registered`));
      }
      childServices.set(svcName, { name: svcName, lifetime, factory: factory });
      if (lifetime === 'singleton') cSingleton++; else cTransient++;
      return ok(undefined);
    },

    resolve<T>(svcName: string): KallaxResult<T> {
      const desc = childServices.get(svcName);
      if (desc) {
        if (desc.lifetime === 'singleton' && desc.instance !== undefined) {
          return ok(desc.instance as T);
        }
        try {
          const instance = desc.factory(child);
          if (desc.lifetime === 'singleton') { desc.instance = instance; cInstantiated++; }
          return ok(instance as T);
        } catch {
          return err(new KallaxError(KallaxErrorCode.INTERNAL_ERROR, `Failed to instantiate ${svcName}`));
        }
      }
      return parent.resolve<T>(svcName);
    },

    has(svcName: string): boolean {
      return childServices.has(svcName) || parent.has(svcName);
    },

    remove(svcName: string): void {
      const desc = childServices.get(svcName);
      if (desc) {
        if (desc.lifetime === 'singleton') cSingleton--; else cTransient--;
        if (desc.instance !== undefined) cInstantiated--;
        childServices.delete(svcName);
      }
    },

    reset(): void {
      childServices.clear();
      cSingleton = 0; cTransient = 0; cInstantiated = 0;
    },

    getStats(): ContainerStats {
      const ps = parent.getStats();
      return {
        totalServices: childServices.size + ps.totalServices,
        singletons: cSingleton + ps.singletons,
        transients: cTransient + ps.transients,
        instantiatedSingletons: cInstantiated + ps.instantiatedSingletons,
        serviceNames: [...Array.from(childServices.keys()), ...ps.serviceNames],
      };
    },

    createChild(grandchildName: string): DIContainer {
      return buildChildContainer(child, grandchildName);
    },
  };

  logger.debug({ child: childName }, 'child container created');
  return child;
}

export function createDIContainer(name = 'root'): DIContainer {
  const services = new Map<string, ServiceDescriptor>();
  let singletonCount = 0;
  let transientCount = 0;
  let instantiatedCount = 0;

  return {
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-type-parameters
    register<T>(svcName: string, factory: (c: DIContainer) => T, lifetime: Lifetime = 'singleton'): KallaxResult<void> {
      if (services.has(svcName)) {
        return err(new KallaxError(
          KallaxErrorCode.INSTANCE_ALREADY_EXISTS,
          `Service ${svcName} already registered in container ${name}`,
        ));
      }

      services.set(svcName, {
        name: svcName,
        lifetime,
        factory: factory,
      });

      if (lifetime === 'singleton') {
        singletonCount++;
      } else {
        transientCount++;
      }

      logger.debug({ container: name, service: svcName, lifetime }, 'service registered');
      return ok(undefined);
    },

    resolve<T>(svcName: string): KallaxResult<T> {
      const descriptor = services.get(svcName);
      if (!descriptor) {
        return err(new KallaxError(
          KallaxErrorCode.INSTANCE_NOT_FOUND,
          `Service ${svcName} not found in container ${name}. Available: ${Array.from(services.keys()).join(', ')}`,
        ));
      }

      if (descriptor.lifetime === 'singleton' && descriptor.instance !== undefined) {
        return ok(descriptor.instance as T);
      }

      try {
        const instance = descriptor.factory(this);
        if (descriptor.lifetime === 'singleton') {
          descriptor.instance = instance;
          instantiatedCount++;
        }
        return ok(instance as T);
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        return err(new KallaxError(
          KallaxErrorCode.INTERNAL_ERROR,
          `Failed to instantiate service ${svcName}: ${msg}`,
          { cause: error },
        ));
      }
    },

    has(svcName: string): boolean {
      return services.has(svcName);
    },

    remove(svcName: string): void {
      const desc = services.get(svcName);
      if (desc) {
        if (desc.lifetime === 'singleton') singletonCount--;
        else transientCount--;
        if (desc.instance !== undefined) instantiatedCount--;
        services.delete(svcName);
        logger.debug({ container: name, service: svcName }, 'service removed');
      }
    },

    reset(): void {
      const count = services.size;
      services.clear();
      singletonCount = 0;
      transientCount = 0;
      instantiatedCount = 0;
      logger.info({ container: name, removedCount: count }, 'container reset');
    },

    getStats(): ContainerStats {
      return {
        totalServices: services.size,
        singletons: singletonCount,
        transients: transientCount,
        instantiatedSingletons: instantiatedCount,
        serviceNames: Array.from(services.keys()),
      };
    },

    createChild(childName: string): DIContainer {
      return buildChildContainer(this, childName);
    },
  };
}

// Default container
let defaultContainer: DIContainer | null = null;

export function getDIContainer(): DIContainer {
  defaultContainer ??= createDIContainer();
  return defaultContainer;
}

export function resetDIContainer(): void {
  if (defaultContainer) {
    defaultContainer.reset();
  }
  defaultContainer = null;
}
