# Access — credentials and read recipes

Reference for preflight and snapshot. All calls target org `BrandtInfoServices`, project `Itinio Software Development`. Recipes verified live 2026-08-04.

## Credentials

The PAT lives at `~/.config/backlog-agent/pat` (file mode 600). It is scoped `vso.work` — Work Items, **read only**. Keep it out of terminal output, out of committed files, and out of process argv. Define this helper once and make every call through it — the header travels via process substitution, never as a visible argument:

```sh
BASE='https://dev.azure.com/BrandtInfoServices/Itinio%20Software%20Development/_apis'
authcurl() {
  curl -s -w '\n%{http_code}' -K <(printf 'header = "Authorization: Basic %s"' \
    "$(printf ':%s' "$(cat ~/.config/backlog-agent/pat)" | base64)") "$@"
}
```

`authcurl` prints the response body, then the HTTP status on the final line.

**Every call fails closed.** Split the status off the output and require 200 before using the body. On any other status — 401, 403, 404, 429, 5xx — stop the patrol and report the failing call and status. A patrol built on a partial or failed response reports fiction.

If the PAT file is missing, stop and tell the operator to complete Setup below. The patrol itself never creates, lists, or revokes tokens.

## Setup (human, one-time, outside any patrol)

A person with board access mints the read-only PAT interactively (`az login` first):

```sh
az rest --method post \
  --url 'https://vssps.dev.azure.com/BrandtInfoServices/_apis/tokens/pats?api-version=7.1-preview.1' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798' \
  --body '{"displayName":"backlog-agent-readonly","scope":"vso.work","validTo":"<90 days out, ISO 8601>","allOrgs":false}' \
  --query 'patToken.token' -o tsv > ~/.config/backlog-agent/pat
chmod 600 ~/.config/backlog-agent/pat
```

Exactly one token named `backlog-agent-readonly` should exist; the human revokes extras.

## Preflight probes

Run the WIQL query from the snapshot section first — a 200 with a valid `workItems` array is the read probe. Then take the **first id it returned** and probe writes — expect HTTP **401** (the token refuses writes at the auth layer; this `op":"test"` request would change nothing even if accepted):

```sh
authcurl -H 'Content-Type: application/json-patch+json' \
  -X PATCH -d '[{"op":"test","path":"/fields/System.Id","value":<first id>}]' \
  "$BASE/wit/workitems/<first id>?api-version=7.1"
```

Any write-probe status other than 401 means the token can write. Follow the over-scoped-token rule in `SKILL.md`.

## Snapshot

### 1. Open item ids (WIQL)

```sh
authcurl -H 'Content-Type: application/json' -X POST \
  "$BASE/wit/wiql?api-version=7.1&\$top=15000" \
  -d '{"query":"SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.State] NOT IN ('"'"'Closed'"'"','"'"'Done'"'"','"'"'Removed'"'"','"'"'Completed'"'"') ORDER BY [System.Id]"}'
```

Require status 200 and a present `workItems` array; its length is the count the snapshot step must match. Around 5,000 open items is normal. If exactly 15,000 arrive, the cap truncated the result: repeat the query with `AND [System.Id] > <last id received>` appended, and concatenate, until a page comes back short.

### 2. Fields (batch, 200 ids per call)

POST id chunks of at most 200 to the batch read endpoint until every id is fetched; require 200 on each call:

```sh
authcurl -H 'Content-Type: application/json' -X POST \
  "$BASE/wit/workitemsbatch?api-version=7.1" \
  -d '{"ids":[<up to 200 ids>],"fields":[
    "System.Id","System.Title","System.WorkItemType","System.State",
    "System.AssignedTo","System.CreatedBy","System.AreaPath","System.IterationPath",
    "System.CreatedDate","System.ChangedDate",
    "Microsoft.VSTS.Common.Priority","Microsoft.VSTS.Common.Severity","System.Tags",
    "System.Description","Microsoft.VSTS.TCM.ReproSteps",
    "Microsoft.VSTS.Common.AcceptanceCriteria","System.Parent","System.CommentCount"]}'
```

Concatenate `value[].fields` into the working file. Description, ReproSteps, and AcceptanceCriteria arrive as HTML; strip tags before measuring length or hashing.

### 3. Relations (per card, on demand)

Only the duplicate gate needs links, and only for candidate cards:

```sh
authcurl "$BASE/wit/workitems/<id>?\$expand=relations&api-version=7.1"
```

The no-link condition holds only on a 200 response whose `relations` array is absent, empty, or contains no entry whose `url` ends in the other candidate's id (non-card links carry GUID urls; ignore them). On any other status, drop the candidate rather than guess.

### 4. Comments (per card, on demand)

For drafting context on a thin card:

```sh
authcurl "$BASE/wit/workItems/<id>/comments?api-version=7.1-preview.4"
```
