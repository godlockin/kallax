/**
 * File-based DataAdapter implementation (跟 v2.7.4 D4 联合, 跟 Rule 8 联合)
 * Reads/writes team collaboration data from/to jira/ JSON files.
 * Used when kallax.db does not exist.
 */

import { err, ok } from 'neverthrow';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { KallaxResult } from '../../types/index.js';
import type { DataAdapter, Epic, Phase, ProjectTicket } from './types.js';
import { createDataError, readDirSafe } from './helpers.js';


/**
 * Reads/writes team collaboration data from/to jira/ JSON files.
 * Used when kallax.db does not exist.
 */
export class FileDataAdapter implements DataAdapter {
  private readonly jiraDir: string;

  constructor(jiraDir: string) {
    this.jiraDir = jiraDir;
  }

  readPhase(phaseId: string): KallaxResult<Phase | null> {
    try {
      const phasePath = join(this.jiraDir, 'phases', phaseId, 'phase.json');
      if (!existsSync(phasePath)) return ok(null);
      const raw = readFileSync(phasePath, 'utf-8');
      return ok(JSON.parse(raw) as Phase);
    } catch (error: unknown) {
      return err(createDataError('Failed to read phase', error));
    }
  }

  writePhase(phase: Phase): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'phases', phase.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'phase.json'), JSON.stringify(phase, null, 2), 'utf-8');
      this.updatePhaseIndex(phase);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write phase', error));
    }
  }

  readEpic(epicId: string): KallaxResult<Epic | null> {
    try {
      const epicPath = join(this.jiraDir, 'epics', epicId, 'epic.json');
      if (!existsSync(epicPath)) return ok(null);
      const raw = readFileSync(epicPath, 'utf-8');
      return ok(JSON.parse(raw) as Epic);
    } catch (error: unknown) {
      return err(createDataError('Failed to read epic', error));
    }
  }

  writeEpic(epic: Epic): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'epics', epic.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'epic.json'), JSON.stringify(epic, null, 2), 'utf-8');
      this.updateEpicIndex(epic);
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write epic', error));
    }
  }

  readTicket(ticketId: string): KallaxResult<ProjectTicket | null> {
    try {
      const ticketPath = join(this.jiraDir, 'tickets', ticketId, 'ticket.json');
      if (!existsSync(ticketPath)) return ok(null);
      const raw = readFileSync(ticketPath, 'utf-8');
      return ok(JSON.parse(raw) as ProjectTicket);
    } catch (error: unknown) {
      return err(createDataError('Failed to read ticket', error));
    }
  }

  writeTicket(ticket: ProjectTicket): KallaxResult<void> {
    try {
      const dir = join(this.jiraDir, 'tickets', ticket.id);
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'ticket.json'), JSON.stringify(ticket, null, 2), 'utf-8');
      return ok(undefined);
    } catch (error: unknown) {
      return err(createDataError('Failed to write ticket', error));
    }
  }

  syncToDb(): KallaxResult<void> {
    return ok(undefined); // No-op: no DB to sync to in file mode
  }

  syncToFiles(): KallaxResult<void> {
    return ok(undefined); // No-op: already using files
  }

  listPhases(): KallaxResult<Phase[]> {
    try {
      const index = this.readPhaseIndex();
      const phases: Phase[] = [];
      for (const entry of index.phases) {
        const result = this.readPhase(entry.id);
        if (result.isOk() && result.value) phases.push(result.value);
      }
      return ok(phases);
    } catch (error: unknown) {
      return err(createDataError('Failed to list phases', error));
    }
  }

  listEpics(phaseId?: string): KallaxResult<Epic[]> {
    try {
      const index = this.readEpicIndex();
      let entries = index.epics;
      if (phaseId != null) entries = entries.filter((e: { id: string; phase: string }) => e.phase === phaseId);
      const epics: Epic[] = [];
      for (const entry of entries) {
        const result = this.readEpic(entry.id);
        if (result.isOk() && result.value != null && (phaseId == null || result.value.phaseId === phaseId)) {
          epics.push(result.value);
        }
      }
      return ok(epics);
    } catch (error: unknown) {
      return err(createDataError('Failed to list epics', error));
    }
  }

  listTickets(epicId?: string): KallaxResult<ProjectTicket[]> {
    try {
      const ticketsDir = join(this.jiraDir, 'tickets');
      if (!existsSync(ticketsDir)) return ok([]);
      const entries = readDirSafe(ticketsDir);
      const tickets: ProjectTicket[] = [];
      for (const entry of entries) {
        const ticketPath = join(ticketsDir, entry, 'ticket.json');
        if (!existsSync(ticketPath)) continue;
        const raw = readFileSync(ticketPath, 'utf-8');
        const ticket = JSON.parse(raw) as ProjectTicket;
        if (epicId == null || ticket.epicId === epicId) tickets.push(ticket);
      }
      return ok(tickets);
    } catch (error: unknown) {
      return err(createDataError('Failed to list tickets', error));
    }
  }

  close(): void {
    // No-op for file adapter
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  private readPhaseIndex(): { phases: Array<{ id: string; status: string; start_time: string; delivery_time: string }> } {
    const indexPath = join(this.jiraDir, 'phases', 'phase_index.json');
    if (!existsSync(indexPath)) return { phases: [] };
    return JSON.parse(readFileSync(indexPath, 'utf-8')) as { phases: Array<{ id: string; status: string; start_time: string; delivery_time: string }> };
  }

  private updatePhaseIndex(phase: Phase): void {
    const index = this.readPhaseIndex();
    const existing = index.phases.findIndex((p) => p.id === phase.id);
    const entry = { id: phase.id, status: phase.status, start_time: phase.startTime ?? '', delivery_time: phase.deliveryTime ?? '' };
    if (existing >= 0) {
      index.phases[existing] = entry;
    } else {
      index.phases.push(entry);
    }
    writeFileSync(join(this.jiraDir, 'phases', 'phase_index.json'), JSON.stringify(index, null, 2), 'utf-8');
  }

  private readEpicIndex(): { epics: Array<{ id: string; phase: string; status: string; start_time: string; delivery_time: string }> } {
    const indexPath = join(this.jiraDir, 'epics', 'epic_index.json');
    if (!existsSync(indexPath)) return { epics: [] };
    return JSON.parse(readFileSync(indexPath, 'utf-8')) as { epics: Array<{ id: string; phase: string; status: string; start_time: string; delivery_time: string }> };
  }

  private updateEpicIndex(epic: Epic): void {
    const index = this.readEpicIndex();
    const existing = index.epics.findIndex((e) => e.id === epic.id);
    const entry = { id: epic.id, phase: epic.phaseId, status: epic.status, start_time: epic.startTime ?? '', delivery_time: epic.deliveryTime ?? '' };
    if (existing >= 0) {
      index.epics[existing] = entry;
    } else {
      index.epics.push(entry);
    }
    writeFileSync(join(this.jiraDir, 'epics', 'epic_index.json'), JSON.stringify(index, null, 2), 'utf-8');
  }
}

