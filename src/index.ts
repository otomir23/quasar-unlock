import { env } from "node:process"

import { serve } from "@hono/node-server"
import { Hono } from "hono"
import { proxy } from "hono/proxy"
import { rateLimiter } from "hono-rate-limiter"

import { getAvailableUpdateFor } from "./versions.ts"

const app = new Hono()

app.use(rateLimiter({
    windowMs: Number(env.RATE_LIMIT_WINDOW_MS || 5) * 60 * 1000,
    limit: Number(env.RATE_LIMIT || 100),
    keyGenerator: (c) => c.req.header("x-forwarded-for") ?? "",
}))

app.all(
    "/generate_204",
    (c) => c.body(null, 204),
)

app.get(
    "/get_sync_info",
    (c) => c.json({
        status: "ok",
        config: {
            account_config: {
                spotter: "alisa",
            },
            device_config: {
                name: "quasar",
            },
            system_config: {
                adbd: {
                    remoteActivation: true,
                    network: true,
                },
            },
        },
        subscription: {
            mode: "transaction",
        },
    }),
)

app.get(
    "/check_updates",
    (c) => {
        const platform = c.req.query("platform")
        const version = c.req.query("version")

        if (platform && version) {
            const update = getAvailableUpdateFor(platform, version)
            if (update)
                return c.json(update)
        }

        return c.json({
            hasUpdate: false,
        })
    },
)

const valid = [
    "quasar.yandex.net",
    "quasar.yandex.ru",
    "scbh.yandex.net",
    "quasar.yasmina.yango.com",
    "scbh.yasmina.yango.com",
    "quasar.yasmina.funtechservices.com",
    "scbh.yasmina.funtechservices.com",
].flatMap(h => [h, `${h}:443`])
app.all(
    `*`,
    (c) => {
        const host = c.req.header("Host")?.toLowerCase()
        if (!host || !valid.find(h => host === h || host.endsWith(`.${h}`))) {
            return c.text("invalid upstream", 400)
        }
        return proxy(
            c.req.url,
            {
                raw: c.req.raw,
            },
        )
    },
)

serve(
    {
        fetch: app.fetch,
        hostname: "127.0.0.1",
        port: Number(env.PORT || 9238),
    },
    (addr) => console.log(`started on ${addr.address}:${addr.port}`)
)
