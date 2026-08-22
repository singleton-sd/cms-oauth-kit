/**
 * Decap / Netlify CMS OAuth handshake HTML (postMessage to opener).
 * @see https://github.com/vencax/netlify-cms-github-oauth-provider
 */

export type OauthResultMessage = 'success' | 'error';

/** Locked production ORIGINS for cms-oauth-kit. Apex names are required; wildcards do not match the root. */
export const DEFAULT_ORIGINS =
  '*.singletonsd.com,*.patoperpetua.com,singletonsd.com,patoperpetua.com,localhost:4321';

const AZURE_SWA_ROOT = 'azurestaticapps.net';
const SWA_INSTANCE_SUFFIX = `*.${AZURE_SWA_ROOT}`;

export function parseOrigins(raw: string | undefined): string[] {
  if (!raw?.trim()) {
    throw new Error('ORIGINS must be a comma-separated list of allowed hostnames');
  }
  return raw
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
}

/**
 * Allow exact hostnames and generic `*` globs (including nested subdomains).
 * SWA instance prefixes (`name*.azurestaticapps.net`) are supported for a
 * specific SWA; open `*.azurestaticapps.net` is rejected.
 */
export function isAllowedOauthHostname(host: string, origins: readonly string[]): boolean {
  for (const entry of origins) {
    if (entry === host) {
      return true;
    }

    if (entry.endsWith(SWA_INSTANCE_SUFFIX)) {
      const swaName = entry.slice(0, -SWA_INSTANCE_SUFFIX.length);
      if (!swaName || swaName.includes('*')) {
        continue;
      }
      if (!host.endsWith(`.${AZURE_SWA_ROOT}`)) {
        continue;
      }
      if (host.startsWith(`${swaName}.`) || host.startsWith(`${swaName}-`)) {
        return true;
      }
      continue;
    }

    if (entry.includes('*')) {
      const regex = new RegExp(`^${entry.replace(/\./g, '\\.').replace(/\*/g, '[\\w_.-]+')}$`);
      if (regex.test(host)) {
        return true;
      }
    }
  }
  return false;
}

/** Browser-side mirror of `isAllowedOauthHostname` (no TypeScript in the popup). */
function buildContainsRuntime(): string {
  return `function contains(arr, elem) {
    for (var i = 0; i < arr.length; i++) {
      var entry = arr[i];
      if (entry === elem) return true;
      var swaMarker = '*.azurestaticapps.net';
      if (entry.length >= swaMarker.length && entry.slice(-swaMarker.length) === swaMarker) {
        var swaName = entry.slice(0, -swaMarker.length);
        if (!swaName || swaName.indexOf('*') >= 0) continue;
        if (elem.slice(-'.azurestaticapps.net'.length) !== '.azurestaticapps.net') continue;
        if (elem.indexOf(swaName + '.') === 0 || elem.indexOf(swaName + '-') === 0) return true;
        continue;
      }
      if (entry.indexOf('*') >= 0) {
        var regex = new RegExp('^' + entry.replace(/\\./g, '\\\\.').replace(/\\*/g, '[\\\\w_.-]+') + '$');
        if (elem.match(regex) !== null) return true;
      }
    }
    return false;
  }`;
}

export function buildLoginScript(
  oauthProvider: string,
  message: OauthResultMessage,
  content: Record<string, unknown> | string,
  origins: string[],
): string {
  const contentJson = typeof content === 'string' ? content : JSON.stringify(content);
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8" /><title>CMS OAuth</title></head>
<body>
<script>
(function () {
  var origins = ${JSON.stringify(origins)};
  ${buildContainsRuntime()}
  function receiveMessage(e) {
    var host = e.origin.replace('https://', '').replace('http://', '');
    if (!contains(origins, host)) {
      console.log('Invalid origin:', e.origin);
      return;
    }
    window.opener.postMessage(
      'authorization:${oauthProvider}:${message}:${contentJson}',
      e.origin
    );
  }
  window.addEventListener('message', receiveMessage, false);
  window.opener.postMessage('authorizing:${oauthProvider}', '*');
})();
</script>
<p>Completing GitHub login…</p>
</body>
</html>`;
}
