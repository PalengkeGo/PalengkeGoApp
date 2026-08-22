/**
 * Cross-platform runner for the payments E2E suite (Windows cmd cannot do
 * `VAR=x cmd`). Sets the stub-PayMongo env, then boots the emulators.
 */
const { execSync } = require('child_process');

process.env.PAYMENTS_E2E = '1';
process.env.PAYMONGO_API_URL = 'http://127.0.0.1:9777/v1';
process.env.PAYMONGO_SECRET_KEY = 'sk_test_e2e_stub';
process.env.PAYMONGO_WEBHOOK_SECRET = 'whsec_e2e_stub';

execSync(
  'firebase emulators:exec --project demo-palengkegodb --only firestore,auth,functions ' +
    '"npx jest --runInBand payments_e2e.test.ts"',
  { stdio: 'inherit' },
);
