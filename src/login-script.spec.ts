import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  DEFAULT_ORIGINS,
  buildLoginScript,
  isAllowedOauthHostname,
  parseOrigins,
} from './login-script';

const origins = parseOrigins(DEFAULT_ORIGINS);

describe('parseOrigins', () => {
  it('splits and trims hostnames', () => {
    assert.deepEqual(parseOrigins('a.example.com, localhost:4321 '), [
      'a.example.com',
      'localhost:4321',
    ]);
  });

  it('rejects empty ORIGINS', () => {
    assert.throws(() => parseOrigins(''), /ORIGINS/);
    assert.throws(() => parseOrigins(undefined), /ORIGINS/);
  });

  it('parses the locked default list', () => {
    assert.deepEqual(origins, [
      '*.singletonsd.com',
      '*.patoperpetua.com',
      'singletonsd.com',
      'patoperpetua.com',
      'localhost:4321',
    ]);
  });
});

describe('isAllowedOauthHostname', () => {
  it('allows nested subdomains under *.singletonsd.com', () => {
    assert.equal(isAllowedOauthHostname('www.singletonsd.com', origins), true);
    assert.equal(isAllowedOauthHostname('plattform-kit.poc.singletonsd.com', origins), true);
    assert.equal(isAllowedOauthHostname('inkads.poc.singletonsd.com', origins), true);
  });

  it('allows nested subdomains under *.patoperpetua.com', () => {
    assert.equal(isAllowedOauthHostname('www.patoperpetua.com', origins), true);
    assert.equal(isAllowedOauthHostname('app.poc.patoperpetua.com', origins), true);
  });

  it('allows apex hosts only when listed explicitly', () => {
    assert.equal(isAllowedOauthHostname('singletonsd.com', origins), true);
    assert.equal(isAllowedOauthHostname('patoperpetua.com', origins), true);
    assert.equal(isAllowedOauthHostname('singletonsd.com', ['*.singletonsd.com']), false);
    assert.equal(isAllowedOauthHostname('patoperpetua.com', ['*.patoperpetua.com']), false);
  });

  it('allows localhost:4321', () => {
    assert.equal(isAllowedOauthHostname('localhost:4321', origins), true);
  });

  it('rejects unrelated hosts and Azure SWA default hosts', () => {
    assert.equal(isAllowedOauthHostname('attacker.example.com', origins), false);
    assert.equal(isAllowedOauthHostname('singletonsd.com.evil.com', origins), false);
    assert.equal(
      isAllowedOauthHostname('purple-field-05048bf00.7.azurestaticapps.net', origins),
      false,
    );
    assert.equal(
      isAllowedOauthHostname('attacker.7.azurestaticapps.net', ['*.azurestaticapps.net']),
      false,
    );
  });
});

describe('buildLoginScript', () => {
  it('embeds authorization success payload for Decap handshake', () => {
    const html = buildLoginScript(
      'github',
      'success',
      { token: 'gho_test', provider: 'github' },
      origins,
    );
    assert.match(html, /authorization:github:success:/);
    assert.match(html, /gho_test/);
    assert.match(html, /authorizing:github/);
    assert.match(html, /\*\.singletonsd\.com/);
    assert.match(html, /\*\.patoperpetua\.com/);
  });
});
