from pathlib import Path
import copy
import pytest
import boto3
from botocore.stub import Stubber
from deploy_image import build_revision
from recovery_drill import select_task
from validate_live import summarize
from common import session_for
from check_secrets import scan


def definition():
    return {'family': 'portfolio', 'executionRoleArn': 'execution', 'taskRoleArn': 'task',
            'revision': 99, 'status': 'ACTIVE', 'containerDefinitions': [{'name': 'wordpress', 'image': 'old'}]}


def test_deploy_rejects_mutable_image_and_role_change():
    with pytest.raises(ValueError):
        build_revision(definition(), 'wordpress:latest', 'execution', 'task', 'portfolio')
    with pytest.raises(ValueError):
        build_revision(definition(), 'docker.io/library/wordpress@sha256:'+'a'*64, 'different-role', 'task', 'portfolio')


def test_revision_preserves_original_and_strips_response_metadata():
    original = definition(); before = copy.deepcopy(original)
    revision = build_revision(original, 'docker.io/library/wordpress@sha256:'+'a'*64, 'execution', 'task', 'portfolio')
    assert original == before
    assert 'revision' not in revision and 'status' not in revision
    assert revision['containerDefinitions'][0]['image'].endswith('a'*64)


def test_statistics_do_not_hide_failures():
    result = summarize([{'ok': True, 'latency_ms': 10}, {'ok': False, 'latency_ms': 10000}, {'ok': True, 'latency_ms': 20}])
    assert result == {'requests': 3, 'successes': 2, 'errors': 1, 'p50_ms': 10, 'p95_ms': 20, 'p99_ms': 20}
    assert summarize([{'ok': False, 'latency_ms': 100}])['p95_ms'] is None


def test_recovery_refuses_wrong_project_before_listing_or_stopping():
    ecs = boto3.client('ecs', region_name='us-east-1', aws_access_key_id='test', aws_secret_access_key='test')
    stub = Stubber(ecs)
    stub.add_response('describe_services', {'services': [{'serviceName': 'service', 'tags': [{'key': 'Project', 'value': 'other'}]}]},
                      {'cluster': 'cluster', 'services': ['service'], 'include': ['TAGS']})
    with stub, pytest.raises(ValueError, match='Project tag'):
        select_task(ecs, {'cluster': 'cluster', 'service': 'service', 'project': 'portfolio'})
    stub.assert_no_pending_responses()


def test_recovery_refuses_unstable_service():
    ecs = boto3.client('ecs', region_name='us-east-1', aws_access_key_id='test', aws_secret_access_key='test')
    stub = Stubber(ecs)
    stub.add_response('describe_services', {'services': [{'tags': [{'key': 'Project', 'value': 'portfolio'}], 'pendingCount': 1, 'runningCount': 1, 'desiredCount': 2}]},
                      {'cluster': 'cluster', 'services': ['service'], 'include': ['TAGS']})
    with stub, pytest.raises(ValueError, match='stable'):
        select_task(ecs, {'cluster': 'cluster', 'service': 'service', 'project': 'portfolio'})


def test_secret_scan_reports_filename_without_value(tmp_path):
    fake = 'A'+'KIA'+'X'*16
    (tmp_path/'bad.txt').write_text(fake)
    result = scan(tmp_path)
    assert len(result) == 1 and fake not in result[0]


def test_private_state_and_tfvars_are_blocked(tmp_path):
    (tmp_path/'terraform.tfstate').write_text('{}')
    (tmp_path/'terraform.tfvars').write_text('region = "us-east-1"')
    assert len(scan(tmp_path)) == 2
