"""Shared offline credential detection. Redact before truncating or persisting.

The legacy clipboard mask and command-history exclusion share these detections;
new tools use redact() and its typed markers. No credential is logged.
"""
import re

PATTERNS = [
    ('pem', re.compile(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----[\s\S]*?(?:-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----|\Z)')),
    ('variable', re.compile(r'''(?ix)["']?\b(?:[A-Z_][A-Z0-9_]*(?:_KEY|_TOKEN|_SECRET|_PASSWORD)|PASSWORD[A-Z0-9_]*|TOKEN|SECRET|API_KEY)["']?\s*[=:]\s*(?:"[^"\n]*"|'[^'\n]*'|[^\s;]+)''')),
    ('bearer', re.compile(r'(?i)\bBearer\s+[^\s\'"<>]+')),
    ('url', re.compile(r'(?i)\b[a-z][a-z0-9+.-]{0,31}://[^:\s/@]+:[^\s/@]*@[^\s]+')),
    ('token', re.compile(r'\b(?:sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9_]{8,}|AKIA[A-Z0-9]{12,})')),
]
TOKEN = re.compile(r'[^\s\'"<>]{24,}')


def detections(text, opaque=True):
    spans = [(m.start(), m.end(), kind) for kind, pattern in PATTERNS for m in pattern.finditer(text)]
    # Keep the previous conservative opaque-token detection for clipboard/history.
    for match in (TOKEN.finditer(text) if opaque else []):
        token = match.group()
        if '://' in token or token.startswith(('/', '~/')) or token.startswith('[oculto:'):
            continue
        classes = sum(bool(re.search(p, token)) for p in (r'[a-z]', r'[A-Z]', r'\d', r'[^A-Za-z0-9]'))
        if classes >= 3 or (len(token) >= 32 and classes >= 2):
            spans.append((*match.span(), 'token'))
    merged = []
    for start, end, kind in sorted(spans, key=lambda s: (s[0], -s[1])):
        if merged and start < merged[-1][1]:
            old = merged[-1]
            merged[-1] = (old[0], max(end, old[1]), old[2])
        else:
            merged.append((start, end, kind))
    return merged


def secret_spans(text):
    return [(start, end) for start, end, _ in detections(text)]


def redact(text):
    # Typed markers preserve structural IDs/hashes; legacy opaque heuristics remain in masked/history.
    spans = detections(text, opaque=False)
    for start, end, kind in reversed(spans):
        text = text[:start] + '[oculto:' + kind + ']' + text[end:]
    return text, len(spans)


def masked(text):
    spans = detections(text)
    for start, end, _ in reversed(spans):
        text = text[:start] + '••••••••' + text[end:]
    return text, bool(spans)
