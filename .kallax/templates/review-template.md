# PR Review: #{PR-ID}

## 基本信息

- **PR 标题**: 
- **关联 Ticket**: 
- **Performer**: 
- **提交时间**: 

---

## 4-Level Fact-Forcing 验证

### Level 1: 存在性验证

- [ ] 文件存在于 diff

**检查命令**:
```bash
git diff --name-only HEAD~1
```

**结果**:
```
# 粘贴输出
```

---

### Level 2: 实质性验证

- [ ] 真实逻辑，非 stub
- [ ] 无 TODO 占位符在关键路径

**检查内容**:

| 文件 | 行号 | 说明 |
|------|------|------|
| - | - | - |

---

### Level 3: 接线验证

- [ ] import/export 正确
- [ ] 类型兼容

**检查命令**:
```bash
npm run type-check
```

**结果**:
```
# 粘贴输出
```

---

### Level 4: 数据流验证

- [ ] 测试通过
- [ ] 集成测试覆盖

**检查命令**:
```bash
npm test
```

**结果**:
```
# 粘贴完整测试输出
```

---

## 产出验证

```bash
kallax verify:output {TASK-ID}
```

**结果**:
```
# 粘贴输出
```

---

## 反模式检查

- [ ] 无 `any` 类型
- [ ] 无 `@ts-ignore`
- [ ] 无 `expect()`/`unwrap()`
- [ ] 无 `console.log`
- [ ] 无空 catch 块
- [ ] 无 magic number

---

## 文件范围检查

**声明的 file_scope**:
```yaml
includes:
  - 
excludes:
  - 
```

**实际修改**:
```
# git diff --name-only
```

- [ ] 修改仅限于声明范围

---

## 评审意见

### 必须修改

1. 

### 建议修改

1. 

### 优点

1. 

---

## 决策

- [ ] **Approve** - 通过
- [ ] **Request Changes** - 需要修改
- [ ] **Comment** - 仅评论

**评审人**: 
**评审时间**: 
