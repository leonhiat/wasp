import PgBoss from 'pg-boss'
import config from '../../../config.js'

export const boss = new PgBoss({ connectionString: config.databaseUrl })

// Ensure PgBoss can only be started once during a server's lifetime.
let hasPgBossBeenStarted = false

/**
 * Prepares the target PostgreSQL database and begins job monitoring.
 * If the required database objects do not exist in the specified database,
 * `boss.start()` will automatically create them.
 * Ref: https://github.com/timgit/pg-boss/blob/master/docs/readme.md#start
 * 
 * After making this call, we can send PgBoss jobs and they will be persisted and acted upon.
 * This should only be called once during a server's lifetime.
 */
export async function startPgBoss() {
  if (!hasPgBossBeenStarted) {
    console.log('Starting PgBoss...')

    boss.on('error', error => console.error(error))
    await boss.start()

    console.log('PgBoss started!')
    hasPgBossBeenStarted = true
  }
}
