// Build-time patches for the pinned gortexhq/web commit. Exits non-zero if a target line is missing.
const fs = require("fs");
function patch(file, pattern, replacement) {
  const before = fs.readFileSync(file, "utf8");
  const after = before.replace(pattern, replacement);
  if (after === before) { console.error(`patch did not apply: ${file}`); process.exit(1); }
  fs.writeFileSync(file, after);
  console.log(`patched ${file}`);
}
// API base: empty string means relative fetches to /v1/* on the UI's own origin.
patch("src/lib/api.ts",
  /const SERVER_URL = process\.env\.NEXT_PUBLIC_GORTEX_URL\s*\|\|\s*process\.env\.NEXT_PUBLIC_GORTEX_WEB_URL\s*\|\|\s*'http:\/\/localhost:4747'/,
  "const SERVER_URL = process.env.NEXT_PUBLIC_GORTEX_URL || ''");
// Dashboard label that names the server it talks to.
patch("src/components/dashboard/Dashboard.tsx",
  /process\.env\.NEXT_PUBLIC_GORTEX_URL \|\| 'http:\/\/localhost:4747'/,
  "process.env.NEXT_PUBLIC_GORTEX_URL || 'the gortex service behind this page'");
