# NEGATIVE_SIGNALS.md — 负向信号触发模式
# Rule 2: 需求含"不要X"/"不是Y"/"排除Z" → 对应 expert score = 0
# 格式: 触发: <patterns>; 排除: <experts>
# patterns 和 excludes 都是逗号分隔

#模式1: 后端否定
触发: 不要后端, 别用后端, 前端就能搞定, 只要前端, 后端不用管, 不要backend, 别用backend; 排除: backend

# 模式2: 前端否定
触发: 不要前端, 别用前端, 后端做就行, 只要后端, 前端不用管, 不要frontend;排除: frontend

# 模式3: 安全否定
触发: 不是安全, 跟安全无关, 无安全风险, 安全不用管, 不涉及安全, OWASP不相关, 不要security; 排除: security

# 模式4: 架构否定
触发: 不是架构, 跟架构无关, 架构不用管, 不需要架构设计; 排除: architect

# 模式5: UX否定
触发: 不是体验, 跟体验无关, 体验不用管, 无用户体验问题; 排除: ux

# 模式6: 产品/PM否定
触发: 不是需求, 跟需求无关, 不是功能, 跟功能无关, PM不用管, 不涉及排期; 排除: product, pm