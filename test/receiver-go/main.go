package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

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

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)

	h := hub()
	hubInfo, err := h.GetRuntimeInformation(ctx)
	if err != nil {
		log.Fatalf("failed to get hub info: %s\n", err)
	}

	handler := func(ctx context.Context, event *eh.Event) error {
		log.Println(string(event.Data))
		return nil
	}

	for _, partition := range hubInfo.PartitionIDs {
		h.Receive(ctx, partition, handler, eh.ReceiveWithStartingOffset("-1"))
	}
	cancel()

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
