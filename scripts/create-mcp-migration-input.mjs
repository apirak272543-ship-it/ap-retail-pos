import { readFile, writeFile } from 'node:fs/promises';

const [sourcePath, targetPath, migrationName] = process.argv.slice(2);

if (!sourcePath || !targetPath || !migrationName) {
  throw new Error('Usage: node create-mcp-migration-input.mjs <source.sql> <target.json> <migration_name>');
}

const query = await readFile(sourcePath, 'utf8');
const payload = {
  project_id: 'abtsctwfkgzciseppach',
  name: migrationName,
  query,
};

await writeFile(targetPath, `${JSON.stringify(payload)}\n`, 'utf8');
