// HTTPS-Proxy: SSL termination for *.hitman.io on port 443 → port 80
const https = require("https"), http = require("http"), fs = require("fs"), path = require("path")
const sslDir = path.join(__dirname, "../ssl")
const opts = {
    key: fs.readFileSync(path.join(sslDir, "hitman-server.key")),
    cert: fs.readFileSync(path.join(sslDir, "hitman-server.crt")),
    minVersion: "TLSv1.2",
}
https.createServer(opts, (req, res) => {
    let body = []
    req.on("data", c => body.push(c))
    req.on("end", () => {
        const pr = http.request(
            { hostname: "127.0.0.1", port: 80, path: req.url, method: req.method, headers: req.headers },
            ps => { res.writeHead(ps.statusCode, ps.headers); ps.pipe(res) }
        )
        pr.on("error", (e) => {
            console.error("[HTTPS-Proxy] Forward error:", e.message)
            res.writeHead(502)
            res.end()
        })
        pr.write(Buffer.concat(body))
        pr.end()
    })
}).listen(443, "0.0.0.0", () => console.log("[HTTPS-Proxy] :443 → :80"))
 .on("error", (e) => {
    console.error("[HTTPS-Proxy] Failed to start:", e.message)
    process.exit(1)
})
