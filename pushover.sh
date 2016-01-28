#!/bin/bash

UserKey="uJpBTjxUCmYs5RJ6hDH7SnD86jThyz"
Token="aPZFGryiYc3MH39Fmfw8TeNkVDnsP7"

curl -s --form-string "token=$Token" --form-string "user=$UserKey" --form-string "message=$3 finished $7" https://api.pushover.net/1/messages.json
