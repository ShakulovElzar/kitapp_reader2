// Runs the admin API QA scenarios against a throwaway `kitapp_test` database and
// storage folder, so QA never writes test readers or books into the dev data.
// Usage: npm run qa:api   (needs `docker compose up -d` for PostgreSQL)
const { spawn, spawnSync } = require('node:child_process');
const path = require('node:path');
const { Client } = require('pg');

const root = path.resolve(__dirname, '..');
const server = path.join(root, 'server');
const port = process.env.QA_PORT || '3200';
const baseDb = process.env.QA_BASE_DATABASE_URL || 'postgresql://kitapp:kitapp@127.0.0.1:55432/kitapp';
const testDb = baseDb.replace(/\/[^/?]+(\?.*)?$/, '/kitapp_test$1');
const env = {
  ...process.env,
  DATABASE_URL: testDb,
  STORAGE_PATH: path.join(server, 'storage-test'),
  PORT: port,
  PUBLIC_URL: `http://127.0.0.1:${port}`,
  OTP_MODE: 'local',
  SMS_PROVIDER: 'log',
  OTP_IP_LIMIT: '1000',
  EDITOR_EMAIL: 'editor@kitapp.kg',
  EDITOR_PASSWORD: 'Editor123!',
};

function run(command, args) {
  const result = spawnSync(command, args, { cwd: server, env, stdio: 'inherit' });
  if (result.status !== 0) throw new Error(`${command} ${args.join(' ')} failed`);
}

async function waitForServer() {
  for (let attempt = 0; attempt < 60; attempt++) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/api/catalog/categories`);
      if (response.ok) return;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error('QA server did not start');
}

(async () => {
  const admin = new Client({ connectionString: baseDb });
  await admin.connect();
  const exists = await admin.query("select 1 from pg_database where datname = 'kitapp_test'");
  if (!exists.rowCount) await admin.query('create database kitapp_test');
  await admin.end();

  run('npx', ['prisma', 'migrate', 'deploy']);
  run('npx', ['tsx', 'prisma/seed.ts']);
  run('npm', ['run', 'build']);

  const api = spawn('node', ['dist/src/main.js'], { cwd: server, env, stdio: 'ignore' });
  let failed = false;
  try {
    await waitForServer();
    const qa = spawnSync('node', [path.join(__dirname, 'qa_admin_api.cjs')], {
      cwd: root,
      stdio: 'inherit',
      env: {
        ...process.env,
        KITAPP_API_URL: `http://127.0.0.1:${port}/api`,
        KITAPP_QA_EDITOR_EMAIL: env.EDITOR_EMAIL,
        KITAPP_QA_EDITOR_PASSWORD: env.EDITOR_PASSWORD,
      },
    });
    failed = qa.status !== 0;
  } finally {
    api.kill();
  }
  process.exit(failed ? 1 : 0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
