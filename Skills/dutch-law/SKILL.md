---
name: dutch-law
description: |
  Look up Dutch legislation and case law using agent-friendly access methods.
  TRIGGER when: user asks about Dutch law, references wetten.overheid.nl or rechtspraak.nl,
  mentions a Dutch law by name (BW, WvSr, Awb, Grondwet, etc.), mentions an ECLI identifier,
  or needs to read specific articles or court decisions from Dutch legislation.

layer: process

requires:
  - swift-institute-core

applies_to:
  - dutch-law
  - wetten
  - legislation
---

# Dutch Law Lookup

Agent workflow for retrieving Dutch legislation from wetten.overheid.nl.
Research basis: `swift-institute/Research/wetten-overheid-agent-access.md`

---

## Quick Reference

### [NL-WET-001] Primary Method: `/afdrukken`

**Statement**: To read a specific article or section, agents MUST use the `/afdrukken` (print) URL suffix. This produces a minimal page containing only the requested content.

**URL pattern:**

```
https://wetten.overheid.nl/{BWBID}/{YYYY-MM-DD}/0/{PATH}/afdrukken
```

**Examples:**

```
# Single article — BW Boek 2, Artikel 19
https://wetten.overheid.nl/BWBR0003045/2025-01-01/0/Boek2/Titeldeel1/Artikel19/afdrukken

# Single article — Wetboek van Strafrecht, Artikel 310
https://wetten.overheid.nl/BWBR0001854/2025-01-01/0/BoekTweede/TiteldeelXXII/Artikel310/afdrukken

# Entire title section — BW Boek 2, Titel 1 (25 articles)
https://wetten.overheid.nl/BWBR0003045/2025-01-01/0/Boek2/Titeldeel1/afdrukken
```

Use `WebFetch` with an extraction prompt to get the article text.

**Rationale**: `/afdrukken` produces a tiny, focused page — no TOC, no JavaScript, no full-law dump. Directly consumable by agents.

---

### [NL-WET-002] Date Parameter

**Statement**: The date in the URL (`{YYYY-MM-DD}`) determines which version of the law is shown (geldig op / valid on that date). When the user does not specify a date, use today's date.

**Format**: `YYYY-MM-DD` (e.g., `2025-01-01`)

**Rationale**: Dutch laws change over time. Every URL must include a validity date to get a deterministic result.

---

### [NL-WET-003] Path Components

**Statement**: The `{PATH}` component follows the law's structural hierarchy. Path component names vary per law and MUST match the law's actual structure.

| Dutch term | English | Path examples |
|------------|---------|---------------|
| Boek | Book | `Boek2`, `BoekTweede`, `BoekEerste` |
| Hoofdstuk | Chapter | `Hoofdstuk3` |
| Titeldeel | Title | `Titeldeel1`, `TiteldeelXXII` |
| Afdeling | Section | `Afdeling1` |
| Paragraaf | Paragraph | `Paragraaf1` |
| Artikel | Article | `Artikel19`, `Artikel310`, `Artikel3:2` |

**Numbering is inconsistent across laws**: some use Arabic numerals (`Titeldeel1`), some use Roman (`TiteldeelXXII`), some use Dutch ordinals (`BoekTweede`). Always discover the path rather than guessing.

**Rationale**: Incorrect paths return 404 or the wrong content. Path discovery is a required step.

**Cross-references**: [NL-WET-005]

---

### [NL-WET-004] Granularity Levels

**Statement**: `/afdrukken` works at any hierarchy level. Agents SHOULD use the most specific level that answers the user's question.

| Level | Scope | When to use |
|-------|-------|-------------|
| Artikel | Single article | Precise legal question |
| Afdeling | Section (group of articles) | Related provisions |
| Titeldeel | Title (larger group) | Full topic area |
| Hoofdstuk/Boek | Chapter/Book | Broad context (may be large) |

**Rationale**: Higher granularity = more content. Stay focused to keep agent context clean.

---

## Discovery

### [NL-WET-005] Path Discovery

**Statement**: When the article path is unknown, agents MUST discover it by fetching the law's main page and extracting the path from the table of contents.

**Steps:**

1. Fetch the main page (without `/afdrukken`):
   ```
   WebFetch https://wetten.overheid.nl/{BWBID}/{DATE}
   ```
2. Ask for the TOC structure and article paths in the WebFetch prompt.
3. The TOC shows the hierarchy with anchor fragments like `#Boek2_Titeldeel1_Artikel5`.
4. Convert the anchor fragment to a URL path: replace `_` with `/`.
   - Anchor: `#Boek2_Titeldeel1_Artikel5`
   - Path: `Boek2/Titeldeel1/Artikel5`
5. Construct the `/afdrukken` URL.

**Rationale**: Path components are law-specific and unpredictable. Discovery is the only reliable method.

**Cross-references**: [NL-WET-003]

---

### [NL-WET-006] SRU Search (Finding a Law)

**Statement**: When the BWB ID is unknown, agents SHOULD use the SRU search API to find it.

**URL:**

```
https://zoekservice.overheid.nl/sru/Search?operation=searchRetrieve&version=1.2&x-connection=BWB&query={QUERY}&maximumRecords=10
```

**Useful query fields:**

| Field | Use | Example |
|-------|-----|---------|
| `overheidbwb.afkorting` | Search by abbreviation | `overheidbwb.afkorting=BW` |
| `overheidbwb.titel` | Search by title keyword | `overheidbwb.titel=huur` |
| `dcterms.identifier` | Search by BWB ID | `dcterms.identifier=BWBR0003045` |
| `overheidbwb.rechtsgebied` | Search by legal field | `overheidbwb.rechtsgebied=strafrecht` |
| `dcterms.type` | Filter by type | `dcterms.type=wet` |

**Query syntax**: CQL. Boolean: `AND`, `OR`. Operators: `=`, `==`, `>=`, `<=`.

**Response**: XML with `<dcterms:identifier>`, `<dcterms:title>`, and download URLs.

**Rationale**: SRU is the only metadata search interface. It cannot search within article text, but it can find laws by name, abbreviation, or legal domain.

---

## Common Laws Reference

### [NL-WET-007] Known BWB Identifiers

**Statement**: For frequently referenced laws, agents MAY use the BWB IDs below directly, skipping SRU discovery.

| Abbreviation | Full name | BWB ID |
|--------------|-----------|--------|
| Gw | Grondwet (Constitution) | BWBR0001840 |
| BW 1 | Burgerlijk Wetboek Boek 1 (Persons) | BWBR0002656 |
| BW 2 | Burgerlijk Wetboek Boek 2 (Legal entities) | BWBR0003045 |
| BW 3 | Burgerlijk Wetboek Boek 3 (Property) | BWBR0005291 |
| BW 5 | Burgerlijk Wetboek Boek 5 (Real rights) | BWBR0005288 |
| BW 6 | Burgerlijk Wetboek Boek 6 (Obligations) | BWBR0005289 |
| BW 7 | Burgerlijk Wetboek Boek 7 (Special contracts) | BWBR0005290 |
| BW 8 | Burgerlijk Wetboek Boek 8 (Transport) | BWBR0005034 |
| WvSr | Wetboek van Strafrecht | BWBR0001854 |
| WvSv | Wetboek van Strafvordering | BWBR0001903 |
| Awb | Algemene wet bestuursrecht | BWBR0005537 |
| Rv | Wetboek van Burgerlijke Rechtsvordering | BWBR0001827 |
| Fw | Faillissementswet | BWBR0001860 |
| Wvggz | Wet verplichte ggz | BWBR0040635 |

**BWB ID prefixes:**

| Prefix | Meaning |
|--------|---------|
| `BWBR` | Rijksregeling (national regulation) |
| `BWBV` | Verdrag (treaty) |
| `BWBA` | Autonome regeling (autonomous regulation) |

**Rationale**: Common laws are referenced repeatedly. A lookup table avoids redundant SRU calls.

---

## Agent Workflow Summary

### [NL-WET-008] Standard Workflow

**Statement**: Agents MUST follow this decision tree when looking up Dutch law:

```
User asks about Dutch law
    │
    ├── Is this about CASE LAW (rechtspraak)?
    │     └── YES → go to [NL-WET-015] case law workflow
    │
    ├── Is this about LEGISLATION (wetten)?
    │     │
    │     ├── BWB ID known?
    │     │     ├── YES → go to path check
    │     │     └── NO  → [NL-WET-007] check known table
    │     │                 ├── Found → go to path check
    │     │                 └── Not found → [NL-WET-006] SRU search
    │     │
    │     ├── Need STRUCTURAL INDEX (which articles/leden exist)?
    │     │     └── YES → [NL-WET-017] fetch XML, extract structure
    │     │
    │     ├── Article path known?
    │     │     ├── YES → construct /afdrukken URL [NL-WET-001]
    │     │     └── NO  → [NL-WET-005] discover path from TOC
    │     │
    │     └── WebFetch the /afdrukken URL
    │           → extract article text with prompt
    │           → present to user with citation
    │
    └── Ambiguous → ask user to clarify
```

**Citation format**: When presenting an article, include:
- Law name and abbreviation
- Article number
- Validity date
- Direct URL (without `/afdrukken`, for the user to visit)

**Rationale**: A deterministic workflow prevents agents from fetching full law pages or guessing paths.

---

## Fallback: XML Repository

### [NL-WET-009] XML Repository Access

**Statement**: When structured/programmatic access is needed (e.g., extracting all articles matching a pattern, or parsing cross-references), agents MAY use the XML Repository.

**URL pattern:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/{DATE}_{VERSION}/xml/{BWBID}_{DATE}_{VERSION}.xml
```

**Version suffix**: Usually `_0`. The SRU response provides the exact URL.

**XML structure:**

| Element | Meaning |
|---------|---------|
| `<toestand>` | Root element |
| `<artikel bwb-ng-variabel-deel="{PATH}">` | Article with path |
| `<kop>` → `<label>` + `<nr>` | Article number |
| `<lid>` → `<lidnr>` + `<al>` | Paragraph number + text |
| `<lijst>` → `<li>` | Enumerated lists |
| `<extref>` | Cross-reference to another law |

**The `bwb-ng-variabel-deel` attribute value maps directly to the URL path** used in `/afdrukken` URLs. This is how path discovery works when inspecting XML.

**Rationale**: XML gives structure that HTML cannot. Use it when you need to parse, not just read.

---

## Statute Structure Index

### [NL-WET-017] Structural Index via XML Repository

**Statement**: When an agent needs an overview of a statute's structure (which articles, leden, afdelingen, titels exist), it MUST fetch the XML from the repository and extract the structural elements. The HTML TOC ([NL-WET-005]) gives only article ranges; the XML gives individual articles with their leden.

**URL pattern:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/{BWBID}/{DATE}_0/xml/{BWBID}_{DATE}_0.xml
```

**Example:**

```
https://repository.officiele-overheidspublicaties.nl/bwb/BWBR0003045/2025-01-01_0/xml/BWBR0003045_2025-01-01_0.xml
```

**Extraction**: Use `WebFetch` with a prompt requesting the structural index. The XML contains:

| Element | Attribute/Child | Gives you |
|---------|-----------------|-----------|
| `<boek>`, `<titeldeel>`, `<afdeling>` | `<kop>` → `<label>` + `<nr>` | Hierarchy level + number |
| `<artikel>` | `bwb-ng-variabel-deel` | Exact `/afdrukken` path |
| `<artikel>` | `<kop>` → `<nr>` | Article number (e.g., `8`, `10a`) |
| `<lid>` | `<lidnr>` | Lid numbers within each article |

**WebFetch prompt template:**

```
Extract the complete structural index of this law. For every artikel element, list:
1) the article number (from kop/nr)
2) the bwb-ng-variabel-deel path
3) how many lid elements it contains and their lidnr values
Group by boek/titeldeel/afdeling hierarchy.
```

**Large statutes**: For laws with many articles (e.g., BW Boek 2 has 455+), WebFetch may truncate. In that case, request specific titeldelen in separate calls, or ask for a summary first and drill down.

**Use cases:**
- User asks "which articles does Titel 4 of BW Boek 2 contain?"
- Agent needs to enumerate all leden of a specific article
- Building a table of contents for navigation
- Discovering path components without guessing

**Rationale**: The XML repository is the only source that provides article-level and lid-level granularity in a machine-readable format. The HTML TOC gives ranges (e.g., "Artikel 64-78a") but not individual article metadata. The XML is authoritative and includes the exact `bwb-ng-variabel-deel` paths needed for `/afdrukken` URLs.

**Cross-references**: [NL-WET-009], [NL-WET-005], [NL-WET-003]

---

## Cross-References Between Laws

### [NL-WET-010] Following Cross-References

**Statement**: When an article references another law or article, agents SHOULD follow the reference by constructing a new `/afdrukken` URL for the referenced article.

**Common reference patterns in legal text:**

| Pattern | Example | Action |
|---------|---------|--------|
| "artikel X" (same law) | "artikel 6:162" | Same BWBID, different path |
| "artikel X van [law]" | "artikel 3:40 van het Burgerlijk Wetboek" | Different BWBID |
| "Boek X, titel Y" | "Boek 6, titel 3" | Section-level reference |

**Rationale**: Dutch law is heavily cross-referenced. Following references is essential for complete answers.

---

## Limitations

### [NL-WET-011] Known Limitations

**Statement**: Agents MUST be aware of these limitations:

1. **No full-text search**: Neither wetten.overheid.nl nor SRU supports searching within article text. To find which article contains specific language, the user must know the approximate location.
2. **Path inconsistency**: Numbering schemes differ across laws (Arabic, Roman, Dutch ordinals). Always discover, never guess.
3. **Large sections**: Fetching an entire Boek via `/afdrukken` can still produce large output. Prefer the most specific level.
4. **Historical versions**: Laws change. Always specify a date. If the user asks about "the current law," use today's date.
5. **Undocumented**: The `/afdrukken` endpoint is not in any official API documentation. It works reliably but is technically undocumented.

**Rationale**: Awareness of limitations prevents wasted tool calls and incorrect results.

---

## Case Law (Rechtspraak)

### [NL-WET-012] Fetch Verdict by ECLI

**Statement**: To read a specific court decision, agents MUST use the content endpoint with the ECLI identifier.

**URL pattern:**

```
https://data.rechtspraak.nl/uitspraken/content?id={ECLI}
```

**Examples:**

```
# Hoge Raad decision
https://data.rechtspraak.nl/uitspraken/content?id=ECLI:NL:HR:2023:1291

# Rechtbank Amsterdam decision
https://data.rechtspraak.nl/uitspraken/content?id=ECLI:NL:RBAMS:2023:3197
```

**Response**: XML (~25 KB typical) with three main sections:

| XML element | Content | When to extract |
|-------------|---------|-----------------|
| `inhoudsindicatie/para` | **Summary** | Always — this answers most questions |
| `section[@role="beslissing"]` | **Ruling/decision** | When user asks what was decided |
| `section[@role="overwegingen"]` | **Court's reasoning** | When user asks why |
| `uitspraak.info` | Parties, case number | For full citation |
| `dcterms:creator` | Court name | For citation |
| `dcterms:date` | Decision date | For citation |
| `dcterms:subject` | Legal area(s) | For context |
| `psi:zaaknummer` | Case number | For citation |

Use `WebFetch` with a prompt asking for the summary (`inhoudsindicatie`) and ruling (`beslissing`).

**Rationale**: One URL, structured XML, no auth. The `inhoudsindicatie` is the case law equivalent of `/afdrukken` — focused and concise.

---

### [NL-WET-013] ECLI Format

**Statement**: Dutch case law identifiers follow the ECLI format. Agents MUST understand this format to construct and validate ECLIs.

**Format**: `ECLI:NL:{COURT}:{YEAR}:{NUMBER}`

**Court codes (most common):**

| Code | Court | Level |
|------|-------|-------|
| HR | Hoge Raad | Supreme Court |
| PHR | Parket bij de Hoge Raad | AG at Supreme Court |
| RVS | Raad van State | Council of State (admin) |
| CRVB | Centrale Raad van Beroep | Social Security Appeals |
| CBB | College van Beroep bedrijfsleven | Trade/Industry Appeals |
| GHAMS | Gerechtshof Amsterdam | Court of Appeal |
| GHARL | Gerechtshof Arnhem-Leeuwarden | Court of Appeal |
| GHDHA | Gerechtshof Den Haag | Court of Appeal |
| GHSHE | Gerechtshof 's-Hertogenbosch | Court of Appeal |
| RBAMS | Rechtbank Amsterdam | District Court |
| RBDHA | Rechtbank Den Haag | District Court |
| RBGEL | Rechtbank Gelderland | District Court |
| RBLIM | Rechtbank Limburg | District Court |
| RBMNE | Rechtbank Midden-Nederland | District Court |
| RBNHO | Rechtbank Noord-Holland | District Court |
| RBNNE | Rechtbank Noord-Nederland | District Court |
| RBOBR | Rechtbank Oost-Brabant | District Court |
| RBOVE | Rechtbank Overijssel | District Court |
| RBROT | Rechtbank Rotterdam | District Court |
| RBZWB | Rechtbank Zeeland-West-Brabant | District Court |

**Rationale**: ECLI is the universal key for Dutch case law. Every verdict has one.

---

### [NL-WET-014] Search Case Law

**Statement**: When the ECLI is unknown, agents SHOULD search the ECLI index by metadata.

**URL:**

```
https://data.rechtspraak.nl/uitspraken/zoeken?{PARAMETERS}
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `max` | int | Max results (default 1000) |
| `from` | int | Pagination offset (0-based) |
| `sort` | string | `ASC` (default) or `DESC` |
| `type` | string | `Uitspraak` (verdict) or `Conclusie` (AG opinion) |
| `date` | date | Decision date (one = exact, two = range) |
| `modified` | datetime | Last modified (for sync) |
| `return` | string | `DOC` = only with full text |
| `subject` | URI | Legal area filter |
| `creator` | URI | Court filter |

**Subject URIs:**

| URI | Legal area |
|-----|------------|
| `http://psi.rechtspraak.nl/rechtsgebied#civielRecht` | Civil law |
| `http://psi.rechtspraak.nl/rechtsgebied#strafrecht` | Criminal law |
| `http://psi.rechtspraak.nl/rechtsgebied#bestuursrecht` | Administrative law |
| `http://psi.rechtspraak.nl/rechtsgebied#belastingrecht` | Tax law |

**Creator URIs** (pattern: `http://standaarden.overheid.nl/owms/terms/{Full_Court_Name}`):

| URI suffix | Court |
|------------|-------|
| `Hoge_Raad_der_Nederlanden` | Hoge Raad |
| `Rechtbank_Amsterdam` | Rechtbank Amsterdam |
| `Gerechtshof_Amsterdam` | Gerechtshof Amsterdam |
| `Raad_van_State` | Raad van State |
| `Centrale_Raad_van_Beroep` | CRvB |

**Example** — recent Hoge Raad criminal verdicts:

```
https://data.rechtspraak.nl/uitspraken/zoeken?type=Uitspraak&creator=http://standaarden.overheid.nl/owms/terms/Hoge_Raad_der_Nederlanden&subject=http://psi.rechtspraak.nl/rechtsgebied%23strafrecht&max=5&sort=DESC
```

**Response**: Atom XML feed. Extract `<id>` elements to get ECLIs, then fetch each with [NL-WET-012].

**Limitation**: No full-text search. The API only filters on metadata. For topic-based search, use the web interface or the Dutch-law-mcp MCP server.

**Rationale**: The search endpoint finds relevant ECLIs; the content endpoint delivers the verdict. Two steps, but each is clean and focused.

---

### [NL-WET-015] Case Law Workflow

**Statement**: Agents MUST follow this decision tree for case law lookups:

```
User asks about case law
    │
    ├── ECLI known?
    │     ├── YES → fetch content [NL-WET-012]
    │     └── NO  → does user describe court + date + area?
    │                 ├── YES → search [NL-WET-014] → fetch content
    │                 └── NO  → ask user for more details
    │
    └── Extract from XML:
          → inhoudsindicatie (summary) for quick answer
          → section[@role="beslissing"] for the ruling
          → present with ECLI citation
```

**Citation format**: When presenting case law, include:
- ECLI identifier
- Court name
- Decision date
- Case number (zaaknummer)
- Legal area
- Link: `https://uitspraken.rechtspraak.nl/details?id={ECLI}`

**Rationale**: Consistent citations enable the user to verify and reference the decision.

---

### [NL-WET-016] Case Law Rate Limit

**Statement**: The rechtspraak.nl API limits requests to 10 per second. Agents MUST NOT exceed this rate when making multiple requests.

**Rationale**: Exceeding the rate limit may result in temporary blocking.
