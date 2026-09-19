"""Offline security invariants. These do not replace provider validation or an AWS plan."""
from pathlib import Path
import hcl2

ROOT = Path(__file__).resolve().parents[1]


def resources():
    result = []
    for path in (ROOT / 'infra').glob('*.tf'):
        with path.open() as stream:
            for group in hcl2.load(stream).get('resource', []):
                for kind, named in group.items():
                    for name, body in named.items():
                        result.append((kind, name, body))
    return result


def test_every_database_and_filesystem_is_encrypted():
    for kind, name, body in resources():
        if kind == 'aws_db_instance':
            assert body.get('storage_encrypted') is True, name
            assert body.get('publicly_accessible') is False, name
            assert body.get('manage_master_user_password') is True, name
            assert 'password' not in body, name
        if kind == 'aws_efs_file_system':
            assert body.get('encrypted') is True, name


def test_internal_ingress_uses_security_group_identity():
    for kind, name, body in resources():
        if kind != 'aws_vpc_security_group_ingress_rule' or name == 'web':
            continue
        assert 'cidr_ipv4' not in body and 'cidr_ipv6' not in body, name
        assert body.get('referenced_security_group_id'), name
        assert body['from_port'] == body['to_port'], name
        assert body['from_port'] in {80, 3306, 2049}, name


def test_data_route_table_has_no_internet_route():
    data_routes = [body for kind, name, body in resources() if kind == 'aws_route_table' and name == 'data']
    assert len(data_routes) == 1
    assert not data_routes[0].get('route')


def test_normal_execution_role_cannot_read_master_secret():
    policies = {name: body for kind, name, body in resources() if kind == 'aws_iam_role_policy'}
    assert 'master_user_secret' not in policies['execution']['policy']
    assert 'aws_secretsmanager_secret.application.arn' in policies['execution']['policy']
    assert 'master_user_secret' in policies['bootstrap']['policy']


def test_persistent_volume_requires_tls_and_iam():
    definitions = [body for kind, name, body in resources() if kind == 'aws_ecs_task_definition']
    assert definitions
    for definition in definitions:
        for volume in definition.get('volume', []):
            for efs in volume.get('efs_volume_configuration', []):
                assert efs.get('transit_encryption') == 'ENABLED'
                assert efs['authorization_config'][0]['iam'] == 'ENABLED'
