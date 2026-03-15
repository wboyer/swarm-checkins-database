using './main.bicep'

param appName = 'swarmCheckinsDatabaseSync'          // change to something globally unique
param syncCronExpression = '0 6 * * *'  // daily at 06:00 UTC

// Set these via --parameters or environment secrets — do not commit real values:
// param foursquareToken = ''
// param postgresAdminPassword = ''
