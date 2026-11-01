import { describe } from 'vitest';

import { enumStyle } from './naming.plugin.js';
import { tester } from './rule-tester.js';

describe('naming/enum-style', () => {
  tester.run('enum-style', enumStyle, {
    valid: [
      { code: "enum WordStatus { NEW = 'NEW', NOT_LEARNED = 'NOT_LEARNED' }" },
      { code: 'enum ErrorCode { TOO_LONG = 102 }' },
      {
        code: "enum ErrorCode { TERM_EXISTS = 'vocabulary.word.termExists' }",
      },
    ],
    invalid: [
      {
        code: "enum ErrorCode { TERM_EXISTS = 'TERM_EXISTS' }",
        errors: [
          {
            message:
              'Enum value "TERM_EXISTS" must be a dotted lowerCamel key.',
          },
        ],
      },
      {
        code: "enum WordStatus { NEW = 'vocabulary.word.new' }",
        errors: [
          {
            message:
              'Enum value "vocabulary.word.new" must be UPPER_SNAKE_CASE.',
          },
        ],
      },
      {
        code: "enum wordStatus { NEW = 'NEW' }",
        errors: [{ message: 'Enum name "wordStatus" must be PascalCase.' }],
      },
      {
        code: "enum WordStatus { New = 'NEW' }",
        errors: [{ message: 'Enum member "New" must be UPPER_SNAKE_CASE.' }],
      },
      {
        code: "enum WordStatus { NEW = 'new' }",
        errors: [{ message: 'Enum value "new" must be UPPER_SNAKE_CASE.' }],
      },
    ],
  });
});
