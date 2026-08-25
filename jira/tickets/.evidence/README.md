# Evidence artifacts

Collector writes one JSON record per EPIC.

Usage:

```sh
bash scripts/evidence/evidence-collector.sh EPIC-287
bash scripts/evidence/evidence-collector.sh EPIC-290 --commit HEAD
```

Optional sidecar `<EPIC-ID>.test.log` contributes `test_output_byte`; absent log is `0`.
