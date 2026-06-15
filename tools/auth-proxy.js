// Auth-Proxy: injects Peacock JWT into all game requests
// Config is written by installer — do not edit manually
const http = require("http")
const path = require("path")
const fs = require("fs")

const cfg = JSON.parse(fs.readFileSync(path.join(__dirname, "../.config.json"), "utf8"))
const PEACOCK_PORT = 3000
let currentJWT = null

async function authenticate() {
    return new Promise((resolve, reject) => {
        const body = new URLSearchParams({
            grant_type: "external_steam",
            steam_userid: cfg.steamId,
            steam_appid: "1659040",
            pId: cfg.profileUuid,
            locale: "en-US",
            rgn: "EXAN",
        }).toString()
        const req = http.request(
            { hostname: "127.0.0.1", port: PEACOCK_PORT, path: "/oauth/token", method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded", "Content-Length": Buffer.byteLength(body) } },
            (res) => {
                let data = ""
                res.on("data", c => data += c)
                res.on("end", () => {
                    try {
                        const json = JSON.parse(data)
                        currentJWT = json.access_token
                        const payload = JSON.parse(Buffer.from(currentJWT.split(".")[1], "base64url").toString())
                        console.log("[Auth-Proxy] OK — uuid=" + payload.unique_name)
                        setTimeout(authenticate, (payload.exp - Math.floor(Date.now() / 1000) - 120) * 1000)
                        resolve()
                    } catch(e) { reject(e) }
                })
            }
        )
        req.on("error", reject)
        req.write(body)
        req.end()
    })
}

authenticate().then(() => {
    http.createServer((req, res) => {
        const chunks = []
        req.on("data", c => chunks.push(c))
        req.on("end", () => {
            const body = Buffer.concat(chunks)
            const headers = Object.assign({}, req.headers)
            if (!headers["authorization"] && currentJWT)
                headers["authorization"] = "Bearer " + currentJWT
            const proxyReq = http.request(
                { hostname: "127.0.0.1", port: PEACOCK_PORT, path: req.url, method: req.method, headers },
                proxyRes => { res.writeHead(proxyRes.statusCode, proxyRes.headers); proxyRes.pipe(res) }
            )
            proxyReq.on("error", () => { res.writeHead(502); res.end("Bad Gateway") })
            proxyReq.write(body)
            proxyReq.end()
        })
    }).listen(80, "0.0.0.0", () => console.log("[Auth-Proxy] :80 → Peacock :3000"))
}).catch(e => { console.error("[Auth-Proxy] FEHLER:", e.message); process.exit(1) })
