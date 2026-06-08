#!/usr/bin/env python3
"""
expand-extended-triggers.py — EPIC-030
Expand 90 extended expert triggers from 5-6 words to 24-30 words.
Uses domain-specific vocabulary expansion to supplement jieba segmentation.
No verbatim test cases.
"""
import re
import sys

# 30 test cases to avoid verbatim
TEST_CASES = {
    "接口慢怎么优化", "数据库索引怎么加", "页面渲染卡顿", "组件状态管理混乱",
    "用户旅程卡在哪一步", "按钮点击率低", "这个需求值不值得做",
    "微服务架构选型", "缓存击穿怎么办", "N+1查询怎么查",
    "前端重渲染优化", "SQL慢查询优化", "接口超时处理",
    "用户留存率下降", "怎么加监控告警", "锁竞争怎么解决",
    "连接池耗尽", "内存泄漏怎么查", "GC频繁怎么调",
    "死锁怎么排查", "分布式事务一致性", "灰度发布方案",
    "AB test怎么设计", "代码重构节奏", "技术债评估",
    "安全漏洞扫描", "权限控制设计", "数据加密方案",
    "压测怎么做", "性能瓶颈定位"
}

# Domain-specific vocabulary for expansion
DOMAIN_VOCAB = {
    "security": [
        "渗透测试", "漏洞挖掘", "威胁建模", "红队", "蓝队", "应急响应", "安全运营",
        "漏洞修复", "安全架构", "合规审计", "SOC2", "GDPR", "数据保护", "身份认证",
        "访问控制", "加密", "密钥管理", "威胁情报", "攻击面", "入侵检测", "WAF",
        "防火墙", "安全编码", "代码审计", "SDL", "DevSecOps", "零信任", "微分段",
        "安全监控", "日志分析", "取证", "数字取证", "隐私保护", "GDPR合规", "CCPA"
    ],
    "tech": [
        "微服务", "分布式", "云原生", "容器化", "K8s", "Docker", "服务网格", "API网关",
        "负载均衡", "CDN", "缓存", "消息队列", "异步", "事件驱动", "数据库", "SQL优化",
        "NoSQL", "MongoDB", "PostgreSQL", "MySQL", "Redis", "缓存策略", "主从复制",
        "读写分离", "分库分表", "索引优化", "查询优化", "性能分析", "瓶颈定位",
        "监控", "告警", "日志", "链路追踪", "可观测性", "SRE", "DevOps", "CI/CD",
        "自动化", "配置管理", "IaC", "Terraform", "Ansible", "熔断", "限流", "降级"
    ],
    "ai": [
        "机器学习", "深度学习", "神经网络", "NLP", "CV", "计算机视觉", "推荐系统",
        "协同过滤", "内容推荐", "个性化", "模型训练", "模型部署", "MLOps", "特征工程",
        "数据预处理", "模型评估", "A/B测试", "在线学习", "增量学习", "迁移学习",
        "强化学习", "对抗学习", "生成模型", "LLM", "大模型", "RAG", "向量数据库",
        "Prompt工程", "知识蒸馏", "模型压缩", "模型量化", "GPU", "TPU", "分布式训练",
        "数据增强", "超参数调优", "AutoML", "模型融合", "集成学习", "随机森林", "XGBoost"
    ],
    "design": [
        "UI设计", "UX设计", "用户体验", "交互设计", "原型设计", "用户研究", "可用性测试",
        "信息架构", "导航设计", "视觉设计", "品牌设计", "UI视觉", "图标设计", "动效设计",
        "设计系统", "组件库", "设计令牌", "设计协作", "设计工程", "Figma", "Sketch",
        "Adobe XD", "设计评审", "设计规范", "设计原则", "响应式设计", "移动端设计",
        "Web设计", "App设计", "小程序设计", "深色模式", "无障碍设计", "国际化"
    ],
    "business": [
        "商业模式", "商业画布", "收入模型", "定价策略", "单元经济", "增长策略",
        "用户增长", "留存提升", "转化优化", "市场分析", "竞品分析", "差异化策略",
        "市场定位", "品牌定位", "品牌战略", "品牌故事", "品牌矩阵", "增长黑客",
        "病毒增长", "裂变", "KPI", "OKR", "财务建模", "预算编制", "投资分析",
        "现金流", "ROI", "LTV", "CAC", "ARPU", "GMV", "DAU", "MAU", "留存率"
    ],
    "consulting": [
        "战略咨询", "企业战略", "市场进入", "并购咨询", "战略规划", "组织变革",
        "流程优化", "精益生产", "效率提升", "敏捷转型", "Scrum", "看板", "敏捷教练",
        "变革管理", "领导力", "高管教练", "团队建设", "组织设计", "架构调整",
        "岗位设计", "职级体系", "流程再造", "浪费消除", "持续改进", "精益", "六西格玛"
    ],
    "hr": [
        "招聘策略", "雇主品牌", "面试设计", "人才mapping", "绩效管理", "KPI", "OKR",
        "评估机制", "薪酬设计", "福利方案", "股权激励", "员工关系", "离职管理",
        "企业文化", "培训体系", "人才发展", "导师制度", "继任计划", "学习发展",
        "人才评估", "能力模型", "岗位胜任力", "360评估", "九宫格", "人才盘点"
    ],
    "knowledge": [
        "知识图谱", "本体设计", "语义搜索", "知识推理", "知识工程", "文档工程",
        "技术写作", "API文档", "文档平台", "内容管理", "信息架构", "导航设计",
        "分类法", "元数据", "搜索引擎", "全文检索", "排序算法", "查询优化",
        "Elasticsearch", "Solr", "知识管理", "知识沉淀", "知识共享", "知识复用"
    ],
    "marketing": [
        "内容策略", "内容运营", "文案撰写", "内容分发", "数字营销", "增长营销",
        "SEO优化", "网站优化", "外链建设", "技术SEO", "营销分析", "归因模型",
        "转化追踪", "ROI优化", "用户获取", "用户激活", "用户留存", "用户裂变",
        "病毒营销", "活动策划", "活动运营", "线下活动", "KOL合作", "媒体投放"
    ],
    "ops": [
        "运营体系", "流程自动化", "跨部门协调", "活动策划", "活动运营", "线下活动",
        "项目管理", "客服体系", "服务质量", "客服培训", "投诉处理", "供应链管理",
        "库存优化", "物流协调", "供应商管理", "质量体系", "质量改进", "六西格玛",
        "质量评估", "看板", "流程可视化", "持续改进", "PMP", "敏捷项目管理"
    ],
    "pr": [
        "媒体关系", "新闻发布", "舆情管理", "危机公关", "危机处理", "声誉管理",
        "利益相关方", "品牌传播", "媒体投放", "社交运营", "KOL合作", "内部沟通",
        "员工传播", "文化宣传", "变革沟通", "公关策略", "媒体策略", "舆情监控"
    ],
    "training": [
        "培训体系", "课程设计", "培训开发", "学习体验", "培训评估", "导师制度",
        "导师赋能", "辅导技巧", "mentee发展", "在线学习", "LMS平台", "e-Learning",
        "微学习", "技能评估", "能力模型", "认证体系", "岗位胜任力", "游戏化设计",
        "激励机制", "学习动力", "行为设计", "学习路径", "课程开发", "培训交付"
    ]
}

def is_test_case_verbatim(word):
    """Check if a word matches a test case verbatim."""
    return word in TEST_CASES

def get_expanded_trigger(expert_id, name_cn, role, domain, description, existing_trigger):
    """
    Build an expanded trigger from expert metadata.
    Returns list of trigger words (24-30).
    """
    existing_words = [w.strip() for w in existing_trigger.split('|') if w.strip()]

    # Build corpus from all fields
    corpus = f"{name_cn} {role} {domain} {description} {' '.join(existing_words)}"

    try:
        import jieba
        import jieba.analyse

        # Get top keywords from description
        top_kw = jieba.analyse.extract_tags(description, topK=50)

        # Segment corpus
        all_words = []
        for word in jieba.cut(corpus, cut_all=False):
            word = word.strip()
            if word and len(word) >= 2:
                all_words.append(word)

        # Deduplicate
        seen = set()
        unique_words = []
        for w in all_words:
            wl = w.lower()
            if wl not in seen:
                seen.add(wl)
                unique_words.append(w)

        # Combine from multiple sources
        combined = []
        seen2 = set()

        # Priority 1: existing trigger words (highest signal)
        for w in existing_words:
            ws = w.strip()
            if ws and not is_test_case_verbatim(ws):
                wl = ws.lower()
                if wl not in seen2:
                    seen2.add(wl)
                    combined.append(ws)

        # Priority 2: top keywords from description
        for w in top_kw:
            ws = w.strip()
            if ws and not is_test_case_verbatim(ws):
                wl = ws.lower()
                if wl not in seen2:
                    seen2.add(wl)
                    combined.append(ws)

        # Priority 3: unique segmentations
        for w in unique_words:
            ws = w.strip()
            if ws and not is_test_case_verbatim(ws):
                wl = ws.lower()
                if wl not in seen2:
                    seen2.add(wl)
                    combined.append(ws)

        # Priority 4: domain vocabulary expansion
        domain_words = DOMAIN_VOCAB.get(domain, [])
        for w in domain_words:
            ws = w.strip()
            if ws and not is_test_case_verbatim(ws):
                wl = ws.lower()
                if wl not in seen2:
                    seen2.add(wl)
                    combined.append(ws)

        # Filter: short words (2-6 chars Chinese, or short English)
        def is_acceptable_word(w):
            has_chinese = any('一' <= c <= '鿿' for c in w)
            has_letter = any(c.isalpha() for c in w)
            if has_chinese:
                return 2 <= len(w) <= 6
            elif has_letter:
                return len(w) <= 30
            return False

        filtered = [w for w in combined if is_acceptable_word(w)]

        # Ensure at least 24 words by reusing domain words if needed
        if len(filtered) < 24:
            for w in domain_words:
                ws = w.strip()
                if ws and not is_test_case_verbatim(ws) and len(filtered) < 30:
                    wl = ws.lower()
                    if wl not in seen2:
                        seen2.add(wl)
                        filtered.append(ws)

        return filtered[:30]

    except ImportError:
        return existing_words[:24]

def main():
    index_path = "/Users/chenchen/working/sourcecode/tools/dev-tools/kallax/.kallax/worktrees/performer-EPIC-024-B/.kallax/experts/extended/INDEX.md"

    with open(index_path, 'r') as f:
        content = f.read()

    blocks = content.split('---\n')

    total = 0
    expanded = 0
    under_threshold = []

    for i, block in enumerate(blocks):
        if not re.search(r'^id: eket\.extended\.', block, re.MULTILINE):
            continue

        id_match = re.search(r'^id:\s*(.+?)$', block, re.MULTILINE)
        name_cn_match = re.search(r'^name_cn:\s*(.+?)$', block, re.MULTILINE)
        role_match = re.search(r'^role:\s*(.+?)$', block, re.MULTILINE)
        domain_match = re.search(r'^domain:\s*(.+?)$', block, re.MULTILINE)
        desc_match = re.search(r'^description:\s*(.+?)$', block, re.MULTILINE)
        trigger_match = re.search(r'^trigger:\s*(.+?)$', block, re.MULTILINE)

        if not all([id_match, name_cn_match, role_match, domain_match, desc_match, trigger_match]):
            continue

        total += 1
        expert_id = id_match.group(1).strip()
        name_cn = name_cn_match.group(1).strip()
        role = role_match.group(1).strip()
        domain = domain_match.group(1).strip()
        description = desc_match.group(1).strip()
        old_trigger = trigger_match.group(1).strip()
        old_words = [w.strip() for w in old_trigger.split('|') if w.strip()]
        old_count = len(old_words)

        new_words = get_expanded_trigger(expert_id, name_cn, role, domain, description, old_trigger)
        new_count = len(new_words)

        new_trigger = '|'.join(new_words)

        block_new = re.sub(
            r'^trigger:\s*.+$',
            f'trigger: {new_trigger}',
            block,
            count=1,
            flags=re.MULTILINE
        )

        blocks[i] = block_new

        if new_count >= 24:
            expanded += 1
            print(f"[{total}] {expert_id}: {old_count}→{new_count} OK", file=sys.stderr)
        else:
            under_threshold.append((total, expert_id, new_count))
            print(f"[{total}] {expert_id}: {old_count}→{new_count} UNDER", file=sys.stderr)

    new_content = '---\n'.join(blocks)
    with open(index_path, 'w') as f:
        f.write(new_content)

    print(f"\nTotal: {total}, Expanded (24+): {expanded}, Under threshold: {len(under_threshold)}", file=sys.stderr)

    return 0

if __name__ == "__main__":
    sys.exit(main())