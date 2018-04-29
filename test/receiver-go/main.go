package main

import (
	"context"
	"fmt"
	"log"
	"os"

	sas "github.com/Azure/azure-amqp-common-go/sas"
	eh "github.com/Azure/azure-event-hubs-go"

	"github.com/joho/godotenv"
)

var (
	groupName     string
	namespaceName string
	hubName       string
	hubKey        string
)

func init() {
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %s\n", err)
	}

	groupName = os.Getenv("EVENTHUB_GROUP_NAME")
	namespaceName = os.Getenv("EVENTHUB_NAMESPACE_NAME")
	hubName = os.Getenv("EVENTHUB_HUB_NAME")
	hubKey = os.Getenv("EVENTHUB_HUB_KEY")
}

func handler(ctx context.Context, event *eh.Event) error {
	log.Printf("MessageID: %s\n", string(event.ID))
	// log.Printf("MessageProperties: %s\n", string(event.Properties))
	log.Printf("MessageData: %s\n\n", string(event.Data))
	return nil
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	h := hub()
	hubInfo, err := h.GetRuntimeInformation(ctx)
	if err != nil {
		log.Fatalf("failed to get hub info: %s\n", err)
	}

	for _, partition := range hubInfo.PartitionIDs {
		h.Receive(ctx, partition, handler, eh.ReceiveWithStartingOffset("-1"))
	}

	fmt.Printf("Received events will be printed. Press <enter> to exit.\n")
	fmt.Scanln()
}

func hub() *eh.Hub {
	provider, err := sas.NewTokenProvider(sas.TokenProviderWithEnvironmentVars())
	if err != nil {
		log.Fatalf("failed to create SAS token provider: %s\n", err)
	}

	hub, err := eh.NewHub(namespaceName, hubName, provider)
	if err != nil {
		log.Fatalf("failed to create hub: %s\n", err)
	}

	return hub
}
