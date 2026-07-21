import { compareMigrations, fail, loadMigrations, readAppliedMigrations, withConnection } from "./lib.mjs";

const lockId = 4_826_191_337;

try {
  await withConnection(async (sql) => {
    await sql`select pg_advisory_lock(${lockId})`;
    try {
      await sql`
        create table if not exists schema_migrations (
          name text primary key,
          checksum text not null,
          applied_at timestamptz not null default now()
        )
      `;

      const files = await loadMigrations();
      const applied = await readAppliedMigrations(sql);
      const { changed, missing, pending } = compareMigrations(files, applied);
      if (changed.length || missing.length) {
        throw new Error(
          `Migration history mismatch: changed=${changed.map((item) => item.name).join(",") || "none"} missing=${missing.map((item) => item.name).join(",") || "none"}`,
        );
      }

      for (const migration of pending) {
        await sql.begin(async (transaction) => {
          await transaction.unsafe(migration.sql);
          await transaction`
            insert into schema_migrations (name, checksum)
            values (${migration.name}, ${migration.checksum})
          `;
        });
        console.log(`applied ${migration.name}`);
      }
      console.log(`schema current (${files.length} migrations)`);
    } finally {
      await sql`select pg_advisory_unlock(${lockId})`;
    }
  }, "DATABASE_MIGRATOR_URL");
} catch (error) {
  fail(error, "database-migrate");
}
