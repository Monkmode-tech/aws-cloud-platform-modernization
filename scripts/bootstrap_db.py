"""Initialize a restricted WordPress DB user in a one-off Fargate task.
No SQL password is written to disk, command arguments, logs, or Terraform state.
Run before application_ready=true. Repeat before first launch if the task fails.
"""
import argparse
import json
import secrets
import sys
from common import read_outputs, session_for, require_service

SALTS = ['AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY',
         'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT']
SQL_PHP = r"""
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
 $db = new mysqli(getenv('DB_HOST'), getenv('MASTER_USER'), getenv('MASTER_PASSWORD'));
 $pw = $db->real_escape_string(getenv('APP_PASSWORD'));
 $db->query("CREATE USER IF NOT EXISTS 'wpapp'@'%' IDENTIFIED BY '".$pw."'");
 $db->query("ALTER USER 'wpapp'@'%' IDENTIFIED BY '".$pw."'");
 $db->query("GRANT ALL PRIVILEGES ON wordpress.* TO 'wpapp'@'%'");
 echo "Restricted WordPress database user initialized.\n";
} catch (Throwable $e) { fwrite(STDERR, "Database bootstrap failed; inspect connectivity and secret configuration.\n"); exit(1); }
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs', default='outputs.json')
    parser.add_argument('--confirm-project', required=True)
    args = parser.parse_args()
    cfg = read_outputs(args.outputs)
    if args.confirm_project != cfg['project']:
        raise ValueError('Project confirmation does not match.')
    session = session_for(cfg)
    ecs, sm = session.client('ecs'), session.client('secretsmanager')
    service = require_service(ecs, cfg)
    if service['desiredCount'] or service['runningCount'] or service['pendingCount']:
        raise ValueError('Bootstrap requires an empty service with desired count zero.')
    # Reuse an existing value for idempotence; never silently rotate a running application.
    try:
        payload = json.loads(sm.get_secret_value(SecretId=cfg['application_secret_arn'])['SecretString'])
        if payload.get('username') != 'wpapp' or not all(payload.get(k) for k in ['password'] + SALTS):
            raise ValueError('Existing application secret has an unexpected schema.')
    except sm.exceptions.ResourceNotFoundException:
        payload = {'username': 'wpapp', 'password': secrets.token_urlsafe(36)}
        payload.update({k: secrets.token_urlsafe(48) for k in SALTS})
        sm.put_secret_value(SecretId=cfg['application_secret_arn'], SecretString=json.dumps(payload))
    definition = ecs.describe_task_definition(taskDefinition=cfg['task_definition_arn'])['taskDefinition']
    image = definition['containerDefinitions'][0]['image']
    registration = ecs.register_task_definition(
        family=cfg['project'] + '-bootstrap', networkMode='awsvpc',
        requiresCompatibilities=['FARGATE'], cpu='256', memory='512',
        executionRoleArn=cfg['bootstrap_execution_role_arn'],
        containerDefinitions=[{
            'name': 'bootstrap', 'image': image, 'essential': True,
            'entryPoint': ['php', '-r'], 'command': [SQL_PHP],
            'environment': [{'name': 'DB_HOST', 'value': cfg['db_host']}],
            'secrets': [
                {'name': 'MASTER_USER', 'valueFrom': cfg['master_secret_arn'] + ':username::'},
                {'name': 'MASTER_PASSWORD', 'valueFrom': cfg['master_secret_arn'] + ':password::'},
                {'name': 'APP_PASSWORD', 'valueFrom': cfg['application_secret_arn'] + ':password::'}],
            'logConfiguration': definition['containerDefinitions'][0]['logConfiguration']}])
    task_definition = registration['taskDefinition']['taskDefinitionArn']
    try:
        run = ecs.run_task(cluster=cfg['cluster'], taskDefinition=task_definition,
            launchType='FARGATE', platformVersion='1.4.0', count=1,
            networkConfiguration={'awsvpcConfiguration': {
                'subnets': cfg['subnet_ids'], 'securityGroups': [cfg['app_security_group_id']],
                'assignPublicIp': 'ENABLED' if cfg['assign_public_ip'] else 'DISABLED'}})
        if run.get('failures') or not run.get('tasks'):
            raise RuntimeError('Fargate bootstrap could not start. Check ECS events.')
        task = run['tasks'][0]['taskArn']
        print('Waiting for database bootstrap task; no application traffic is enabled.')
        ecs.get_waiter('tasks_stopped').wait(cluster=cfg['cluster'], tasks=[task],
                                            WaiterConfig={'Delay': 10, 'MaxAttempts': 90})
        result = ecs.describe_tasks(cluster=cfg['cluster'], tasks=[task])['tasks'][0]
        if not result.get('containers') or result['containers'][0].get('exitCode') != 0:
            raise RuntimeError('Database bootstrap failed. Review the private CloudWatch log.')
        print('Bootstrap succeeded. Set application_ready=true, then apply Terraform.')
    finally:
        ecs.deregister_task_definition(taskDefinition=task_definition)


if __name__ == '__main__':
    main()
