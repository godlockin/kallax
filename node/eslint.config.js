import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // KALLAX P1: Strict type safety
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-unsafe-member-access': 'error',
      '@typescript-eslint/no-unsafe-call': 'error',
      '@typescript-eslint/no-unsafe-return': 'error',
      '@typescript-eslint/no-unsafe-argument': 'error',

      // Prohibit @ts-ignore
      '@typescript-eslint/ban-ts-comment': ['error', {
        'ts-ignore': true,
        'ts-expect-error': 'allow-with-description',
      }],

      // Prohibit console.log
      'no-console': 'error',

      // Prohibit empty catch blocks
      'no-empty': ['error', { allowEmptyCatch: false }],
      '@typescript-eslint/no-empty-function': 'error',

      // Require explicit return types
      '@typescript-eslint/explicit-function-return-type': 'error',
      '@typescript-eslint/explicit-module-boundary-types': 'error',

      // No unused vars
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],

      // Prefer nullish coalescing
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',

      // Strict boolean expressions
      '@typescript-eslint/strict-boolean-expressions': 'error',

      // No floating promises
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
    },
  },
  {
    ignores: ['dist/**', 'node_modules/**', '*.config.js'],
  }
);
