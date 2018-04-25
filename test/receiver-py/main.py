#!/usr/bin/env python

# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import os
import sys
import logging
import time
import asyncio

from dotenv import load_dotenv, find_dotenv
from azure.eventhub import Offset
from azure.eventhub.async import EventHubClientAsync


async def pump(pid, receiver, timeout):
    total = 0
    if timeout:
        deadline = time.time() + timeout
        condition = time.time() < deadline
    else:
        condition = True

    try:
        while condition:
            batch = await receiver.receive(timeout=10)
            total += len(batch)
            # print("Partition {}: total received {}, last sn={}, last offset={}".format(
            #     pid,
            #     total,
            #     batch[-1].sequence_number,
            #     batch[-1].offset))
            condition = (time.time() < deadline) if timeout else True
            for message in batch:
                print("{}".format(list(message.body)[0])
        print("Partition {}: total received {}".format(pid, total))

    except Exception as e:
        print("Partition {} receiver failed: {}".format(pid, e))


if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    load_dotenv(find_dotenv())
    namespace_name = os.environ["EVENTHUB_NAMESPACE_NAME"]
    saspolicy_name = os.environ["EVENTHUB_KEY_NAME"]
    saspolicy_secret = os.environ["EVENTHUB_KEY_VALUE"]
    hub_name = os.environ["EVENTHUB_HUB_NAME"]
    consumer_group = "$default"
    offset = Offset("-1")
    duration = None  # Optional timeout in seconds

    conn_string = "Endpoint=sb://{}.servicebus.windows.net/;SharedAccessKeyName={};SharedAccessKey={}".format(
        namespace_name,
        saspolicy_name,
        saspolicy_secret)
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
            pumps.append(pump(pid, receiver, duration))
        loop.run_until_complete(client.run_async())
        loop.run_until_complete(asyncio.gather(*pumps))
    except:
        raise
    finally:
        loop.run_until_complete(client.stop_async())
        loop.close()
