import manifests from "./manifests.json" with { type: "json" }

const updates = new Map(Object.entries(manifests))

export type UpdateManifest = typeof updates extends Map<unknown, infer TValue> ? TValue : never

function parseVersionCode(version: string): number[] {
    return version.split(".").map(Number)
}

function compareVersionCodes(a: string, b: string): -1 | 0 | 1 {
    const left = parseVersionCode(a)
    const right = parseVersionCode(b)

    for (let i = 0; i < Math.max(left.length, right.length); i++) {
        const x = left[i] ?? 0
        const y = right[i] ?? 0
        if (x < y) return -1
        if (x > y) return 1
    }

    return 0
}

export function getAvailableUpdateFor(platform: string, currentVesrionCode: string): UpdateManifest | null {
    const latest = updates.get(platform)
    if (!latest)
        return null
    if (compareVersionCodes(latest.version, currentVesrionCode) === 1)
        return latest
    return null
}
