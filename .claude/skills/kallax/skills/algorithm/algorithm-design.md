# 算法设计技能

## 技能定义
算法设计和优化能力，用于解决复杂计算问题。

## 适用场景
- 数据结构选择
- 算法复杂度优化
- 特定问题求解

## 执行流程

### 1. 问题分析
- 输入/输出规格
- 约束条件
- 性能要求

### 2. 算法选择
- 暴力解法
- 优化思路
- 最优方案

### 3. 复杂度分析
- 时间复杂度
- 空间复杂度
- 权衡决策

### 4. 实现验证
- 伪代码
- 边界测试
- 性能测试

## 输出格式
```markdown
## 算法设计方案

### 问题描述
[问题定义]

### 约束条件
- 数据规模: N <= 10^6
- 时间限制: 1s
- 空间限制: 256MB

### 解法分析

#### 方案1: 暴力解法
- 思路: [描述]
- 时间: O(N^2)
- 空间: O(1)
- 评估: 超时

#### 方案2: 优化解法
- 思路: [描述]
- 时间: O(N log N)
- 空间: O(N)
- 评估: 可行

### 推荐方案

```python
def solution(data):
    # 核心算法实现
    pass
```

### 复杂度分析
- 时间: O(N log N)
  - 排序: O(N log N)
  - 遍历: O(N)
- 空间: O(N)
  - 辅助数组: O(N)

### 测试用例
| 输入 | 预期输出 | 说明 |
|------|----------|------|
| [1,2,3] | 6 | 正常 |
| [] | 0 | 边界 |
| [-1,-2] | -3 | 负数 |
```

## 常用算法模板

### 二分查找
```python
def binary_search(arr, target):
    left, right = 0, len(arr) - 1
    while left <= right:
        mid = (left + right) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
    return -1
```

### 动态规划框架
```python
def dp_template():
    # 1. 定义状态
    # dp[i] = ...
    
    # 2. 初始化
    dp[0] = base_case
    
    # 3. 状态转移
    for i in range(1, n):
        dp[i] = f(dp[i-1], ...)
    
    # 4. 返回结果
    return dp[n-1]
```

### 图遍历 (BFS/DFS)
```python
from collections import deque

def bfs(graph, start):
    visited = set([start])
    queue = deque([start])
    while queue:
        node = queue.popleft()
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
```

## 复杂度速查

| 复杂度 | 规模限制 | 典型算法 |
|--------|----------|----------|
| O(1) | 任意 | 哈希查找 |
| O(log N) | 任意 | 二分查找 |
| O(N) | 10^8 | 线性扫描 |
| O(N log N) | 10^6 | 排序、堆 |
| O(N^2) | 10^4 | 双重循环 |
| O(N^3) | 500 | Floyd |
| O(2^N) | 20 | 子集枚举 |
| O(N!) | 10 | 全排列 |
