import { describe } from 'vitest';

import { blankLines } from './padding.plugin.js';
import { tester } from './rule-tester.js';

describe('padding/blank-lines', () => {
  tester.run('blank-lines', blankLines, {
    valid: [
      { code: 'function f() {\n  const a = 1;\n\n  return a;\n}' },
      { code: 'function f() {\n  return 1;\n}' },
      {
        code: 'function f() {\n  const a = 1;\n  const b = 2;\n\n  g(a, b);\n}',
      },
      {
        code: 'function f(a) {\n  if (!a) {\n    return;\n  }\n  if (a > 1) {\n    throw new Error("x");\n  }\n\n  g(a);\n}',
      },
    ],
    invalid: [
      {
        code: 'function f(a) {\n  if (!a) {\n    return;\n  }\n  g(a);\n}',
        output: 'function f(a) {\n  if (!a) {\n    return;\n  }\n\n  g(a);\n}',
        errors: [{ message: 'Add a blank line after a guard clause.' }],
      },
      {
        code: 'function f() { g(); return 1; }',
        output: 'function f() { g();\n\n return 1; }',
        errors: [{ message: 'Add a blank line before return.' }],
      },
      {
        code: 'function f() {\n  g();\n  return 1;\n}',
        output: 'function f() {\n  g();\n\n  return 1;\n}',
        errors: [{ message: 'Add a blank line before return.' }],
      },
      {
        code: 'function f() {\n  const a = 1;\n  g(a);\n}',
        output: 'function f() {\n  const a = 1;\n\n  g(a);\n}',
        errors: [{ message: 'Add a blank line after variable declarations.' }],
      },
    ],
  });
});
