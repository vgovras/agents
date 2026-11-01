import { describe } from 'vitest';

import { noExplicitComparison } from './comparison.plugin.js';
import { tester } from './rule-tester.js';

const message =
  'Do not compare with undefined, null, true or false; use the value itself, !value or !!value.';

describe('comparison/no-explicit-comparison', () => {
  tester.run('no-explicit-comparison', noExplicitComparison, {
    valid: [
      { code: 'if (!value) {}' },
      { code: 'const ok = !!value;' },
      { code: "if (typeof value === 'string') {}" },
      { code: 'if (a === b) {}' },
    ],
    invalid: [
      { code: 'if (a === undefined) {}', errors: [{ message }] },
      { code: 'if (a !== null) {}', errors: [{ message }] },
      { code: 'if (true === a) {}', errors: [{ message }] },
      { code: 'if (a !== false) {}', errors: [{ message }] },
    ],
  });
});
