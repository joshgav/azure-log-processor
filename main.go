package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/Azure/azure-amqp-common-go/sas"
	eh "github.com/Azure/azure-event-hubs-go"
	ehmgmt "github.com/Azure/azure-sdk-for-go/services/eventhub/mgmt/2017-04-01/eventhub"
	"github.com/Azure/go-autorest/autorest/azure/auth"

	"github.com/joho/godotenv"
)

var (
	baseName      string
	groupName     string
	namespaceName string
	policyName    string
	hubName       string
)

func init() {
	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %s\n", err)
	}

	baseName = os.Getenv("AZURE_BASE_NAME")
	groupName = fmt.Sprintf("%s-group", baseName)
	namespaceName = fmt.Sprintf("%sns", strings.Replace(baseName, "-", "", -1))
	policyName = fmt.Sprintf("%s-policy", baseName)
	hubName = fmt.Sprintf("%s-hub", baseName)
}

func handler(ctx context.Context, event *eh.Event) error {
	log.Printf("==EVENT(ID: %s)==\nProperties: %+v\nData: %s\n",
		event.ID, event.Properties, string(event.Data))
	return nil
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	namespaces := ehmgmt.NewNamespacesClient(os.Getenv("AZURE_SUBSCRIPTION_ID"))
	a, err := auth.NewAuthorizerFromEnvironment()
	if err != nil {
		log.Fatalf("could not create authorizer: %s\n", err)
	}
	namespaces.Authorizer = a
	keys, err := namespaces.ListKeys(ctx, groupName, namespaceName, policyName)
	if err != nil {
		log.Fatalf("could not list keys: %s\n", err)
	}

	token, err := sas.NewTokenProvider(sas.TokenProviderWithKey(policyName, *keys.PrimaryKey))
	if err != nil {
		log.Fatalf("failed to create SAS token provider: %s\n", err)
	}

	hub, err := eh.NewHub(namespaceName, hubName, token)
	if err != nil {
		log.Fatalf("failed to create hub: %s\n", err)
	}

	hubInfo, err := hub.GetRuntimeInformation(ctx)
	if err != nil {
		log.Fatalf("failed to get hub info: %s\n", err)
	}

	for _, partition := range hubInfo.PartitionIDs {
		hub.Receive(ctx, partition, handler, eh.ReceiveWithStartingOffset("-1"))
	}

	fmt.Printf("Received events will be printed. Press <enter> to exit.\n")
	fmt.Scanln()
}
