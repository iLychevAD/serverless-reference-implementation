SUBSCRIPTION=
az rest --method get --url https://management.azure.com/subscriptions/$SUBSCRIPTION/providers/Microsoft.ApiManagement/deletedservices?api-version=2020-06-01-preview

az rest --method delete  --url  https://management.azure.com/subscriptions/$SUBSCRIPTION/providers/Microsoft.ApiManagement/locations/westus2/deletedservices/dev-dsaas-portal-apim-7ekfcb2nlvy56?api-version=2020-06-01-preview

