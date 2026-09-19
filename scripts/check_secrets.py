"""Small repository guardrail, not a substitute for a full secret scanner."""
import re
from pathlib import Path


def scan(root):
    patterns = [re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
                re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
                re.compile(r'(?im)^\s*(?:aws_secret_access_key|aws_secret_key|aws_session_token)\s*=\s*[\"\'][^\"\']{16,}')]
    problems = []
    for path in root.rglob('*'):
        if not path.is_file() or any(p in {'.git', '.terraform', '.venv', '__pycache__', '.pytest_cache', 'raw'} for p in path.parts):
            continue
        if path.suffix == '.tfvars' or path.name.startswith('terraform.tfstate') or path.suffix == '.tfplan':
            problems.append(str(path.relative_to(root)) + ': private deployment file'); continue
        try:
            text = path.read_text()
        except UnicodeError:
            continue
        if any(pattern.search(text) for pattern in patterns):
            problems.append(str(path.relative_to(root)) + ': possible secret (value withheld)')
    return problems


if __name__ == '__main__':
    errors = scan(Path('.'))
    print('\n'.join(errors) if errors else 'Repository secret guardrail passed.')
    raise SystemExit(bool(errors))
