@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Azure region for PostgreSQL (may differ from main location due to quota restrictions).')
param postgresLocation string = location

@description('Short alphanumeric prefix used in resource names. Must be globally unique enough for ACR and Postgres.')
param appName string

@description('Foursquare OAuth2 user token.')
@secure()
param foursquareToken string

@description('PostgreSQL admin password.')
@secure()
param postgresAdminPassword string

@description('Container image tag to deploy.')
param imageTag string = 'latest'

@description('CRON expression for the scheduled sync (UTC).')
param syncCronExpression string = '0 6 * * *'

// ---------------------------------------------------------------------------
// Container Registry
// ---------------------------------------------------------------------------

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${appName}Acr'
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

// ---------------------------------------------------------------------------
// PostgreSQL Flexible Server
// ---------------------------------------------------------------------------

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: '${appName}-ps'
  location: postgresLocation
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: 'swarm'
    administratorLoginPassword: postgresAdminPassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
    highAvailability: { mode: 'Disabled' }
  }
}

resource postgresDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgres
  name: 'swarm_checkins'
}

// Allow connections from other Azure services (includes Container Apps)
resource postgresFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Enable PostGIS extension
resource postgresExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: postgres
  name: 'azure.extensions'
  properties: {
    value: 'POSTGIS'
    source: 'user-override'
  }
  dependsOn: [postgresDb]
}

// ---------------------------------------------------------------------------
// Log Analytics (required by Container Apps Environment)
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${appName}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// Container Apps Environment
// ---------------------------------------------------------------------------

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${appName}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared config for both jobs
// ---------------------------------------------------------------------------

var image = '${acr.properties.loginServer}/swarm-checkins-database-sync:${imageTag}'
var databaseUrl = 'postgresql://swarm:${postgresAdminPassword}@${postgres.properties.fullyQualifiedDomainName}/swarm_checkins'

var sharedSecrets = [
  { name: 'acr-password', value: acr.listCredentials().passwords[0].value }
  { name: 'database-url', value: databaseUrl }
  { name: 'foursquare-token', value: foursquareToken }
]

var sharedRegistries = [
  {
    server: acr.properties.loginServer
    username: acr.listCredentials().username
    passwordSecretRef: 'acr-password'
  }
]

var sharedEnvVars = [
  { name: 'DATABASE_URL', secretRef: 'database-url' }
  { name: 'FOURSQUARE_TOKEN', secretRef: 'foursquare-token' }
]

// ---------------------------------------------------------------------------
// Migrate job (manual trigger — run from CI after each deploy)
// ---------------------------------------------------------------------------

resource migrateJob 'Microsoft.App/jobs@2024-03-01' = {
  name: '${appName}-migrate'
  location: location
  properties: {
    environmentId: containerEnv.id
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 300
      replicaRetryLimit: 0  // never retry a failed migration
      registries: sharedRegistries
      secrets: sharedSecrets
    }
    template: {
      containers: [
        {
          name: 'migrate'
          image: image
          command: ['alembic', 'upgrade', 'head']
          env: sharedEnvVars
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Sync job (scheduled daily + triggerable manually from CI)
// ---------------------------------------------------------------------------

resource syncJob 'Microsoft.App/jobs@2024-03-01' = {
  name: '${appName}-sync'
  location: location
  properties: {
    environmentId: containerEnv.id
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 1800  // 30 minutes
      replicaRetryLimit: 1
      scheduleTriggerConfig: { cronExpression: syncCronExpression }
      registries: sharedRegistries
      secrets: sharedSecrets
    }
    template: {
      containers: [
        {
          name: 'sync'
          image: image
          env: sharedEnvVars
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs (referenced in GitHub Actions)
// ---------------------------------------------------------------------------

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output migrateJobName string = migrateJob.name
output syncJobName string = syncJob.name
