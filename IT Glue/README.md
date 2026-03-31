# IT Glue

Utilities for working with the IT Glue documentation platform — downloading exports and preparing import templates.

See [HOWTO.md](../HOWTO.md) for guidance on downloading and running scripts.

---

## Scripts

| Script | Description |
|---|---|
| [Download IT Glue Export.ps1](Download%20IT%20Glue%20Export.ps1) | Downloads an IT Glue account export via the IT Glue API. Requires an API key passed via parameter or `$env:ITGlueAPIKey`. |
| [Format Import Template.py](Format%20Import%20Template.py) | Reformats a CSV or spreadsheet to match an IT Glue flexible asset import template layout. |
