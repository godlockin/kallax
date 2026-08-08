// KALLAX commitlint config (EPIC-221)
// 强制 DCO Sign-off-by trailer (跟 .github/dco.yml 1:1)
// 强制 Conventional Commits 格式 (跟 CONTRIBUTING.md 1:1)
module.exports = {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        // 自定义规则: DCO Sign-off-by trailer 必填
        'dco-signoff': (parsed, when) => {
          if (when === 'never') return [true];
          const signoffRegex = /^Signed-off-by:\s.+\s<.+@.+>$/m;
          return [signoffRegex.test(parsed.raw), 'commit 必须含 Signed-off-by trailer (DCO)'];
        },
      },
    },
  ],
  rules: {
    'dco-signoff': [2, 'always'],
    // header 长度 ≤ 100 (跟 Rule 8 Rule-of-500 联合, 单 commit ≤ 100 字 header)
    'header-max-length': [2, 'always', 100],
    // type 必填 (feat/fix/docs/refactor/test/chore/ci/release/style/perf)
    'type-enum': [2, 'always', ['feat', 'fix', 'docs', 'refactor', 'test', 'chore', 'ci', 'release', 'style', 'perf']],
  },
};