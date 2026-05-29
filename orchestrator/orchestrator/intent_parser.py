"""Map a natural-language query to PHOMBER CLI arguments."""

import re

# International phone number: optional +, digits, spaces, dashes, parens.
_PHONE_RE = re.compile(r"(\+?[\d][\d\s\-\(\)]{6,18}[\d])")


def parse_intent(prompt: str) -> list[str]:
    """Return a PHOMBER argument list derived from *prompt*.

    Raises ValueError when no recognizable target is found.
    """
    match = _PHONE_RE.search(prompt)
    if match:
        # Normalize: remove formatting characters, keep leading +
        raw = match.group(1)
        phone = re.sub(r"[\s\-\(\)]", "", raw)
        return ["-p", phone]

    raise ValueError(
        "No recognizable phone number found in the query. "
        "Example: 'busca información sobre +52 55 1234 5678'"
    )
