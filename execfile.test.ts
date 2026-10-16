// The same early exit makes a promisified execFile never settle (cf. oven-sh/bun#41024).
import { expect, test } from "bun:test";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

test("promisified execFile settles", async () => {
  const result = await Promise.race([
    promisify(execFile)("/bin/sh", ["-c", "echo ok"]).then((r) => r.stdout.trim()),
    Bun.sleep(3000).then(() => "LOST execFile did not settle within 3 s"),
  ]);
  if (result !== "ok") console.log(result);
  expect(result).toBe("ok");
});
