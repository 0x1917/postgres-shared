#!/usr/bin/env node
// Order this repo's source tags.
//
//   node scripts/tags.mjs version <version>  < tags   # highest tag of one upstream version
//   node scripts/tags.mjs max                < tags   # highest tag of the whole series
//
// Tags are `v<upstream version>` for the first publish of a release and
// `v<upstream version>-r<n>` for rebuilds of it. Upstream only ships
// prereleases (0.2.2-rc.5), so ordering is semver, not `sort -V`: sort -V puts
// 0.2.2 below 0.2.2-rc.5, which would stop `latest` moving at the first final
// release. The rebuild suffix is split off before comparing, because as semver
// `rc.5-r1` would sort above `rc.6`.
//
// Reads candidate names on stdin, one per line, ignores anything that is not a
// tag of this shape, prints the winner or nothing, and always exits 0 on a
// valid command.
import { readFileSync } from 'node:fs'

const REBUILD = /-r(\d+)$/
const VERSION = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.]+))?$/

export function parse(name) {
  if (!name.startsWith('v')) return null
  // The suffix comes off first so a rebuild of a final release (v0.2.2-r3) is not
  // mistaken for a prerelease called `r3`.
  const r = REBUILD.exec(name)
  const version = r ? name.slice(1, r.index) : name.slice(1)
  const m = VERSION.exec(version)
  if (!m) return null
  const pre = m[4] === undefined ? [] : m[4].split('.')
  if (pre.some(id => id === '' || (/^\d+$/.test(id) && id.length > 1 && id.startsWith('0')))) return null
  return {
    name,
    core: [Number(m[1]), Number(m[2]), Number(m[3])],
    pre,
    version,
    rebuild: r ? Number(r[1]) : 0,
  }
}

function comparePre(a, b) {
  // A release without a prerelease outranks any prerelease of the same core.
  if (a.length === 0 || b.length === 0) return b.length - a.length
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    const na = /^\d+$/.test(a[i])
    const nb = /^\d+$/.test(b[i])
    if (na && nb) {
      const d = Number(a[i]) - Number(b[i])
      if (d !== 0) return d
    } else if (na !== nb) {
      return na ? -1 : 1
    } else if (a[i] !== b[i]) {
      return a[i] < b[i] ? -1 : 1
    }
  }
  return a.length - b.length
}

export function compare(a, b) {
  for (let i = 0; i < 3; i++) {
    if (a.core[i] !== b.core[i]) return a.core[i] - b.core[i]
  }
  return comparePre(a.pre, b.pre) || a.rebuild - b.rebuild
}

export function highest(names, version) {
  return names
    .map(parse)
    .filter(t => t !== null && (version === undefined || t.version === version))
    .sort(compare)
    .at(-1)?.name
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [cmd, version] = process.argv.slice(2)
  if (!(cmd === 'max' || (cmd === 'version' && version))) {
    console.error('usage: tags.mjs version <version> | max   (tags on stdin)')
    process.exit(2)
  }
  const names = readFileSync(0, 'utf8').split('\n').map(s => s.trim()).filter(Boolean)
  const winner = highest(names, cmd === 'version' ? version : undefined)
  if (winner) console.log(winner)
}
