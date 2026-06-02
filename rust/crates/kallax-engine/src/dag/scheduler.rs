//! DAG Scheduler implementation
//!
//! Schedules tasks based on dependency graph using topological sort.

use kallax_core::{KallaxError, Result, Task, TaskId, TaskStatus};
use std::collections::{HashMap, HashSet, VecDeque};

/// DAG Scheduler for task dependency management
pub struct DagScheduler {
    /// Task ID -> Task
    tasks: HashMap<String, Task>,
    /// Task ID -> Dependent task IDs (tasks that depend on this task)
    dependents: HashMap<String, HashSet<String>>,
    /// Task ID -> Number of unresolved dependencies
    in_degree: HashMap<String, usize>,
}

impl DagScheduler {
    /// Create a new DAG scheduler
    pub fn new() -> Self {
        Self {
            tasks: HashMap::new(),
            dependents: HashMap::new(),
            in_degree: HashMap::new(),
        }
    }

    /// Add a task to the scheduler
    pub fn add_task(&mut self, task: Task) -> Result<()> {
        let task_id = task.id().as_str().to_string();

        if self.tasks.contains_key(&task_id) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "task",
                entity_id: task_id,
            });
        }

        // Count dependencies
        let dep_count = task.dependencies().len();
        self.in_degree.insert(task_id.clone(), dep_count);

        // Register this task as a dependent of its dependencies
        for dep_id in task.dependencies() {
            self.dependents
                .entry(dep_id.as_str().to_string())
                .or_insert_with(HashSet::new)
                .insert(task_id.clone());
        }

        self.tasks.insert(task_id, task);
        Ok(())
    }

    /// Get tasks that are ready to execute (no pending dependencies)
    pub fn get_ready_tasks(&self) -> Vec<&Task> {
        self.tasks
            .iter()
            .filter(|(id, task)| {
                task.status() == TaskStatus::Pending &&
                self.in_degree.get(*id).map_or(false, |&d| d == 0)
            })
            .map(|(_, task)| task)
            .collect()
    }

    /// Mark a task as completed and update dependencies
    pub fn complete_task(&mut self, task_id: &str) -> Result<Vec<TaskId>> {
        // Verify task exists
        if !self.tasks.contains_key(task_id) {
            return Err(KallaxError::not_found("task", task_id));
        }

        // Get dependents that may now be ready
        let newly_ready = if let Some(dependents) = self.dependents.get(task_id) {
            dependents
                .iter()
                .filter_map(|dep_id| {
                    if let Some(in_deg) = self.in_degree.get_mut(dep_id) {
                        *in_deg = in_deg.saturating_sub(1);
                        if *in_deg == 0 {
                            return Some(TaskId::from_str(dep_id));
                        }
                    }
                    None
                })
                .collect()
        } else {
            Vec::new()
        };

        Ok(newly_ready)
    }

    /// Check if there's a cycle in the dependency graph
    pub fn detect_cycle(&self) -> Option<Vec<TaskId>> {
        let mut visited = HashSet::new();
        let mut rec_stack = HashSet::new();
        let mut cycle_path = Vec::new();

        for task_id in self.tasks.keys() {
            if self.detect_cycle_dfs(task_id, &mut visited, &mut rec_stack, &mut cycle_path) {
                return Some(cycle_path.into_iter().map(TaskId::from_str).collect());
            }
        }

        None
    }

    fn detect_cycle_dfs(
        &self,
        task_id: &str,
        visited: &mut HashSet<String>,
        rec_stack: &mut HashSet<String>,
        path: &mut Vec<String>,
    ) -> bool {
        if rec_stack.contains(task_id) {
            path.push(task_id.to_string());
            return true;
        }

        if visited.contains(task_id) {
            return false;
        }

        visited.insert(task_id.to_string());
        rec_stack.insert(task_id.to_string());

        if let Some(dependents) = self.dependents.get(task_id) {
            for dependent in dependents {
                if self.detect_cycle_dfs(dependent, visited, rec_stack, path) {
                    path.push(task_id.to_string());
                    return true;
                }
            }
        }

        rec_stack.remove(task_id);
        false
    }

    /// Get topological order of tasks
    pub fn topological_sort(&self) -> Result<Vec<TaskId>> {
        if let Some(cycle) = self.detect_cycle() {
            return Err(KallaxError::Validation {
                field: "dependencies",
                message: format!("Cycle detected: {:?}", cycle),
            });
        }

        let mut result = Vec::new();
        let mut in_degree = self.in_degree.clone();
        let mut queue: VecDeque<String> = in_degree
            .iter()
            .filter(|(_, &deg)| deg == 0)
            .map(|(id, _)| id.clone())
            .collect();

        while let Some(task_id) = queue.pop_front() {
            result.push(TaskId::from_str(&task_id));

            if let Some(dependents) = self.dependents.get(&task_id) {
                for dependent in dependents {
                    if let Some(deg) = in_degree.get_mut(dependent) {
                        *deg = deg.saturating_sub(1);
                        if *deg == 0 {
                            queue.push_back(dependent.clone());
                        }
                    }
                }
            }
        }

        if result.len() != self.tasks.len() {
            return Err(KallaxError::internal("Topological sort incomplete - possible cycle"));
        }

        Ok(result)
    }

    /// Get number of tasks
    pub fn len(&self) -> usize {
        self.tasks.len()
    }

    /// Check if scheduler is empty
    pub fn is_empty(&self) -> bool {
        self.tasks.is_empty()
    }

    /// Get a task by ID
    pub fn get_task(&self, task_id: &str) -> Option<&Task> {
        self.tasks.get(task_id)
    }
}

impl Default for DagScheduler {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kallax_core::{TaskType, TicketId};

    fn create_task(name: &str, deps: Vec<&str>) -> Task {
        let ticket_id = TicketId::new();
        let mut task = Task::new(ticket_id, TaskType::Analyze, serde_json::json!({}));

        // We need to set a custom ID for testing
        // In real code, we'd use the generated ID
        task
    }

    #[test]
    fn ready_tasks_have_no_dependencies() {
        let mut scheduler = DagScheduler::new();

        let ticket_id = TicketId::new();
        let task1 = Task::new(ticket_id.clone(), TaskType::Analyze, serde_json::json!({}));
        let task2 = Task::new(ticket_id, TaskType::Generate, serde_json::json!({}));

        scheduler.add_task(task1).unwrap();
        scheduler.add_task(task2).unwrap();

        let ready = scheduler.get_ready_tasks();
        assert_eq!(ready.len(), 2); // Both should be ready (no deps)
    }

    #[test]
    fn topological_sort_respects_dependencies() {
        let mut scheduler = DagScheduler::new();

        let ticket_id = TicketId::new();
        let task1 = Task::new(ticket_id.clone(), TaskType::Analyze, serde_json::json!({}));
        let task1_id = task1.id().clone();

        let task2 = Task::new(ticket_id, TaskType::Generate, serde_json::json!({}))
            .with_dependency(task1_id.clone());

        scheduler.add_task(task1).unwrap();
        scheduler.add_task(task2).unwrap();

        let order = scheduler.topological_sort().unwrap();

        // task1 should come before task2
        let task1_pos = order.iter().position(|id| id.as_str() == task1_id.as_str()).unwrap();
        assert_eq!(task1_pos, 0);
    }
}
