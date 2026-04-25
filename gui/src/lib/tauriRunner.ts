// ProcessRunner that uses the Tauri shell plugin to spawn the configurator's
// bash scripts and yields stdout lines as an async iterable.
//
// Tauri 2's Command.create('f13-script', args) is mapped via the capability
// allow-list to: `bash <args>`. We pass the absolute script path as the first
// arg, so the actual invocation is `bash <script-path> [...userArgs]`.

import { Command } from "@tauri-apps/plugin-shell";
import type { ProcessRunner } from "./engine.js";

export function createTauriRunner(): ProcessRunner {
  return {
    run(cmd: string, args: string[], env?: Record<string, string>): AsyncIterable<string> {
      // Backpressure-aware queue: lines accumulate, the iterator drains them.
      const queue: string[] = [];
      let resolveNext: ((v: IteratorResult<string>) => void) | null = null;
      let buffer = "";
      let done = false;

      function push(line: string): void {
        if (resolveNext) {
          const r = resolveNext;
          resolveNext = null;
          r({ value: line, done: false });
        } else {
          queue.push(line);
        }
      }

      function finish(): void {
        // Flush any partial trailing line without a newline.
        if (buffer.length > 0) {
          const tail = buffer;
          buffer = "";
          push(tail);
        }
        done = true;
        if (resolveNext) {
          const r = resolveNext;
          resolveNext = null;
          r({ value: undefined as unknown as string, done: true });
        }
      }

      // Build the command: the allow-list maps name "f13-script" to bash.
      // We pass `cmd` (script path) as the first positional, then user args.
      const command = Command.create("f13-script", [cmd, ...args], {
        env: env ?? {},
      });

      command.stdout.on("data", (chunk: string) => {
        buffer += chunk;
        let nl = buffer.indexOf("\n");
        while (nl !== -1) {
          const line = buffer.slice(0, nl);
          buffer = buffer.slice(nl + 1);
          push(line);
          nl = buffer.indexOf("\n");
        }
      });

      command.stderr.on("data", (chunk: string) => {
        // Surface stderr lines too — preflight uses ui::* helpers that go
        // there but our event lines come on stdout. Keeping stderr visible
        // helps debugging without interfering with the JSON event stream.
        // eslint-disable-next-line no-console
        console.debug("[f13-script:stderr]", chunk);
      });

      command.on("close", () => {
        finish();
      });

      command.on("error", (err: unknown) => {
        // eslint-disable-next-line no-console
        console.error("[f13-script:error]", err);
        finish();
      });

      // Spawn — fire-and-forget; close handler drives termination.
      command.spawn().catch((err) => {
        // eslint-disable-next-line no-console
        console.error("[f13-script:spawn]", err);
        finish();
      });

      return {
        [Symbol.asyncIterator]() {
          return {
            next(): Promise<IteratorResult<string>> {
              if (queue.length > 0) {
                return Promise.resolve({ value: queue.shift() as string, done: false });
              }
              if (done) {
                return Promise.resolve({ value: undefined as unknown as string, done: true });
              }
              return new Promise<IteratorResult<string>>((resolve) => {
                resolveNext = resolve;
              });
            },
          };
        },
      };
    },
  };
}
