import type { Rule } from './rule-tester.js';

type RuleCreate = Extract<Rule, { create: unknown }>['create'];
type BinaryVisitor = NonNullable<ReturnType<RuleCreate>['BinaryExpression']>;
type Operand = Parameters<BinaryVisitor>[0]['left'];

const COMPARISON_OPERATORS = new Set(['===', '!==']);
const LITERAL_VALUES = new Set<unknown>([null, true, false]);

function isBannedOperand(node: Operand): boolean {
  if (node.type === 'Identifier') {
    return node.name === 'undefined';
  }

  return node.type === 'Literal' && LITERAL_VALUES.has(node.value);
}

export const noExplicitComparison: Rule = {
  create(context) {
    return {
      BinaryExpression(node) {
        if (!COMPARISON_OPERATORS.has(node.operator)) {
          return;
        }
        if (!isBannedOperand(node.left) && !isBannedOperand(node.right)) {
          return;
        }

        context.report({
          message:
            'Do not compare with undefined, null, true or false; use the value itself, !value or !!value.',
          node,
        });
      },
    };
  },
};

export default {
  meta: { name: 'comparison' },
  rules: { 'no-explicit-comparison': noExplicitComparison },
};
