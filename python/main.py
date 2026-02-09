import sys
import json
import time

# --- Tracing/Diagnostics Scaffolding (Issue #87) ---

class TracingSystem:
    def __init__(self):
        self.spans = []
        self.events = []
        self.metrics = {}
        self.is_tracing = False
        self.current_span_id: str | None = None
        self.current_trace_id: str | None = None

    def _generate_id(self):
        return hex(int(time.time() * 1000000) + len(self.spans) + len(self.events))

    def start_span(self, name, parent_id=None):
        if not self.is_tracing: return
        span_id = self._generate_id()
        self.current_span_id = span_id
        self.spans.append({
            "spanId": span_id,
            "name": name,
            "startTime": time.time(),
            "parentId": parent_id,
            "status": "STARTED",
            "tags": {"engine": "python_scaffold"}
        })
        return span_id

    def end_span(self, span_id, status="COMPLETED"):
        if not self.is_tracing: return
        for span in self.spans:
            if span["spanId"] == span_id and span["status"] == "STARTED":
                span["endTime"] = time.time()
                span["status"] = status
                return

    def log_event(self, name, payload=None):
        if not self.is_tracing: return
        event_id = self._generate_id()
        self.events.append({
            "eventId": event_id,
            "timestamp": time.time(),
            "name": name,
            "payload": payload if payload is not None else {},
            "spanId": self.current_trace_id if self.is_tracing else None
        })

    def record_metric(self, name, value, unit="count"):
        if not self.is_tracing: return
        if name not in self.metrics:
            self.metrics[name] = []
        self.metrics[name].append({
            "timestamp": time.time(),
            "value": value,
            "unit": unit
        })

    def export_chrome_trace(self):
        if not self.is_tracing: return "{}"
        trace_data = []
        # Convert spans to Chrome format (Simplified)
        for span in self.spans:
            trace_data.append({
                "ph": "X", # Complete event
                "name": span["name"],
                "pid": 1, # Process ID (Placeholder)
                "tid": 1, # Thread ID (Placeholder)
                "ts": int(span["startTime"] * 1000000), # Microseconds
                "dur": int((span.get("endTime", time.time()) - span["startTime"]) * 1000000),
                "args": {"status": span["status"], "tags": span["tags"]}
            })
        # Convert events to Chrome format (Simplified)
        for event in self.events:
            trace_data.append({
                "ph": "i", # Instant event
                "name": event["name"],
                "pid": 1,
                "tid": 1,
                "ts": int(event["timestamp"] * 1000000),
                "args": {"payload": event["payload"]}
            })
        return json.dumps({"traceEvents": trace_data}, indent=2)

    def report_metrics(self):
        if not self.is_tracing: return
        # In a real engine, this would send data somewhere. Here, we just output.
        sys.stdout.write(f"METRICS REPORT: {json.dumps(self.metrics, indent=2)}\\n")
        sys.stdout.flush()


# --- Engine Core Placeholder ---

def display_board_ascii(state):
    # Placeholder for ASCII output with coordinates
    print("debug board state: (Placeholder)")
    print("8 . . . . . . . .")
    print("7 . . . . . . . .")
    print("6 . . . . . . . .")
    print("5 . . . . . . . .")
    print("4 . . . . . . . .")
    print("3 . . . . . . . .")
    print("2 . . . . . . . .")
    print("1 . . . . . . . .")
    print("  a b c d e f g h")

def handle_command(command_line, tracing_sys):
    parts = command_line.strip().split()
    if not parts:
        return True

    cmd = parts[0].lower()

    if cmd == "new":
        # Start tracing upon engine initialization for diagnostics
        if not tracing_sys.is_tracing:
            tracing_sys.is_tracing = True
            tracing_sys.current_trace_id = tracing_sys.start_span("engine_startup")
            tracing_sys.log_event("command_new")
        print("ok")

    elif cmd == "move":
        if len(parts) == 2:
            move = parts[1]
            span_id = tracing_sys.start_span(f"move_{move}", parent_id=tracing_sys.current_span_id)
            tracing_sys.log_event("move_attempt", {"move": move})
            # Simulate move execution delay
            time.sleep(0.01)
            tracing_sys.record_metric("move_execution_time", 10, "ms") # Placeholder time
            tracing_sys.end_span(span_id)
            print("ok")
        else:
            print("error: invalid move command format")

    elif cmd == "export":
        if len(parts) > 1 and parts[1] == "fen":
            display_board_ascii("current_state")
            print("ok")
        elif len(parts) > 1 and parts[1] == "chrome_trace":
            output = tracing_sys.export_chrome_trace()
            sys.stdout.write(f"TRACE_OUTPUT_START\\n{output}\\nTRACE_OUTPUT_END\\n")
            sys.stdout.flush()
            print("ok")
        else:
            print("error: invalid export command format. Use 'export fen' or 'export chrome_trace'")

    elif cmd == "quit":
        if tracing_sys.is_tracing:
            tracing_sys.log_event("command_quit")
            tracing_sys.report_metrics()
            tracing_sys.end_span(tracing_sys.current_span_id, status="EXITED_SUCCESSFULLY")
        print("bye")
        return False

    elif cmd == "help":
        print("Commands: new, move <move>, export fen, export chrome_trace, quit")
        print("ok")

    else:
        print(f"error: unknown command '{cmd}'")

    sys.stdout.flush()
    return True

def main():
    tracing_sys = TracingSystem()
    running = True
    # Initial engine state setup (will trigger tracing start on 'new' command)
    # For a placeholder, we assume the engine starts and waits for 'new' command if
    # the spec requires it, otherwise we can start tracing immediately. Following spec
    # examples, 'new' starts the game.

    while running:
        try:
            # Wait for command from stdin
            line = sys.stdin.readline()
            if not line:
                break # EOF
            running = handle_command(line, tracing_sys)
        except EOFError:
            break
        except Exception as e:
            # Report any unexpected error as an engine error
            sys.stderr.write(f"ENGINE_ERROR: {e}\\n")
            sys.stderr.flush()
            if tracing_sys.is_tracing:
                 tracing_sys.end_span(tracing_sys.current_span_id, status="CRASHED")
            running = False

if __name__ == "__main__":
    main()
