#!/usr/bin/env bash

ssh "${WOL_RELAY_HOST}" "cd ${WOL_RELAY_PATH} && ./wake_argonaut.sh"
