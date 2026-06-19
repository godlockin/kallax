# KALLAX JavaScript SDK (EXPERIMENTAL)

> **Status**: EXPERIMENTAL (跟 v2.7.4 D6 联合, 跟 4 团队 review 报告 HIGH 联合)
> **Issue**: 跟 v2.7.4 4 团队 review 报告 联合, 跟"不埋坑" 5 原则 联合
> **Reason**: \`package.json\` references \`dist/index.js\` which doesn't exist. SDK was never built. 跟 5 原则 联合, 0 标 experimental = "incomplete SDK 假动作".

## What works
- \`package.json\` declares \`@kallax/sdk\` v1.0.0
- \`tsconfig.json\` configured
- This README exists

## What doesn't work
- No \`src/index.ts\` (跟 v2.7.4 4 团队 review 报告 联合)
- No \`dist/index.js\` (package.json references it)
- The example API (\`kallax.createTicket()\`, etc.) is not implemented

## To make this non-experimental
- Add \`src/index.ts\` with \`KallaxClient\` class
- Implement the API methods from this README
- Set up build to generate \`dist/\`
- Test end-to-end

## Until then
Do not use this SDK. Use the Node.js CLI (\`kallax\` binary) instead.
