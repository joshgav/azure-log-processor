require('dotenv').config()

const { EventHubClient, EventPosition } = require('azure-event-hubs')

const namespace_name = process.env["EVENTHUB_NAMESPACE_NAME"]
const saspolicy_name = process.env["EVENTHUB_KEY_NAME"]
const saspolicy_secret = process.env["EVENTHUB_KEY_VALUE"]
const hub_name = process.env["EVENTHUB_HUB_NAME"]

const conn_string = `Endpoint=sb://${namespace_name}.servicebus.windows.net/;SharedAccessKeyName=${saspolicy_name};SharedAccessKey=${saspolicy_secret}`

function main() {
    var ehc = EventHubClient.createFromConnectionString(conn_string, hub_name);
	console.log('Going to listen for events, CTRL+C to exit')

    ehc.getPartitionIds().then((partitionIds) => {
		for (const partitionId of partitionIds) {
			console.log(`Listening on: partitionId ${partitionId}, namespace ${namespace_name}, hub ${hub_name}`)
			ehc.receiveOnMessage(
				partitionId,
				(eventData) => { // onMessage
					console.log(eventData.body.content.toString('utf8'));
				},
				(err) => { // onError
					console.log("An error occurred on the receiver ", err);
				},
				{ // options
					eventPosition: EventPosition.fromEnqueuedTime(Date.now())
				}
			)
		}
	})
}

main()
