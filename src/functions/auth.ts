import { app, HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';
import { buildGithubAuthorizeUrl, requireEnv } from '../github-oauth';

export async function authHandler(
  _request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  try {
    const location = buildGithubAuthorizeUrl({
      clientId: requireEnv('OAUTH_CLIENT_ID'),
      redirectUri: requireEnv('REDIRECT_URL'),
      scope: process.env.SCOPES?.trim() || 'repo,user',
    });
    return {
      status: 302,
      headers: { Location: location },
    };
  } catch (error) {
    context.error('auth failed', error);
    return {
      status: 500,
      jsonBody: { error: error instanceof Error ? error.message : 'auth failed' },
    };
  }
}

app.http('auth', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'auth',
  handler: authHandler,
});
