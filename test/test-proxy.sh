#!/bin/bash

curl -sS -o /dev/null https://httpbin.org/get 2>&1 || exit 1

curl -sS -v -o /dev/null https://httpbin.org/get 2>&1 \
    | grep -q 'X-Cache:'

if [ $? -ne 0 ]; then
    echo "Request succeeded but response was not cached" >&2
    exit 1
fi

echo "All tests passed"
