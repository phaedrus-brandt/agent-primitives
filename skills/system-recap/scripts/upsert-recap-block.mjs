#!/usr/bin/env node
// Upsert a marker-delimited block into a PR description without touching any
// text outside the markers. Usage:
//   node upsert-recap-block.mjs <pr-number> <block-file> [--repo owner/name] [--marker name] [--prepend]
// --marker defaults to system-recap; merge-readiness is the other stack block.
// --prepend puts a NEW block at the top of the body (updates stay in place).
// The block file must start with `<!-- <name>:start -->` and end with
// `<!-- <name>:end -->`. Requires the `gh` CLI to be authenticated.
// Adapted from kentcdodds/kcd-skills (MIT); adds --repo/--marker/--prepend.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

const args = process.argv.slice(2)
function takeFlag(name, hasValue) {
	const i = args.indexOf(name)
	if (i === -1) return undefined
	const value = hasValue ? args[i + 1] : true
	args.splice(i, hasValue ? 2 : 1)
	return value
}
const repo = takeFlag('--repo', true)
const marker = takeFlag('--marker', true) ?? 'system-recap'
const prepend = takeFlag('--prepend', false) ?? false
const repoArgs = repo ? ['-R', repo] : []

const startMarker = `<!-- ${marker}:start -->`
const endMarker = `<!-- ${marker}:end -->`

const [prNumber, blockFile] = args
if (!prNumber || !blockFile) {
	console.error(
		'usage: upsert-recap-block.mjs <pr-number> <block-file> [--repo owner/name] [--marker name] [--prepend]',
	)
	process.exit(1)
}

const block = readFileSync(blockFile, 'utf8').trim()
if (!block.startsWith(startMarker) || !block.endsWith(endMarker)) {
	console.error(
		`block file must start with "${startMarker}" and end with "${endMarker}"`,
	)
	process.exit(1)
}

const body = execFileSync(
	'gh',
	['pr', 'view', prNumber, ...repoArgs, '--json', 'body', '--jq', '.body'],
	{ encoding: 'utf8' },
)

const startIndex = body.indexOf(startMarker)
const endIndex = body.indexOf(endMarker)
const hasExistingBlock =
	startIndex !== -1 && endIndex !== -1 && endIndex > startIndex

const nextBody = hasExistingBlock
	? body.slice(0, startIndex) + block + body.slice(endIndex + endMarker.length)
	: prepend
		? `${block}\n\n${body.trimStart()}`
		: `${body.trimEnd()}\n\n${block}\n`

execFileSync('gh', ['pr', 'edit', prNumber, ...repoArgs, '--body-file', '-'], {
	input: nextBody,
})

console.log(
	hasExistingBlock
		? `updated ${marker} block on PR #${prNumber}`
		: `added ${marker} block to PR #${prNumber}${prepend ? ' (top)' : ''}`,
)
