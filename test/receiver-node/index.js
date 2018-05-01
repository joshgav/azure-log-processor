#!/usr/bin/env node

// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license.
// See LICENSE file in the project root for full license information.

require('dotenv').config()
const { EventHubClient, EventPosition } = require('azure-event-hubs');

var namespaceName, sasPolicyName, sasPolicySecret, hubName, connectionString

async function main() {
    readEnv()

    const client = EventHubClient.createFromConnectionString(connectionString, hubName);

    console.log('Going to listen for events, CTRL+C to exit')
    const partitionIds = await client.getPartitionIds();
    for (const partitionId of partitionIds) {
        console.log(`Listening on:` + 
            `partitionId ${partitionId}, namespace ${namespaceName}, hub ${hubName}`);

        const onMessage = (eventData) => {
          logEvent(eventData);
        };

        const onError = (err) => {
          console.log("An error occurred on the receiver ", err);
        };

        const options = { eventPosition: EventPosition.fromStart() };

        client.receive(partitionId, onMessage, onError, options);
    }
}

main().catch((err) => {
    console.log("An error occurred while receiving messages: ", err);
});

// helpers

function readEnv() {
    namespaceName = process.env["EVENTHUB_NAMESPACE_NAME"]
    saspolicyName = process.env["EVENTHUB_KEY_NAME"]
    saspolicySecret = process.env["EVENTHUB_KEY_VALUE"]
    // hubName = process.env["EVENTHUB_HUB_NAME"]
    hubName = process.env["ARM_ACTIVITYLOG_HUB_NAME"]
    connectionString = `Endpoint=sb://${namespaceName}.servicebus.windows.net/;` +
        `SharedAccessKeyName=${saspolicyName};SharedAccessKey=${saspolicySecret}`
}

function logEvent(eventData) {
    if (typeof eventData.body === "string")
        console.log(eventData.body);
    else if (eventData.body.content)
        console.log(eventData.body.content.toString("utf8"));
    else if (Buffer.isBuffer(eventData.body))
        console.log(eventData.body.toString("utf8"));
}
