import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { buildGithubAuthorizeUrl } from './github-oauth';

describe('buildGithubAuthorizeUrl', () => {
  it('points at GitHub authorize with client and shared callback', () => {
    const url = new URL(
      buildGithubAuthorizeUrl({
        clientId: 'abc123',
        redirectUri: 'https://auth.singletonsd.com/callback',
        scope: 'repo,user',
        state: 'fixed-state',
      }),
    );
    assert.equal(url.origin, 'https://github.com');
    assert.equal(url.pathname, '/login/oauth/authorize');
    assert.equal(url.searchParams.get('client_id'), 'abc123');
    assert.equal(url.searchParams.get('redirect_uri'), 'https://auth.singletonsd.com/callback');
    assert.equal(url.searchParams.get('scope'), 'repo,user');
    assert.equal(url.searchParams.get('state'), 'fixed-state');
  });
});
