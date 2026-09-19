"""Shared AWS context. Only use the account and resources in local Terraform outputs."""
import json
import os
from pathlib import Path
from datetime import datetime, timezone
import boto3


def utcnow():
    return datetime.now(timezone.utc).isoformat()


def read_outputs(path):
    raw = json.loads(Path(path).read_text())
    return {key: value['value'] for key, value in raw.items()}


def session_for(config):
    session = boto3.Session(region_name=config['region'])
    actual = session.client('sts').get_caller_identity()['Account']
    if actual != config['account_id']:
        raise ValueError('AWS account does not match Terraform outputs. No changes made.')
    return session


def save_json(path, payload):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as out:
        json.dump(payload, out, indent=2, default=str)
        out.write('\n')


def require_service(ecs, config):
    result = ecs.describe_services(cluster=config['cluster'], services=[config['service']], include=['TAGS'])
    if result.get('failures') or len(result.get('services', [])) != 1:
        raise ValueError('Expected exactly one existing ECS service.')
    service = result['services'][0]
    tags = {t['key']: t['value'] for t in service.get('tags', [])}
    if tags.get('Project') != config['project']:
        raise ValueError('Service Project tag does not match. No changes made.')
    return service
