import { pathToFileURL } from "node:url";
import { bootConfig, createHarness } from "./test.mjs";

const providerName = "Café & Bar #2 + 東京";
const opaqueState = /^[\w-]{22}$/;

// Stands in for the hosted page: take the scheme from the envelope and echo `state` back as sent.
function relay(state) {
  const { scheme } = JSON.parse(Buffer.from(state, "base64url").toString());
  return encodeURI(`${scheme}://oauth?code=relayed&package_name=Extension&state=${state}`);
}

export async function runOAuthFixtures(check) {
  let respond;
  const harness = createHarness({
    stubs: { "oauth.authorize": ([url]) => respond(new URL(url).searchParams.get("state")) },
  });
  harness.boot(bootConfig());
  harness.start("oauth", `
    const { OAuth } = require("@raycast/api");
    module.exports.default = () => {
      globalThis.prepare = async (method, extraParameters) => {
        globalThis.client = new OAuth.PKCEClient({ redirectMethod: OAuth.RedirectMethod[method], providerName: ${JSON.stringify(providerName)} });
        globalThis.request = await client.authorizationRequest({ endpoint: "https://auth.example.test/authorize", clientId: "fixture", scope: "repo", extraParameters });
        return { state: request.state, verifier: request.codeVerifier };
      };
      globalThis.signIn = (target) => client.authorize(target ?? request)
        .then(({ authorizationCode }) => authorizationCode, (error) => error.message);
    };`, "/oauth.js", "/", "no-view", {});
  await new Promise((resolve) => setTimeout(resolve, 20));
  const signIn = () => harness.call("signIn()");
  const signInWithURL = () => harness.call("signIn({ url: request.toURL() })");
  const bothSignIns = async () => [await signIn(), await signInWithURL()];
  const rejected = (results) => results.every((result) => result.includes("mismatched state"));

  try {
    const web = await harness.call('prepare("Web")');
    const envelope = JSON.parse(Buffer.from(web.state, "base64url").toString());
    check("web state is a base64url envelope", /^[\w-]+$/.test(web.state) && envelope.scheme === "raycast"
      && opaqueState.test(envelope.nonce), JSON.stringify(envelope));
    check("the envelope keeps the provider name intact", envelope.providerName === providerName, envelope.providerName);
    respond = relay;
    const relayed = await bothSignIns();
    check("a relayed web sign-in returns its code", relayed.every((code) => code === "relayed"), JSON.stringify(relayed));

    const next = await harness.call('prepare("Web")');
    check("each request draws a fresh state and verifier", next.state !== web.state && next.verifier !== web.verifier);
    for (const [label, suffix] of [
      ["a missing", ""],
      ["an empty", "&state="],
      ["a mismatched", "&state=wrong"],
      ["a duplicated", `&state=${next.state}&state=${next.state}`],
    ]) {
      respond = () => `raycast://oauth?code=relayed${suffix}`;
      const results = await bothSignIns();
      check(`${label} state is rejected`, rejected(results), JSON.stringify(results));
    }
    respond = () => relay(web.state);
    const stale = await bothSignIns();
    check("a stale request's state is rejected", rejected(stale), JSON.stringify(stale));
    respond = (state) => `raycast://oauth?state=${state}`;
    const codeless = await signIn();
    check("a redirect without a code is rejected", codeless.includes("no authorization code"), codeless);

    for (const [method, target] of [
      ["App", "raycast://oauth"],
      ["AppURI", "com.raycast:/oauth"],
      ["ClientIdMetadataDocument", "com.raycast:/oauth"],
    ]) {
      const { state } = await harness.call(`prepare("${method}")`);
      respond = (sent) => `${target}?code=direct&state=${sent}`;
      const returned = await signIn();
      respond = () => `${target}?code=direct`;
      const missing = await signIn();
      check(`${method} sends an opaque state and requires it back`,
        opaqueState.test(state) && returned === "direct" && rejected([missing]), JSON.stringify([state, returned, missing]));
    }

    await harness.call('prepare("App", { state: "custom-state" })');
    respond = (sent) => `raycast://oauth?code=custom&state=${sent}`;
    const overridden = await bothSignIns();
    check("an extra state parameter is the one checked", overridden.every((code) => code === "custom"), JSON.stringify(overridden));
    respond = () => "raycast://oauth?code=stateless";
    const stateless = await harness.call('signIn({ url: "https://auth.example.test/authorize" })');
    check("a custom URL without state is not checked", stateless === "stateless", stateless);
  } finally {
    harness.stop("oauth");
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  let failures = 0;
  await runOAuthFixtures((label, condition, detail) => {
    console.log(`${condition ? "✓" : "✗"} ${label}${condition ? "" : ` — ${detail}`}`);
    if (!condition) failures++;
  });
  process.exitCode = failures ? 1 : 0;
}
