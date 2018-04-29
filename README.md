![Azure Logs Processor](./doc/images/azure-log-processor.png)

# To run

1. Fill in `.env.tpl` and move to `.env`.
1. `make deploy`
1. `make build`
1. `./dist/receiver-go`
1. `node ./test/receiver-node`
1. `python3 ./test/receiver-py/main.py`
