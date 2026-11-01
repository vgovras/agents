import type { Rule } from './rule-tester.js';

type RuleCreate = Extract<Rule, { create: unknown }>['create'];
type BlockVisitor = NonNullable<ReturnType<RuleCreate>['BlockStatement']>;
type Statement = Parameters<BlockVisitor>[0]['body'][number];

const BLANK_LINE = /\n[^\S\n]*\n/u;
const EXIT_TYPES = new Set([
  'ReturnStatement',
  'ThrowStatement',
  'ContinueStatement',
]);

function isGuard(node: Statement): boolean {
  if (node.type !== 'IfStatement' || node.alternate) {
    return false;
  }

  const { consequent } = node;
  const last =
    consequent.type === 'BlockStatement' ? consequent.body.at(-1) : consequent;

  return !!last && EXIT_TYPES.has(last.type);
}

function findViolation(
  previous: Statement,
  current: Statement,
): string | undefined {
  if (current.type === 'ReturnStatement') {
    return 'Add a blank line before return.';
  }
  if (previous.type === 'VariableDeclaration') {
    return current.type === 'VariableDeclaration'
      ? undefined
      : 'Add a blank line after variable declarations.';
  }

  return isGuard(previous) && !isGuard(current)
    ? 'Add a blank line after a guard clause.'
    : undefined;
}

export const blankLines: Rule = {
  meta: { fixable: 'whitespace' },
  create(context) {
    const { text } = context.sourceCode;

    return {
      BlockStatement(node) {
        for (const [index, current] of node.body.entries()) {
          const previous = node.body[index - 1];

          if (!previous) {
            continue;
          }

          const gap = text.slice(previous.range[1], current.range[0]);

          if (BLANK_LINE.test(gap)) {
            continue;
          }

          const message = findViolation(previous, current);

          if (!message) {
            continue;
          }

          context.report({
            message,
            node: current,
            fix: (fixer) => {
              const newline = gap.indexOf('\n');
              const at = previous.range[1] + (newline === -1 ? 0 : newline);

              return fixer.insertTextAfterRange(
                [at, at],
                newline === -1 ? '\n\n' : '\n',
              );
            },
          });
        }
      },
    };
  },
};

export default {
  meta: { name: 'padding' },
  rules: { 'blank-lines': blankLines },
};
