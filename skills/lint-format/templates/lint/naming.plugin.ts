import type { Rule } from './rule-tester.js';

type RuleContext = Parameters<Extract<Rule, { create: unknown }>['create']>[0];
type EnumDeclaration = Parameters<
  NonNullable<
    ReturnType<
      Extract<Rule, { create: unknown }>['create']
    >['TSEnumDeclaration']
  >
>[0];
type EnumMember = EnumDeclaration['body']['members'][number];

const PASCAL_CASE = /^[A-Z][a-zA-Z0-9]*$/u;
const DOTTED_KEYS = /^[a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+$/u;
const DOTTED_KEY_ENUMS = new Set(['ErrorCode']);
const UPPER_SNAKE_CASE = /^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*$/u;

function checkMemberName(context: RuleContext, member: EnumMember): void {
  if (
    member.id.type !== 'Identifier' ||
    UPPER_SNAKE_CASE.test(member.id.name)
  ) {
    return;
  }

  context.report({
    message: `Enum member "${member.id.name}" must be UPPER_SNAKE_CASE.`,
    node: member.id,
  });
}

function checkMemberValue(
  context: RuleContext,
  member: EnumMember,
  enumName: string,
): void {
  const value = member.initializer;

  if (value?.type !== 'Literal' || typeof value.value !== 'string') {
    return;
  }

  const isDotted = DOTTED_KEY_ENUMS.has(enumName);

  if ((isDotted ? DOTTED_KEYS : UPPER_SNAKE_CASE).test(value.value)) {
    return;
  }

  context.report({
    message: `Enum value "${value.value}" must be ${isDotted ? 'a dotted lowerCamel key' : 'UPPER_SNAKE_CASE'}.`,
    node: value,
  });
}

export const enumStyle: Rule = {
  create(context) {
    return {
      TSEnumDeclaration(node) {
        if (!PASCAL_CASE.test(node.id.name)) {
          context.report({
            message: `Enum name "${node.id.name}" must be PascalCase.`,
            node: node.id,
          });
        }
        for (const member of node.body.members) {
          checkMemberName(context, member);
          checkMemberValue(context, member, node.id.name);
        }
      },
    };
  },
};

export default {
  meta: { name: 'naming' },
  rules: { 'enum-style': enumStyle },
};
