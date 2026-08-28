#!/usr/bin/env python3
"""A fake Codex app-server that stalls exactly where Stop races the turn ID.

The real server names a turn twice — once in the `turn/started` notification, once in the
`turn/start` response — and either can be arbitrarily late. Each mode withholds one or both so
`codex-turn-test` can Stop inside that window and watch what the runner does about it.

`TC_STUB_ROOT` is the scratch directory the harness and this process signal through;
`TC_STUB_MODE` picks which half of the turn ID to withhold.
"""

import json
import os
import sys
import time

ROOT = os.environ["TC_STUB_ROOT"]
MODE = os.environ.get("TC_STUB_MODE", "hold-turn")
THREAD = "thread-1"
TURN = "turn-1"


def emit(message):
    sys.stdout.write(json.dumps(message) + "\n")
    sys.stdout.flush()


def record(line):
    with open(os.path.join(ROOT, "received.log"), "a") as log:
        log.write(line + "\n")


def mark(name):
    open(os.path.join(ROOT, name), "w").close()


def await_mark(name, timeout=20.0):
    """The harness releases the stall. Bounded, so a failing assertion never hangs CI."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if os.path.exists(os.path.join(ROOT, name)):
            return True
        time.sleep(0.005)
    return False


# Line-at-a-time rather than `for line in sys.stdin`: that form reads ahead, which would swallow
# the interrupt this process is meant to observe arriving after it releases a stall.
while True:
    line = sys.stdin.readline()
    if not line:
        break
    line = line.strip()
    if not line:
        continue

    message = json.loads(line)
    method = message.get("method")
    request_id = message.get("id")
    record(method or "?")

    if method == "thread/start":
        emit({"id": request_id, "result": {"thread": {"id": THREAD}}})
    elif method == "turn/start":
        mark("turn-start-received")
        await_mark("stop-landed")
        emit({"method": "turn/started", "params": {"threadId": THREAD, "turn": {"id": TURN}}})
        # `hold-turn` never answers the request: the interrupt has to come from the notification
        # alone. `hold-both` answers it too, so a turn named twice is still interrupted once.
        if MODE == "hold-both":
            emit({"id": request_id, "result": {"turn": {"id": TURN}}})
    elif method == "turn/interrupt":
        params = message.get("params", {})
        record("interrupt:%s:%s" % (params.get("threadId"), params.get("turnId")))
        emit({"id": request_id, "result": {}})
    elif request_id is not None:
        emit({"id": request_id, "result": {}})
