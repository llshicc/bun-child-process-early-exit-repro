import { expect, test } from "bun:test";

test("Bun.spawn: `exited` resolves for the same child", async () => {
  const proc = Bun.spawn(["/bin/sh", "-c", "exit 2"], { stdio: ["pipe", "pipe", "pipe"] });
  const result = await Promise.race([proc.exited, Bun.sleep(3000).then(() => "no exit within 3 s")]);
  if (result !== 2) console.log(`LOST exitCode=${proc.exitCode}`);
  expect(result).toBe(2);
});
