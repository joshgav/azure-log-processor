#!/usr/bin/env python3

# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

import os
import sys
import logging
import time
import asyncio

from dotenv import load_dotenv, find_dotenv
from azure.eventhub.async import EventHubClientAsync
from azure.eventhub import Offset

def handler(eventData):
    print(list(eventData.body))

async def pump(receiver):
    await receiver.receive(callback=handler)

def readEnv():
    global namespace_name, saspolicy_name, saspolicy_secret, \
        hub_name, consumer_group, conn_string
    load_dotenv(find_dotenv())
    namespace_name = os.environ["EVENTHUB_NAMESPACE_NAME"]
    saspolicy_name = os.environ["EVENTHUB_KEY_NAME"]
    saspolicy_secret = os.environ["EVENTHUB_KEY_VALUE"]
    hub_name = os.environ["EVENTHUB_HUB_NAME"]
    conn_string = ("Endpoint=sb://{}.servicebus.windows.net/;"
        "SharedAccessKeyName={};SharedAccessKey={}").format(
            namespace_name,
            saspolicy_name,
            saspolicy_secret)
    consumer_group = "$default"

if __name__ == '__main__':
    readEnv()
    loop = asyncio.get_event_loop()
    offset = Offset("-1")

    client = EventHubClientAsync.from_connection_string(
        conn_string,
        eventhub=hub_name)

    try:
        eh_info = loop.run_until_complete(client.get_eventhub_info_async())
        partition_ids = eh_info['partition_ids']

        pumps = []
        for pid in partition_ids:
            receiver = client.add_async_receiver(
                consumer_group=consumer_group,
                partition=pid,
                offset=offset,
                prefetch=5000)
            pumps.append(pump(receiver))
        loop.run_until_complete(client.run_async())
        loop.run_until_complete(asyncio.gather(*pumps))
    except:
        raise
    finally:
        loop.run_until_complete(client.stop_async())
        loop.close()
