import { app, HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';
import { exchangeGithubCode, requireEnv } from '../github-oauth';
import { buildLoginScript, parseOrigins } from '../login-script';

export async function callbackHandler(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  try {
    const code = request.query.get('code');
    const origins = parseOrigins(process.env.ORIGINS);

    if (!code) {
      const html = buildLoginScript('github', 'error', { error: 'missing code' }, origins);
      return { status: 400, headers: { 'Content-Type': 'text/html; charset=utf-8' }, body: html };
    }

    const result = await exchangeGithubCode({
      clientId: requireEnv('OAUTH_CLIENT_ID'),
      clientSecret: requireEnv('OAUTH_CLIENT_SECRET'),
      code,
      redirectUri: requireEnv('REDIRECT_URL'),
    });

    if ('error' in result) {
      context.error('token exchange failed', result.error);
      const html = buildLoginScript('github', 'error', { error: result.error }, origins);
      return { status: 400, headers: { 'Content-Type': 'text/html; charset=utf-8' }, body: html };
    }

    const html = buildLoginScript(
      'github',
      'success',
      { token: result.accessToken, provider: 'github' },
      origins,
    );
    return { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' }, body: html };
  } catch (error) {
    context.error('callback failed', error);
    return {
      status: 500,
      jsonBody: { error: error instanceof Error ? error.message : 'callback failed' },
    };
  }
}

app.http('callback', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'callback',
  handler: callbackHandler,
});
