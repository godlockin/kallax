//! DAG Scheduler implementation
//!
//! Schedules tasks based on dependency graph using topological sort.
//! Uses a BinaryHeap for O(log n) priority-based ready task retrieval.

use kallax_core::{KallaxError, Priority, Result, TaskId};
use std::cmp::Reverse;
use std::collections::BinaryHeap;
use std::collections::{HashMap, HashSet, VecDeque};

pub struct DagScheduler {
    dependents: HashMap<String, HashSet<String>>,
    in_degree: HashMap<String, usize>,
    priorities: HashMap<String, Priority>,
    ready_heap: BinaryHeap<(Priority, Reverse<String>)>,
}

impl DagScheduler {
    pub fn new() -> Self {
        Self {
            dependents: HashMap::new(),
            in_degree: HashMap::new(),
            priorities: HashMap::new(),
            ready_heap: BinaryHeap::new(),
        }
    }

    pub fn add_task(
        &mut self,
        task_id: TaskId,
        dependencies: &[TaskId],
        priority: Priority,
    ) -> Result<()> {
        let id = task_id.as_str().to_string();
        if self.in_degree.contains_key(&id) {
            return Err(KallaxError::AlreadyExists {
                entity_type: "task",
                entity_id: id,
            });
        }
        let dep_count = dependencies.len();
        self.in_degree.insert(id.clone(), dep_count);
        self.priorities.insert(id.clone(), priority);
        for dep in dependencies {
            self.dependents
                .entry(dep.as_str().to_string())
                .or_default()
                .insert(id.clone());
        }
        if dep_count == 0 {
            self.ready_heap.push((priority, Reverse(id)));
        }
        Ok(())
    }

    pub fn get_ready_tasks(&mut self) -> Vec<TaskId> {
        let mut result = Vec::new();
        // EPIC-092 P1-6: 不 pop 消费, 而是先 peek 收集
        // 原: pop 后若 in_degree > 0 则 task 从 heap 永远消失 (任务丢失)
        // 修: 用 std::mem::take 替换 heap, 重建保留 ready + 还原非 ready
        let old_heap = std::mem::take(&mut self.ready_heap);
        let mut ready: Vec<String> = Vec::new();
        for (priority, Reverse(task_id)) in old_heap.into_iter() {
            if self.in_degree.get(&task_id).is_some_and(|&d| d == 0) {
                ready.push(task_id);
            } else {
                // EPIC-092 治根: 非 ready task 放回 heap (防丢失)
                let p = self.priorities.get(&task_id).copied().unwrap_or(priority);
                self.ready_heap.push((p, Reverse(task_id)));
            }
        }
        // EPIC-101: sort by priority desc (Critical first) — heap Reverse gives asc, 显式反序
        ready.sort_by(|a, b| {
            let pa = self.priorities.get(a).copied().unwrap_or(Priority::Normal);
            let pb = self.priorities.get(b).copied().unwrap_or(Priority::Normal);
            pb.cmp(&pa) // desc
        });
        for id in &ready {
            result.push(TaskId::from_str(id));
        }
        result
    }

    pub fn complete_task(&mut self, task_id: &str) -> Result<Vec<TaskId>> {
        if !self.in_degree.contains_key(task_id) {
            return Err(KallaxError::not_found("task", task_id));
        }
        let mut newly_ready = Vec::new();
        if let Some(dependents) = self.dependents.get(task_id) {
            for dep_id in dependents {
                if let Some(in_deg) = self.in_degree.get_mut(dep_id) {
                    *in_deg = in_deg.saturating_sub(1);
                    if *in_deg == 0 {
                        let pid = self
                            .priorities
                            .get(dep_id)
                            .copied()
                            .unwrap_or(Priority::Normal);
                        self.ready_heap.push((pid, Reverse(dep_id.clone())));
                        newly_ready.push(TaskId::from_str(dep_id));
                    }
                }
            }
        }
        Ok(newly_ready)
    }

    pub fn detect_cycle(&self) -> Option<Vec<TaskId>> {
        let mut visited = HashSet::new();
        let mut rec_stack = HashSet::new();
        let mut path = Vec::new();
        for task_id in self.in_degree.keys() {
            if self.detect_cycle_dfs(task_id, &mut visited, &mut rec_stack, &mut path) {
                return Some(path.into_iter().map(TaskId::from_str).collect());
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

    pub fn topological_sort(&self) -> Result<Vec<TaskId>> {
        if let Some(cycle) = self.detect_cycle() {
            return Err(KallaxError::Validation {
                field: "dependencies",
                message: format!("Cycle: {:?}", cycle),
            });
        }
        let mut result = Vec::new();
        let mut in_deg = self.in_degree.clone();
        let mut queue: VecDeque<String> = in_deg
            .iter()
            .filter(|(_, &d)| d == 0)
            .map(|(id, _)| id.clone())
            .collect();
        while let Some(task_id) = queue.pop_front() {
            result.push(TaskId::from_str(&task_id));
            if let Some(dependents) = self.dependents.get(&task_id) {
                for dep in dependents {
                    if let Some(d) = in_deg.get_mut(dep) {
                        *d = d.saturating_sub(1);
                        if *d == 0 {
                            queue.push_back(dep.clone());
                        }
                    }
                }
            }
        }
        if result.len() != self.in_degree.len() {
            return Err(KallaxError::internal("Topo sort incomplete"));
        }
        Ok(result)
    }

    pub fn critical_path(&self) -> Vec<TaskId> {
        if self.is_empty() {
            return Vec::new();
        }
        let mut topo = Vec::new();
        let mut in_deg = self.in_degree.clone();
        let mut queue: VecDeque<String> = in_deg
            .iter()
            .filter(|(_, &d)| d == 0)
            .map(|(id, _)| id.clone())
            .collect();
        while let Some(task_id) = queue.pop_front() {
            topo.push(task_id.clone());
            if let Some(deps) = self.dependents.get(&task_id) {
                for dep in deps {
                    if let Some(d) = in_deg.get_mut(dep) {
                        *d = d.saturating_sub(1);
                        if *d == 0 {
                            queue.push_back(dep.clone());
                        }
                    }
                }
            }
        }
        if topo.len() != self.in_degree.len() {
            return Vec::new();
        }
        let mut dist: HashMap<String, usize> = HashMap::new();
        let mut prev: HashMap<String, String> = HashMap::new();
        for id in self.in_degree.keys() {
            dist.insert(id.clone(), 1);
        }
        for task_id in &topo {
            let cur = dist.get(task_id).copied().unwrap_or(1);
            if let Some(deps) = self.dependents.get(task_id) {
                for dep in deps {
                    let new = cur + 1;
                    if new > dist.get(dep).copied().unwrap_or(0) {
                        dist.insert(dep.clone(), new);
                        prev.insert(dep.clone(), task_id.clone());
                    }
                }
            }
        }
        if let Some(end) = dist
            .iter()
            .max_by_key(|(_, &d)| d)
            .map(|(id, _)| id.clone())
        {
            let mut path = Vec::new();
            let mut current = Some(end);
            while let Some(id) = current {
                path.push(TaskId::from_str(&id));
                current = prev.get(&id).cloned();
            }
            path.reverse();
            path
        } else {
            Vec::new()
        }
    }

    pub fn parallel_paths(&self) -> usize {
        let critical = self.critical_path();
        if critical.is_empty() {
            return 0;
        }
        let cs: HashSet<String> = critical.iter().map(|id| id.as_str().to_string()).collect();
        let mut deps_map: HashMap<String, HashSet<String>> = HashMap::new();
        for (dep, dependents) in &self.dependents {
            for d in dependents {
                deps_map.entry(d.clone()).or_default().insert(dep.clone());
            }
        }
        self.in_degree
            .keys()
            .filter(|id| !cs.contains(*id))
            .filter(|id| {
                if let Some(deps) = deps_map.get(*id) {
                    deps.iter().all(|d| cs.contains(d))
                } else {
                    true
                }
            })
            .count()
    }

    pub fn len(&self) -> usize {
        self.in_degree.len()
    }
    pub fn is_empty(&self) -> bool {
        self.in_degree.is_empty()
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

    #[test]
    fn ready_no_deps() {
        let mut s = DagScheduler::new();
        s.add_task(TaskId::from_str("A"), &[], Priority::Normal)
            .unwrap();
        s.add_task(TaskId::from_str("B"), &[], Priority::Normal)
            .unwrap();
        assert_eq!(s.get_ready_tasks().len(), 2);
    }
    // EPIC-101: 验证 heap 实际行为 — high priority first
    // (BinaryHeap max-heap by default + Reverse wrapper = min-heap, 但 Priority enum 高 = 大)
    // 实际: C (Critical) > H (High) > L (Low), 跟原测试期望一致
    #[test]
    fn priority_order() {
        let mut s = DagScheduler::new();
        s.add_task(TaskId::from_str("L"), &[], Priority::Low)
            .unwrap();
        s.add_task(TaskId::from_str("H"), &[], Priority::High)
            .unwrap();
        s.add_task(TaskId::from_str("C"), &[], Priority::Critical)
            .unwrap();
        let r = s.get_ready_tasks();
        assert_eq!(r[0].as_str(), "C");
        assert_eq!(r[1].as_str(), "H");
    }
    #[test]
    fn critical_diamond() {
        let mut s = DagScheduler::new();
        let a = TaskId::from_str("A");
        let b = TaskId::from_str("B");
        let c = TaskId::from_str("C");
        let d = TaskId::from_str("D");
        s.add_task(a.clone(), &[], Priority::Normal).unwrap();
        s.add_task(b.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        s.add_task(c.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        s.add_task(d.clone(), &[b.clone(), c.clone()], Priority::Normal)
            .unwrap();
        let p = s.critical_path();
        assert_eq!(p.len(), 3);
        assert_eq!(p[0].as_str(), "A");
        assert_eq!(p[2].as_str(), "D");
    }
    #[test]
    fn parallel_count() {
        let mut s = DagScheduler::new();
        let a = TaskId::from_str("A");
        let b = TaskId::from_str("B");
        let c = TaskId::from_str("C");
        let d = TaskId::from_str("D");
        s.add_task(a.clone(), &[], Priority::Normal).unwrap();
        s.add_task(b.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        s.add_task(c.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        s.add_task(d.clone(), &[b.clone(), c.clone()], Priority::Normal)
            .unwrap();
        assert_eq!(s.parallel_paths(), 1);
    }
    #[test]
    fn chain_no_par() {
        let mut s = DagScheduler::new();
        let a = TaskId::from_str("A");
        let b = TaskId::from_str("B");
        let c = TaskId::from_str("C");
        s.add_task(a.clone(), &[], Priority::Normal).unwrap();
        s.add_task(b.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        s.add_task(c.clone(), &[b.clone()], Priority::Normal)
            .unwrap();
        assert_eq!(s.critical_path().len(), 3);
        assert_eq!(s.parallel_paths(), 0);
    }
    #[test]
    fn complete_unblock() {
        let mut s = DagScheduler::new();
        let a = TaskId::from_str("A");
        let b = TaskId::from_str("B");
        s.add_task(a.clone(), &[], Priority::Normal).unwrap();
        s.add_task(b.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        assert_eq!(s.get_ready_tasks().len(), 1);
        let u = s.complete_task("A").unwrap();
        assert_eq!(u.len(), 1);
        assert_eq!(u[0].as_str(), "B");
    }
    #[test]
    fn topo_sort() {
        let mut s = DagScheduler::new();
        let a = TaskId::from_str("A");
        let b = TaskId::from_str("B");
        s.add_task(a.clone(), &[], Priority::Normal).unwrap();
        s.add_task(b.clone(), &[a.clone()], Priority::Normal)
            .unwrap();
        let o = s.topological_sort().unwrap();
        assert!(
            o.iter().position(|x| x.as_str() == "A") < o.iter().position(|x| x.as_str() == "B")
        );
    }
}
