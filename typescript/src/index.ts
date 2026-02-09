interface Span {
    spanId: string;
    name: string;
    startTime: number;
    parentId?: string;
    status: 'STARTED' | 'COMPLETED' | 'FAILED' | 'EXITED_SUCCESSFULLY';
    tags: Record<string, string>;
    endTime?: number;
}

interface TraceEvent {
    eventId: string;
    timestamp: number;
    name: string;
    payload: Record<string, any>;
    spanId: string | null;
}

interface Metrics {
    [name: string]: { timestamp: number, value: number, unit: string }[];
}

// --- Tracing/Diagnostics Scaffolding (Issue #87) ---

class TracingSystem {
    private spans: Span[] = [];
    private events: TraceEvent[] = [];
    private metrics: Metrics = {};
    private isTracing: boolean = false;
    private currentSpanId: string | null = null;
    private currentTraceId: string | null = null;

    private generateId(): string {
        return Math.random().toString(36).substring(2, 15);
    }

    public startSpan(name: string, parentId?: string): string {
        if (!this.isTracing) return '';
        const spanId = this.generateId();
        this.currentSpanId = spanId;
        this.spans.push({
            spanId,
            name,
            startTime: Date.now() / 1000, // Seconds since epoch
            parentId,
            status: 'STARTED',
            tags: { engine: "typescript_scaffold" }
        });
        return spanId;
    }

    public endSpan(spanId: string, status: Span['status'] = 'COMPLETED'): void {
        if (!this.isTracing) return;
        const span = this.spans.find(s => s.spanId === spanId && s.status === 'STARTED');
        if (span) {
            span.endTime = Date.now() / 1000;
            span.status = status;
        }
    }

    public logEvent(name: string, payload: Record<string, any> = {}): void {
        if (!this.isTracing) return;
        this.events.push({
            eventId: this.generateId(),
            timestamp: Date.now() / 1000,
            name,
            payload,
            spanId: this.currentSpanId
        });
    }

    public recordMetric(name: string, value: number, unit: string = "count"): void {
        if (!this.isTracing) return;
        if (!this.metrics[name]) {
            this.metrics[name] = [];
        }
        this.metrics[name].push({
            timestamp: Date.now() / 1000,
            value,
            unit
        });
    }

    public exportChromeTrace(): string {
        if (!this.isTracing) return "{}";
        
        const traceEvents: any[] = [];
        
        // Convert spans to Chrome format (Simplified)
        this.spans.forEach(span => {
            if (span.endTime) {
                traceEvents.push({
                    ph: "X", // Complete event
                    name: span.name,
                    pid: 1, // Process ID (Placeholder)
                    tid: 1, // Thread ID (Placeholder)
                    ts: Math.floor(span.startTime * 1000000), // Microseconds
                    dur: Math.floor((span.endTime - span.startTime) * 1000000),
                    args: { status: span.status, tags: span.tags }
                });
            }
        });

        // Convert events to Chrome format (Simplified)
        this.events.forEach(event => {
            traceEvents.push({
                ph: "i", // Instant event
                name: event.name,
                pid: 1,
                tid: 1,
                ts: Math.floor(event.timestamp * 1000000),
                args: { payload: event.payload, spanId: event.spanId }
            });
        });
        
        return JSON.stringify({ traceEvents }, null, 2);
    }

    public reportMetrics(): void {
        if (!this.isTracing) return;
        console.log(`METRICS REPORT: ${JSON.stringify(this.metrics, null, 2)}`);
    }

    public initializeTracing(): void {
        this.isTracing = true;
        this.currentTraceId = this.startSpan("engine_startup");
        this.logEvent("command_new");
    }
}

// --- Engine Core Placeholder ---

function displayBoardAscii(state: string): void {
    // Placeholder for ASCII output with coordinates
    console.log("debug board state: (Placeholder)");
    console.log("8 . . . . . . . .");
    console.log("7 . . . . . . . .");
    console.log("6 . . . . . . . .");
    console.log("5 . . . . . . . .");
    console.log("4 . . . . . . . .");
    console.log("3 . . . . . . . .");
    console.log("2 . . . . . . . .");
    console.log("1 . . . . . . . .");
    console.log("  a b c d e f g h");
}

function handleCommand(commandLine: string, tracingSys: TracingSystem): boolean {
    const parts = commandLine.trim().split(/\\s+/);
    if (parts.length === 0 || parts[0] === '') {
        return true;
    }

    const cmd = parts[0].toLowerCase();

    if (cmd === "new") {
        if (!tracingSys['isTracingInitialized']) { // Check against initialization flag for first run context
            tracingSys.initializeTracing();
            tracingSys['isTracingInitialized'] = true;
        }
        console.log("ok");
    } else if (cmd === "move") {
        const move = parts[1];
        if (move) {
            const spanId = tracingSys.startSpan(`move_${move}`, tracingSys['currentSpanId']);
            tracingSys.logEvent("move_attempt", { move });
            
            // Simulate move execution delay
            setTimeout(() => {
                tracingSys.recordMetric("move_execution_time", 10, "ms"); // Placeholder time
                tracingSys.endSpan(spanId);
                process.stdout.write("ok\\n");
                process.stdout.flush();
            }, 10); // Small async delay to simulate work
            
            return true; // Wait for async command completion
        } else {
            console.error("error: invalid move command format");
        }
    } else if (cmd === "export") {
        const subCmd = parts[1];
        if (subCmd === "fen") {
            displayBoardAscii("current_state");
            console.log("ok");
        } else if (subCmd === "chrome_trace") {
            const output = tracingSys.exportChromeTrace();
            process.stdout.write(`TRACE_OUTPUT_START\\n${output}\\nTRACE_OUTPUT_END\\n`);
            process.stdout.flush();
            console.log("ok");
        } else {
            console.error("error: invalid export command format. Use 'export fen' or 'export chrome_trace'");
        }
    } else if (cmd === "quit") {
        if (tracingSys['isTracingInitialized']) {
            tracingSys.logEvent("command_quit");
            tracingSys.reportMetrics();
            if (tracingSys['currentSpanId']) {
                tracingSys.endSpan(tracingSys['currentSpanId'], "EXITED_SUCCESSFULLY");
            }
        }
        console.log("bye");
        return false;
    } else if (cmd === "help") {
        console.log("Commands: new, move <move>, export fen, export chrome_trace, quit");
        console.log("ok");
    } else {
        console.error(`error: unknown command '${cmd}'`);
    }

    process.stdout.flush();
    return true;
}

// --- Main Loop ---

function main() {
    const tracingSys = new TracingSystem();
    let running = true;

    process.stdin.setEncoding('utf8');

    process.stdin.on('data', (data) => {
        const lines = data.toString().split('\\n');
        for (const line of lines) {
            if (line.trim() === '') continue;
            if (!handleCommand(line, tracingSys)) {
                running = false;
                process.exit(0);
            }
        }
    });

    process.stdin.on('end', () => {
        if (running && tracingSys['isTracingInitialized']) {
             tracingSys.logEvent("stdin_ended");
             tracingSys.reportMetrics();
        }
        process.exit(0);
    });
}

// A note on the difference in handling 'move': 
// Since Node.js streams work asynchronously, the 'move' command handler 
// must queue its final 'ok' output after the simulated async operation completes.
// This implementation uses a placeholder setTimeout to simulate this.
// The primary loop is event-driven on 'data'.
main();
