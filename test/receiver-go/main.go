package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/uber/jaeger-client-go"
	"github.com/uber/jaeger-client-go/config"
	jaegerlog "github.com/uber/jaeger-client-go/log"

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
	closer := setupTracing()
	defer closer.Close()
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
		h.Receive(ctx, partition, handler, eh.ReceiveWithLatestOffset())
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

func setupTracing() io.Closer {
	// Sample configuration for testing. Use constant sampling to sample every trace
	// and enable LogSpan to log every span via configured Logger.
	cfg := config.Configuration{
		Sampler: &config.SamplerConfig{
			Type:  jaeger.SamplerTypeConst,
			Param: 1,
		},
		Reporter: &config.ReporterConfig{
			LocalAgentHostPort: "0.0.0.0:6831",
		},
	}

	// Example logger and metrics factory. Use github.com/uber/jaeger-client-go/log
	// and github.com/uber/jaeger-lib/metrics respectively to bind to real logging and metrics
	// frameworks.
	jLogger := jaegerlog.StdLogger

	closer, _ := cfg.InitGlobalTracer(
		"ehtests",
		config.Logger(jLogger),
	)

	return closer
}
