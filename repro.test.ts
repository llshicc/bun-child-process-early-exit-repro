import { expect, test } from "bun:test";
import { ChildProcess, spawn } from "node:child_process";

// Record any event a ChildProcess emits while spawn() is still on the stack.
let inSpawn = false;
const emittedInsideSpawn: string[] = [];
const emit = ChildProcess.prototype.emit;
ChildProcess.prototype.emit = function (event: string, ...args: unknown[]) {
  if (inSpawn) emittedInsideSpawn.push(event);
  return emit.call(this, event, ...args);
};

test("'exit' reaches a listener attached right after spawn()", async () => {
  inSpawn = true;
  const child = spawn("/bin/sh", ["-c", "exit 2"]);
  inSpawn = false;
  const exited = new Promise((resolve) => child.on("exit", resolve));
  const result = await Promise.race([exited, Bun.sleep(3000).then(() => "no 'exit' within 3 s")]);
  if (result !== 2) {
    console.log(`LOST emitted inside spawn(): [${emittedInsideSpawn}], child.exitCode=${child.exitCode}`);
  }
  expect(result).toBe(2);
});
