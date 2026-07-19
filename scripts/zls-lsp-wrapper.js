#!/usr/bin/env node
const { spawn } = require("child_process");

const zlsPath = "/usr/local/bin/zls";
const server = spawn(zlsPath, process.argv.slice(2), { stdio: ["pipe", "pipe", "inherit"] });

let buffer = "";
process.stdin.on("data", (chunk) => {
  buffer += chunk.toString("utf-8");
  
  while (true) {
    const headerMatch = buffer.match(/^Content-Length:\s*(\d+)\r?\n\r?\n/);
    if (!headerMatch) break;
    
    const contentLength = parseInt(headerMatch[1], 10);
    const headerEnd = headerMatch[0].length;
    const totalLength = headerEnd + contentLength;
    
    if (buffer.length < totalLength) break;
    
    const jsonStr = buffer.substring(headerEnd, totalLength);
    let fixed = jsonStr;
    try {
      const parsed = JSON.parse(jsonStr);
      if (parsed.method === "initialized" && (parsed.params === undefined || parsed.params === null)) {
        parsed.params = {};
        fixed = JSON.stringify(parsed);
      }
    } catch {}
    
    const fixedHeader = `Content-Length: ${Buffer.byteLength(fixed)}\r\n\r\n`;
    server.stdin.write(fixedHeader + fixed);
    buffer = buffer.substring(totalLength);
  }
});

server.stdout.pipe(process.stdout);
server.on("exit", (code) => process.exit(code ?? 0));
process.on("SIGTERM", () => server.kill("SIGTERM"));
process.on("SIGINT", () => server.kill("SIGINT"));
