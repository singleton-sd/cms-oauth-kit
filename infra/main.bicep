// Shared Decap GitHub OAuth proxy — Azure Functions in rg-ssd-global.
// Deploy: ./scripts/deploy.sh
// Secrets: OAUTH_CLIENT_SECRET from Key Vault only (never GitHub Secrets).
// CAF: ssd-cmsoauth-func-prod-ae

@description('Azure region')
param location string = resourceGroup().location

@description('Function App name (CAF)')
param functionAppName string = 'ssd-cmsoauth-func-prod-ae'

@description('Storage account for Functions (3-24 lowercase alphanumeric)')
param storageAccountName string = 'ssdcmsoauthstprod'

@description('App Service Plan name')
param planName string = 'ssd-cmsoauth-plan-prod-ae'

@description('Plan SKU. Y1 Linux Consumption is preferred; B1 only if Consumption is rejected in this RG.')
@allowed(['Y1', 'B1'])
param sku string = 'Y1'

@description('Existing Key Vault name in this resource group')
param keyVaultName string = 'ssd-global-kv-prod-ae'

@description('GitHub OAuth App client id (non-secret)')
param oauthClientId string

@description('Public hostname used as GitHub OAuth redirect_uri')
param customHostname string = 'auth.singletonsd.com'

@description('Comma-separated Decap opener hostnames (no scheme). Wildcards do not match apex.')
param origins string = '*.singletonsd.com,*.patoperpetua.com,singletonsd.com,patoperpetua.com,localhost:4321'

@description('KV secret name for GitHub OAuth client secret')
param oauthClientSecretName string = 'github-decap-oauth-client-secret'

var roleKeyVaultSecretsUser = '4633458b-17de-408a-b874-0445c86b69e6'
var isConsumption = sku == 'Y1'
var redirectUrl = 'https://${customHostname}/callback'
var storageConn = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
var contentShare = take('ssdcmsoauth${uniqueString(resourceGroup().id)}', 32)

var commonTags = {
  org: 'singleton-sd'
  project: 'cms-oauth-kit'
  repo: 'singleton-sd/cms-oauth-kit'
  env: 'prod'
  component: 'oauth'
  'managed-by': 'bicep'
}

var baseAppSettings = [
  {
    name: 'AzureWebJobsStorage'
    value: storageConn
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'node'
  }
  {
    name: 'AzureWebJobsFeatureFlags'
    value: 'EnableWorkerIndexing'
  }
  {
    name: 'WEBSITE_NODE_DEFAULT_VERSION'
    value: '~24'
  }
  {
    name: 'OAUTH_CLIENT_ID'
    value: oauthClientId
  }
  {
    name: 'OAUTH_CLIENT_SECRET'
    value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/${oauthClientSecretName}/)'
  }
  {
    name: 'REDIRECT_URL'
    value: redirectUrl
  }
  {
    name: 'SCOPES'
    value: 'repo,user'
  }
  {
    name: 'ORIGINS'
    value: origins
  }
]

var consumptionSettings = [
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: storageConn
  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: contentShare
  }
]

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: union(commonTags, { component: 'appservice-plan' })
  sku: {
    name: sku
    tier: isConsumption ? 'Dynamic' : 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: commonTags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    reserved: true
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|24'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: concat(baseAppSettings, isConsumption ? consumptionSettings : [])
    }
  }
}

resource kvFunctionSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, roleKeyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleKeyVaultSecretsUser)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output functionAppName string = functionApp.name
output functionAppHostname string = functionApp.properties.defaultHostName
output functionAppPrincipalId string = functionApp.identity.principalId
output redirectUrl string = redirectUrl
output baseUrl string = 'https://${customHostname}'
output defaultHostUrl string = 'https://${functionApp.properties.defaultHostName}'
