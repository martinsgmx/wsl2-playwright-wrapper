import { createServer } from "http";
import { parse } from "querystring";

const PORT = parseInt(process.env.FIXTURE_PORT || "3000", 10);
const USER = process.env.AUTH_USERNAME || "test@example.com";
const PASS = process.env.AUTH_PASSWORD || "test123";

const loginHtml = `<!doctype html>
<html><head><title>Login</title></head>
<body>
  <h1>Login</h1>
  <form method="POST" action="/login">
    <label>Username <input name="username" type="text" /></label><br/>
    <label>Password <input name="password" type="password" /></label><br/>
    <button type="submit">Sign in</button>
  </form>
</body></html>`;

const dashboardHtml = `<!doctype html>
<html><head><title>Dashboard</title></head>
<body><h1>Dashboard</h1><p>OK — authenticated</p></body></html>`;

const server = createServer((req, res) => {
  const url = new URL(req.url || "/", `http://localhost:${PORT}`);
  if (req.method === "GET" && url.pathname === "/login") {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(loginHtml);
    return;
  }
  if (req.method === "POST" && url.pathname === "/login") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      const data = parse(body);
      if (data.username === USER && data.password === PASS) {
        res.writeHead(302, {
          Location: "/dashboard",
          "Set-Cookie": "session=ok; Path=/; HttpOnly",
        });
        res.end();
      } else {
        res.writeHead(401, { "Content-Type": "text/html" });
        res.end("<h1>401 Unauthorized</h1>");
      }
    });
    return;
  }
  if (req.method === "GET" && url.pathname === "/dashboard") {
    const cookie = req.headers.cookie || "";
    if (!cookie.includes("session=ok")) {
      res.writeHead(302, { Location: "/login" });
      res.end();
      return;
    }
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(dashboardHtml);
    return;
  }
  res.writeHead(404);
  res.end("not found");
});

server.listen(PORT, () => {
  console.log(`fixture login server at http://localhost:${PORT}/login (user=${USER})`);
});
