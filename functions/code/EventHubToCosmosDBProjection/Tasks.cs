using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace EventHubToCosmosDbProjection
{
    public static class Tasks
    {
        [FunctionName("Eh1ToCosmosDb1Binary")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static async Task Eh1ToCosmosDb1Binary(
            [EventHubTrigger("eh1", ConsumerGroup = "Eh1ToCosmosDb1", Connection = "Eh1ToCosmosDb1-source-connection")] EventData[] input,
            [CosmosDB(databaseName: "SampleDB", collectionName: "foo", ConnectionStringSetting = "CosmosDBConnection")] IAsyncCollector<object> output,
            ILogger log)
        {
            foreach (var ev in input)
            {
                if (!string.IsNullOrEmpty(ev.SystemProperties.PartitionKey))
                {
                    var record = new
                    {
                        id = ev.SystemProperties.PartitionKey,
                        data = ev.Body.ToArray(),
                        properties = ev.Properties
                    };
                    await output.AddAsync(record);
                }
            }
        }

        [FunctionName("Eh1ToCosmosDb1Json")]
        [ExponentialBackoffRetry(-1, "00:00:05", "00:05:00")]
        public static async Task Eh1ToCosmosDb1Json(
            [EventHubTrigger("eh1", ConsumerGroup = "Eh1ToCosmosDb1", Connection = "Eh1ToCosmosDb1-source-connection")] EventData[] input,
            [CosmosDB(databaseName: "SampleDb", collectionName: "foo", ConnectionStringSetting = "CosmosDBConnection")] IAsyncCollector<object> output,
            ILogger log)
        {
            foreach (var ev in input)
            {
                if (!string.IsNullOrEmpty(ev.SystemProperties.PartitionKey))
                {
                    var record = new
                    {
                        id = ev.SystemProperties.PartitionKey,
                        data = JsonDocument.Parse(ev.Body),
                        properties = ev.Properties
                    };
                    await output.AddAsync(record);
                }
            }
        }
    }
}
