using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using System.Security.Claims;
using System.Threading.Tasks;

namespace DroneStatusFunctionApp
{
    public static class GetStatusFunction
    {
        public const string GetDeviceStatusRoleName = "GetStatus";

        [FunctionName("GetStatusFunction")]
        public static IActionResult Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", Route = null)]HttpRequest req, 
            [CosmosDB(
                databaseName: "%COSMOSDB_DATABASE_NAME%",
                collectionName: "%COSMOSDB_DATABASE_COL%",
                ConnectionStringSetting = "COSMOSDB_CONNECTION_STRING",
                Id = "{Query.deviceId}",
                PartitionKey = "{Query.deviceId}")] dynamic deviceStatus, 
            ClaimsPrincipal principal,
            ILogger log)
        {   
            string name = principal.Identity.Name;
            string authType = principal.Identity.AuthenticationType;
            string isAuthed = principal.Identity.IsAuthenticated.ToString();
            log.LogInformation($"GetStatus request: {authType} {isAuthed} {name}");
            foreach (var identity in principal.Identities)
            {
                log.LogInformation($"Identity {identity.Name}:");
                log.LogInformation($"Auth type is {identity.AuthenticationType}");
                foreach (var claim in identity.Claims)
                {
                    log.LogInformation($"Claim '{claim.Type}' = '{claim.Value}'");
                }
            }

            if (!principal.IsAuthorizedByRoles(new[] { GetDeviceStatusRoleName }, log))
            {
                log.LogInformation("Principal role check - not authorized!");
                return new UnauthorizedResult();
            }

            string deviceId = req.Query["deviceId"];
            if (deviceId == null)
            {
                return new BadRequestObjectResult("Missing DeviceId");
            }

            if (deviceStatus == null)
            {
                return new NotFoundResult();
            }
            else
            {
                return new OkObjectResult(deviceStatus);
            }
        }
    }
}
