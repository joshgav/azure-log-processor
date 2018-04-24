#!/usr/bin/env python

# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os
import sys
import logging
import time

from urllib.parse import quote_plus
from dotenv import load_dotenv, find_dotenv
from azure.eventhub import EventHubClient, Receiver, Offset

# address format: "amqps://<URL-encoded-SAS-policy>:<URL-encoded-SAS-key>@<mynamespace>.servicebus.windows.net/myeventhub"
load_dotenv(find_dotenv())
SAS_KEY_NAME = quote_plus(os.environ.get("EVENTHUB_SAS_POLICY_NAME"))
SAS_KEY_VALUE = quote_plus(os.environ.get('EVENTHUB_KEY_VALUE'))
NAMESPACE_NAME = os.environ.get('EVENTHUB_NAMESPACE_NAME')
HUB_NAME = os.environ.get('EVENTHUB_HUB_NAME')

ADDRESS = 'amqps://{0}:{1}@{2}.servicebus.windows.net/{3}'.format(
	SAS_KEY_NAME, SAS_KEY_VALUE, NAMESPACE_NAME, HUB_NAME)

# SAS policy and key are not required if they are encoded in the URL
# USER = SAS_KEY_NAME
# KEY = SAS_KEY_VALUE
CONSUMER_GROUP = "$default"
OFFSET = Offset("-1")
PARTITION = "0"

total = 0
last_sn = -1
last_offset = "-1"
client = EventHubClient(ADDRESS, debug=False)
try:
    receiver = client.add_receiver(CONSUMER_GROUP, PARTITION, prefetch=5000, offset=OFFSET)
    client.run()
    start_time = time.time()
    for event_data in receiver.receive(timeout=100):
        last_offset = event_data.offset
        last_sn = event_data.sequence_number
        total += 1

    end_time = time.time()
    client.stop()
    run_time = end_time - start_time
    print("Received {} messages in {} seconds".format(total, run_time))

except KeyboardInterrupt:
    pass
finally:
    client.stop()
