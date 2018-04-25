// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

require('dotenv').config()

const { EventHubClient, EventPosition } = require('azure-event-hubs');
const partitionCount = {};

async function main() {
  const { namespaceName, saslpolicyName, saslpolicySecret, hubName } = createConfig();
  const connectionString = `Endpoint=sb://${namespaceName}.servicebus.windows.net/;` +
    `SharedAccessKeyName=${saslpolicyName};SharedAccessKey=${saslpolicySecret}`
  const client = EventHubClient.createFromConnectionString(connectionString, hubName);
  console.log('Going to listen for events, CTRL+C to exit')
  const partitionIds = await client.getPartitionIds();
  for (const partitionId of partitionIds) {
    console.log(`Listening on: partitionId ${partitionId}, namespace ${namespaceName}, hub ${hubName}`);
    partitionCount[partitionId] = 0;
    const onMessage = (eventData) => {
      processEvent(eventData, partitionId);
    };
    const onError = (err) => {
      console.log("An error occurred on the receiver ", err);
    };
    const options = { eventPosition: EventPosition.fromStart() };
    // const options = { eventPosition: EventPosition.fromEnqueuedTime(Date.now()) };
    const receiveHandler = client.receive(partitionId, onMessage, onError, options);
  }
}

main().catch((err) => {
  console.log("An error occurred while receiving messages: ", err);
});

// Helper methods

function createConfig() {
  return {
    namespaceName: process.env["EVENTHUB_NAMESPACE_NAME"],
    saslpolicyName: process.env["EVENTHUB_KEY_NAME"],
    saslpolicySecret: process.env["EVENTHUB_KEY_VALUE"],
    hubName: process.env["EVENTHUB_HUB_NAME"]
  };
}

function processEvent(eventData, partitionId) {
  console.log(">>>>> Received message from partition id: %d, count: %d",
    partitionId, ++partitionCount[partitionId]);
  if (typeof eventData.body === "string")
    console.log(eventData.body);
  else if (eventData.body.content)
    console.log(eventData.body.content.toString("utf8"));
  else if (Buffer.isBuffer(eventData.body))
    console.log(eventData.body.toString("utf8"));
}

const CtrlC = require("death");
CtrlC((signal, err) => {
  console.log("\nstats:");
  console.log("--------------------------------------");
  console.log(" PartitionId | Received Message Count ");
  console.log("--------------------------------------");
  for (key in partitionCount) {
    console.log(`      ${key}      |          ${partitionCount[key]}`);
  }
  console.log("---------------------------------------");
  process.exit();
});
