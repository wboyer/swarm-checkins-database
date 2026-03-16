using './main.bicep'

param postgresLocation = 'southcentralus'
param syncCronExpression = '0 6 * * *'  // daily at 06:00 UTC

// Overridden by --parameters in CI — do not commit real values here:
param foursquareToken = ''
param postgresAdminPassword = ''
