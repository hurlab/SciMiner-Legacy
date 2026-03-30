# SciMiner 1.1 Deployment Documentation

**Deployed**: 2026-03-25
**Server**: hurlab.med.und.edu
**URL**: http://hurlab.med.und.edu/SciMiner1.1/
**Deployed by**: Claude Code CLI (Claude Opus 4.6)

---

## Architecture

```
Internet → Nginx (port 80) → Tomcat (port 8080) → /webapps/SciMiner1.1/
                                                      ├── WEB-INF/cgi/     (CGI scripts)
                                                      ├── annotation/      (engine + config)
                                                      └── SciMiner/        (static assets)
```

- **No lighttpd** — Tomcat's built-in CGI servlet handles Perl scripts
- **No Apache httpd** — nginx is the reverse proxy
- **Shares data** with production SciMiner via symlinks

---

## Directory Structure

```
/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/
├── index.html                          # Redirect to cgi-bin/sciminer.cgi
├── META-INF/
│   └── context.xml                     # Tomcat context: privileged=true for CGI
├── WEB-INF/
│   ├── web.xml                         # Enables CGI servlet, maps /cgi-bin/*
│   └── cgi/                            # 28 CGI scripts + 6 PM modules + templates
│       ├── sciminer.cgi                # Main entry point
│       ├── analysis.cgi, analysisLaunch.cgi
│       ├── completed.cgi, completedLaunch.cgi
│       ├── MinimalAppSciMiner.pm       # CGI::Application base
│       ├── *.tmpl                      # HTML::Template files
│       ├── Images/                     # UI icons and logos
│       └── FinalResults/               # Per-query output (v1.1 own)
├── SciMiner/                           # Public static assets (served by Tomcat)
│   ├── Images/
│   ├── Samples/
│   └── *.html, *.js, *.tmpl
├── annotation/SciMinerDB/
│   ├── annotationENV.ini               # Main configuration
│   ├── Modules/Annotation/
│   │   ├── SciMiner.pm                 # Core mining engine (1.1 MB)
│   │   ├── SciMinerMining.pm           # Mining utilities (161 KB)
│   │   ├── Config.pm                   # Configuration management
│   │   ├── Logger.pm                   # Structured logging
│   │   ├── basicIO.pm                  # I/O and config loading
│   │   ├── DBHelper.pm                 # Database helpers
│   │   ├── bionlp.pm                   # BioNLP processing
│   │   └── SciMinerSecurity.pm         # Authentication
│   ├── CorpusData/
│   │   ├── Original -> SYMLINK         # 118 GB (shared with production)
│   │   ├── Processed/                  # v1.1 own
│   │   ├── TmpOriginal/               # v1.1 own
│   │   └── TmpProcessed/              # v1.1 own
│   └── Work/
│       ├── Dictionary -> SYMLINK       # 84 MB (shared with production)
│       ├── GO -> SYMLINK               # 69 MB (shared with production)
│       ├── MeSH -> SYMLINK             # 4.5 MB (shared with production)
│       ├── FullSciMinerDB -> SYMLINK   # 167 MB (shared with production)
│       ├── FinalResults/               # v1.1 own (user query results)
│       └── Temp/                       # v1.1 own (working files)
├── scripts/                            # Setup and maintenance scripts
├── t/                                  # Test suite (8 Perl tests)
├── archive/                            # Historical docs
└── web/                                # Original web dir (lighttpd config, kept for reference)
```

---

## Shared Data (Symlinks to Production)

These directories are symlinked to `/home/hurlab/ANNOTATION/SciMinerDB/` to avoid
duplicating ~118 GB of data and to keep dictionaries in sync:

| v1.1 Path | Points To | Size | Purpose |
|---|---|---|---|
| `CorpusData/Original` | `~/ANNOTATION/SciMinerDB/CorpusData/Original` | 118 GB | Downloaded PubMed articles |
| `Work/Dictionary` | `~/ANNOTATION/SciMinerDB/Work/Dictionary` | 84 MB | Gene/protein dictionaries (HGNC, GeneRIF, etc.) |
| `Work/GO` | `~/ANNOTATION/SciMinerDB/Work/GO` | 69 MB | Gene Ontology data |
| `Work/MeSH` | `~/ANNOTATION/SciMinerDB/Work/MeSH` | 4.5 MB | Medical Subject Headings |
| `Work/FullSciMinerDB` | `~/ANNOTATION/SciMinerDB/Work/FullSciMinerDB` | 167 MB | Pre-computed interaction & summary data |

**Separate (v1.1 own):**
- `CorpusData/Processed/`, `TmpOriginal/`, `TmpProcessed/` — working files
- `Work/FinalResults/` — per-user query results
- `Work/Temp/` — temporary analysis files
- `/tmp/SciMiner1.1/` — CGI temp directory

---

## Configuration

### annotationENV.ini
Location: `annotation/SciMinerDB/annotationENV.ini`

| Key | Value | Notes |
|---|---|---|
| ANNOPath | `/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/` | |
| SciMinerPath | `.../annotation/SciMinerDB/` | |
| SciMinerWebPath | `.../WEB-INF/cgi/` | Where CGI scripts live |
| SciMinerWebTempPath | `/tmp/SciMiner1.1/` | Temp dir for CGI |
| SciMinerServerURL | `http://hurlab.med.und.edu/SciMiner1.1/` | Public URL |
| DB | `sciminer` | Shared with production |
| username | `sciminer` | MySQL user |
| Institution | `University of North Dakota` | |
| AdminEmail | `junguk.hur@med.UND.edu` | |
| MaxDoc | 1000 | Max documents per query |
| MaxNewDoc | 500 | Max new documents |

### WEB-INF/web.xml
- CGI servlet: `org.apache.catalina.servlets.CGIServlet`
- CGI path prefix: `WEB-INF/cgi`
- Executable: `/usr/bin/perl`
- Pass shell environment: `true`
- URL pattern: `/cgi-bin/*`

### META-INF/context.xml
- `privileged="true"` (required for Tomcat CGI servlet)
- Environment: `SCIMINER_HOME`, `PERL5LIB`

---

## Database

Uses the **existing production `sciminer` database** on MySQL (port 3306).
No separate database was created for v1.1 — the schema is compatible.

Tables used: analysis, document, gene, generif, docmesh, duplicatename,
duplicatesymbol, engdictionary, excludelist, includelist, ignorelist, etc.

---

## Perl Dependencies

All installed at system level (Perl 5.38.2):

| Module | Status |
|---|---|
| CGI, CGI::Application, CGI::Session | OK |
| DBI, DBD::mysql | OK |
| HTML::Template | OK |
| LWP::UserAgent | OK |
| JSON | OK |
| XML::LibXML | OK |
| YAML | OK |
| Unicode::String | OK |
| Text::NSP | OK |
| Spreadsheet::WriteExcel | OK |
| Boulder::Medline | OK |
| Crypt::Eksblowfish::Bcrypt | OK |

---

## Path Migration

All paths were updated from the development environment to production:

| Old (WSL2 dev) | New (production) |
|---|---|
| `/home/sciminer/legacy/` | `/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/` |
| `http://localhost:8888/` | `http://hurlab.med.und.edu/SciMiner1.1/` |

Updated in: 28 CGI scripts, 6 PM modules, 30+ annotation scripts, annotationENV.ini

---

## Testing

| Test | Method | Result |
|---|---|---|
| index.html serves | curl HTTP 200 | Pass |
| CGI executes (not raw text) | curl + check HTML output | Pass (14KB HTML) |
| CGI via nginx | curl hurlab.med.und.edu | Pass (HTTP 200) |
| Database connection | MySQL test query | Pass |
| Symlinked data accessible | CGI loads after symlinking | Pass |
| Perl modules | `perl -e "use Module"` for all 15 | All OK |

---

## Maintenance

**Update dictionaries**: Run the existing production dictionary update scripts —
since v1.1 symlinks to production dictionaries, updates happen automatically.

**Restart after Tomcat restart**: No action needed — Tomcat auto-deploys webapps.

**Logs**: Check Tomcat logs at `~/apache-tomcat-9.0.37/logs/catalina.out`

**Temp cleanup**: Periodically clean `/tmp/SciMiner1.1/` if it grows large.
