import { spawn } from "node:child_process";

export async function runProcess(command, args, options = {}) {
  await new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      env: options.env ?? process.env,
      stdio: options.stdio ?? "inherit",
    });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} failed (${signal ?? code})`));
    });
  });
}
