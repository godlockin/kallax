/**
 * KALLAX Self-Evolution — eat-dog-food: KALLAX manages its own development.
 * Auto-creates improvement tickets from quality trends and routes them.
 */
import { logger } from '../utils/logger.js';

export interface ImprovementTicket {
  id: string;
  title: string;
  description: string;
  priority: 'P0' | 'P1' | 'P2';
  source: 'quality-trend' | 'performer-feedback' | 'system-metric';
  sourceDetail: string;
  createdAt: number;
  status: 'open' | 'claimed' | 'done';
  assignedTo?: string;
}

export interface EvolutionStats {
  totalImprovements: number;
  openCount: number;
  doneCount: number;
  selfManagedRatio: number; // % of tickets that are self-created
  topCategories: Array<{ source: string; count: number }>;
}

export interface SelfEvolution {
  /** Create an improvement ticket from a detected issue */
  createImprovement(title: string, description: string, source: ImprovementTicket['source'], detail: string, priority?: ImprovementTicket['priority']): ImprovementTicket;
  /** Get all open improvement tickets, sorted by priority */
  getOpenImprovements(): ImprovementTicket[];
  /** Claim an improvement ticket for a performer */
  claimImprovement(ticketId: string, performerId: string): boolean;
  /** Mark an improvement as done */
  completeImprovement(ticketId: string): boolean;
  /** Get evolution stats */
  getStats(): EvolutionStats;
  /** List all tickets */
  listAll(): ImprovementTicket[];
}

const PRIORITY_ORDER: Record<string, number> = { P0: 0, P1: 1, P2: 2 };

function generateId(): string { return `evo_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`; }

export function createSelfEvolution(): SelfEvolution {
  const tickets: ImprovementTicket[] = [];

  return {
    createImprovement(title: string, description: string, source: ImprovementTicket['source'], detail: string, priority: ImprovementTicket['priority'] = 'P2'): ImprovementTicket {
      const ticket: ImprovementTicket = {
        id: generateId(), title, description, priority, source, sourceDetail: detail,
        createdAt: Date.now(), status: 'open',
      };
      tickets.unshift(ticket);
      logger.info({ ticketId: ticket.id, title, source, priority }, 'self-evolution: improvement ticket created');
      return ticket;
    },

    getOpenImprovements(): ImprovementTicket[] {
      return tickets.filter(t => t.status === 'open').sort((a, b) => (PRIORITY_ORDER[a.priority] ?? 9) - (PRIORITY_ORDER[b.priority] ?? 9));
    },

    claimImprovement(ticketId: string, performerId: string): boolean {
      const t = tickets.find(t => t.id === ticketId && t.status === 'open');
      if (!t) return false;
      (t as { status: string; assignedTo?: string }).status = 'claimed';
      (t as { assignedTo?: string }).assignedTo = performerId;
      logger.info({ ticketId, performerId }, 'self-evolution: improvement claimed');
      return true;
    },

    completeImprovement(ticketId: string): boolean {
      const t = tickets.find(t => t.id === ticketId);
      if (!t) return false;
      (t as { status: string }).status = 'done';
      logger.info({ ticketId }, 'self-evolution: improvement completed');
      return true;
    },

    getStats(): EvolutionStats {
      const open = tickets.filter(t => t.status === 'open').length;
      const done = tickets.filter(t => t.status === 'done').length;
      const bySource: Record<string, number> = {};
      for (const t of tickets) { bySource[t.source] = (bySource[t.source] ?? 0) + 1; }
      return {
        totalImprovements: tickets.length,
        openCount: open,
        doneCount: done,
        selfManagedRatio: tickets.length > 0 ? Math.round((done / tickets.length) * 100) : 0,
        topCategories: Object.entries(bySource).map(([source, count]) => ({ source, count })).sort((a, b) => b.count - a.count).slice(0, 5),
      };
    },

    listAll(): ImprovementTicket[] {
      return [...tickets];
    },
  };
}

let instance: SelfEvolution | null = null;
export function getSelfEvolution(): SelfEvolution { return instance ?? (instance = createSelfEvolution()); }
