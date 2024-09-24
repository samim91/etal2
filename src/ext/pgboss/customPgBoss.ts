import PgBoss from 'pg-boss'
import { config } from 'wasp/server'

// Function to create a PgBoss instance with SSL configuration
export function createPgBoss() {
  let pgBossNewOptions = {
    connectionString: config.databaseUrl,
    ssl: {
      rejectUnauthorized: false,  // Enforces SSL, but does not validate certificates
    },
  }

  // Optional: Advanced configuration for pg-boss via environment variable
  if (process.env.PG_BOSS_NEW_OPTIONS) {
    try {
      pgBossNewOptions = JSON.parse(process.env.PG_BOSS_NEW_OPTIONS)
    } catch {
      console.error(
        'Environment variable PG_BOSS_NEW_OPTIONS was not parsable by JSON.parse()!'
      )
    }
  }

  console.log('pg-boss connection options:', pgBossNewOptions)  // Log to verify

  return new PgBoss(pgBossNewOptions)
}

// Function to start PgBoss with error handling
export async function startPgBoss(boss: PgBoss): Promise<void> {
  console.log('Starting pg-boss...')

  // Listen for any errors from pg-boss
  boss.on('error', (error) => console.error('pg-boss error:', error))

  try {
    await boss.start()
    console.log('pg-boss started successfully!')
  } catch (error) {
    console.error('pg-boss failed to start!', error)
    throw error  // Propagate the error
  }
}
