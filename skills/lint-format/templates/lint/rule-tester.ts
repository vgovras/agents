import { RuleTester } from 'oxlint/plugins-dev';
import { describe, it } from 'vitest';

export type Rule = Parameters<RuleTester['run']>[1];

RuleTester.describe = (name, fn) => {
  describe(name, fn);
};
RuleTester.it = (name, fn) => {
  it(name, fn);
};

export const tester = new RuleTester({
  languageOptions: { parserOptions: { lang: 'ts' } },
});
