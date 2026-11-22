// node --test scripts/tags.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { highest, parse } from './tags.mjs'

test('prereleases order by semver, and a final release outranks them', () => {
  assert.equal(highest(['v0.2.2-rc.5', 'v0.2.2-rc.10', 'v0.2.2-alpha.3']), 'v0.2.2-rc.10')
  assert.equal(highest(['v0.2.2-rc.5', 'v0.2.2']), 'v0.2.2')
  assert.equal(highest(['v0.2.2', 'v0.2.3-alpha.1']), 'v0.2.3-alpha.1')
})

test('a rebuild sorts above its own release but below the next one', () => {
  assert.equal(highest(['v0.2.2-rc.5', 'v0.2.2-rc.5-r1', 'v0.2.2-rc.5-r2']), 'v0.2.2-rc.5-r2')
  assert.equal(highest(['v0.2.2-rc.5-r9', 'v0.2.2-rc.6']), 'v0.2.2-rc.6')
  assert.equal(highest(['v0.2.2-r3', 'v0.2.3-rc.1']), 'v0.2.3-rc.1')
  assert.equal(parse('v0.2.2-r3').version, '0.2.2')
  assert.equal(highest(['v0.2.2', 'v0.2.2-r3', 'v0.2.2-r10'], '0.2.2'), 'v0.2.2-r10')
})

test('version filter matches the upstream version exactly', () => {
  const tags = ['v0.2.2-rc.5', 'v0.2.2-rc.5-r1', 'v0.2.2-rc.50', 'v0.2.2']
  assert.equal(highest(tags, '0.2.2-rc.5'), 'v0.2.2-rc.5-r1')
  assert.equal(highest(tags, '0.2.2'), 'v0.2.2')
  assert.equal(highest(tags, '0.2.3'), undefined)
})

test('foreign and malformed names are ignored', () => {
  assert.equal(parse('dsh-v0.2.2-rc.5'), null)
  assert.equal(parse('v0.2.2-rc.05'), null)
  assert.equal(parse('latest'), null)
  assert.equal(parse('v0.2.2-rc.5-r1').version, '0.2.2-rc.5')
  assert.equal(highest(['nope', 'v1.0.0^{}']), undefined)
})
