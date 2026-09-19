"""Deploy the digest committed in app/image.txt to an existing ECS service.
Invoked manually through protected GitHub Actions; uses OIDC credentials.
"""
import json
import os
import re
from pathlib import Path
import boto3


def build_revision(definition, image, execution_role, task_role, family):
    if not re.fullmatch(r'docker.io/library/wordpress@sha256:[0-9a-f]{64}', image):
        raise ValueError('Only a pinned official WordPress image is accepted.')
    if definition['family'] != family or definition['executionRoleArn'] != execution_role or definition['taskRoleArn'] != task_role:
        raise ValueError('Unexpected task family or IAM roles. No changes made.')
    permitted = ['family', 'taskRoleArn', 'executionRoleArn', 'networkMode', 'containerDefinitions',
                 'volumes', 'placementConstraints', 'requiresCompatibilities', 'cpu', 'memory',
                 'pidMode', 'ipcMode', 'proxyConfiguration', 'inferenceAccelerators', 'ephemeralStorage', 'runtimePlatform']
    revision = {k: definition[k] for k in permitted if k in definition}
    revision = json.loads(json.dumps(revision))
    if len(revision['containerDefinitions']) != 1 or revision['containerDefinitions'][0]['name'] != 'wordpress':
        raise ValueError('Unexpected containers in service.')
    revision['containerDefinitions'][0]['image'] = image
    return revision


def main():
    image = Path('app/image.txt').read_text().strip()
    session = boto3.Session(region_name=os.environ['AWS_REGION'])
    if session.client('sts').get_caller_identity()['Account'] != os.environ['AWS_ACCOUNT_ID']:
        raise ValueError('Unexpected AWS account.')
    ecs = session.client('ecs'); cluster = os.environ['ECS_CLUSTER']; service = os.environ['ECS_SERVICE']
    result = ecs.describe_services(cluster=cluster, services=[service])
    if result.get('failures') or len(result.get('services', [])) != 1:
        raise ValueError('ECS service was not found.')
    current = result['services'][0]
    if current['desiredCount'] < 1 or len(current.get('deployments', [])) != 1:
        raise ValueError('Service must be initialized and stable.')
    old = current['taskDefinition']
    definition = ecs.describe_task_definition(taskDefinition=old)['taskDefinition']
    revision = build_revision(definition, image, os.environ['EXECUTION_ROLE_ARN'], os.environ['TASK_ROLE_ARN'], os.environ['TASK_FAMILY'])
    new = ecs.register_task_definition(**revision)['taskDefinition']['taskDefinitionArn']
    ecs.update_service(cluster=cluster, service=service, taskDefinition=new)
    try:
        ecs.get_waiter('services_stable').wait(cluster=cluster, services=[service], WaiterConfig={'Delay': 15, 'MaxAttempts': 80})
        actual = ecs.describe_services(cluster=cluster, services=[service])['services'][0]['taskDefinition']
        if actual != new:
            raise RuntimeError('ECS rolled back; the requested revision did not become active.')
    except Exception:
        ecs.update_service(cluster=cluster, service=service, taskDefinition=old)
        print('Deployment failed. Requested rollback to the previous revision; check ECS until stable.')
        raise
    print('Requested image revision is active. Run workstation HTTP and content validation next.')


if __name__ == '__main__':
    main()
