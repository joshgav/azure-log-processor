package main

import (
	"context"
	"flag"
	"log"
	"os"

	azmon "github.com/Azure/azure-sdk-for-go/services/monitor/mgmt/2018-03-01/insights"
	azauth "github.com/Azure/go-autorest/autorest/azure/auth"
	azto "github.com/Azure/go-autorest/autorest/to"

	"github.com/joho/godotenv"
)

var (
	subID         string
	ehHubName     string
	ehAuthzRuleID string

	// flags
	settingsName string
	resourceURI  string
	resourceType string
)

func init() {
	err := godotenv.Load()
	if err != nil {
		log.Printf("failed to load .env: %s\n", err)
	}

	subID = os.Getenv("AZURE_SUBSCRIPTION_ID")
	ehHubName = os.Getenv("EVENTHUB_HUB_NAME")
	ehAuthzRuleID = os.Getenv("EVENTHUB_AUTHZ_RULE_ID")

	flag.StringVar(&settingsName, "settingsName", "", "name for settings object")
	flag.StringVar(&resourceURI, "resourceURI", "", "full URI of resource")
	flag.StringVar(&resourceType, "resourceType", "", "type of resource")
	flag.Parse()
}

func main() {
	if (resourceURI == "") || (settingsName == "") || (resourceType == "") {
		flag.PrintDefaults()
		log.Fatalln("please provide flags")
	}

	log.Printf("adding diag settings for %s\n", resourceURI)

	res, err := addDiagSettingWithResourceType(settingsName, resourceURI, resourceType)
	if err != nil {
		log.Fatalf("failed to add diag settings: %s\n", err)
	}
	log.Printf("succeeded: %s\n", res)
}

// singleton with accessor
var _diagSettingsClient *azmon.DiagnosticSettingsClient

func diagSettingsClient() *azmon.DiagnosticSettingsClient {
	if _diagSettingsClient != nil {
		return _diagSettingsClient
	}
	c := azmon.NewDiagnosticSettingsClient(subID)
	a, err := azauth.NewAuthorizerFromEnvironment()
	if err != nil {
		log.Fatalf("failed to set up authorizer: %s\n", err)
	}
	c.Authorizer = a
	_diagSettingsClient = &c
	return &c
}

func addDiagSettingWithResourceType(name, resourceURI, resourceType string) (azmon.DiagnosticSettingsResource, error) {
	var logSettings *[]azmon.LogSettings
	var metricSettings *[]azmon.MetricSettings

	// TODO: change providerType to a strict enum and provide predefined templates
	switch resourceType {
	case "EventHub":
		logSettings = &[]azmon.LogSettings{
			{
				Category: azto.StringPtr("OperationalLogs"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("ArchiveLogs"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("AutoScaleLogs"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
		}

	case "SQLDB":

		logSettings = &[]azmon.LogSettings{
			{
				Category: azto.StringPtr("QueryStoreRuntimeStatistics"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("QueryStoreWaitStatistics"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("Errors"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("DatabaseWaitStatistics"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("Timeouts"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("Blocks"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("SQLInsights"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("Audit"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
			{
				Category: azto.StringPtr("SQLSecurityAuditEvents"),
				Enabled:  azto.BoolPtr(true),
				RetentionPolicy: &azmon.RetentionPolicy{
					Enabled: azto.BoolPtr(true),
					Days:    azto.Int32Ptr(7),
				},
			},
		}
	}

	return addDiagSetting(name, resourceURI, logSettings, metricSettings)
}

func addDiagSetting(name, resourceURI string, logSettings *[]azmon.LogSettings, metricSettings *[]azmon.MetricSettings) (azmon.DiagnosticSettingsResource, error) {
	c := diagSettingsClient()
	res, err := c.CreateOrUpdate(
		context.Background(),
		resourceURI,
		azmon.DiagnosticSettingsResource{
			DiagnosticSettings: &azmon.DiagnosticSettings{
				EventHubName:                azto.StringPtr(ehHubName),
				EventHubAuthorizationRuleID: azto.StringPtr(ehAuthzRuleID),
				Logs:    logSettings,
				Metrics: metricSettings,
			},
		},
		name,
	)
	return res, err
}
