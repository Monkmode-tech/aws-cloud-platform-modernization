"""Stop one tagged lab task, then observe replacement and HTTP recovery.
This tests task replacement, not database restore or regional disaster recovery.
"""
import argparse
import time
from common import read_outputs, session_for, require_service, save_json, utcnow
from validate_live import probe


def select_task(ecs, cfg):
    service = require_service(ecs, cfg)
    if service['pendingCount'] or service['runningCount'] != service['desiredCount'] or service['desiredCount'] < 1:
        raise ValueError('Service must be stable before the drill.')
    if len(service.get('deployments', [])) != 1:
        raise ValueError('Wait for the active deployment to finish.')
    result = ecs.list_tasks(cluster=cfg['cluster'], serviceName=cfg['service'], desiredStatus='RUNNING')
    if not result['taskArns']:
        raise ValueError('No running service task found.')
    return result['taskArns'][0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs', default='outputs.json')
    parser.add_argument('--confirm-project', required=True)
    parser.add_argument('--out', default='evidence/raw/recovery.json')
    args = parser.parse_args()
    cfg = read_outputs(args.outputs)
    if args.confirm_project != cfg['project'] or cfg['profile'] != 'lab':
        raise ValueError('This destructive drill is restricted to the lab profile and exact project confirmation.')
    session = session_for(cfg); ecs = session.client('ecs')
    task = select_task(ecs, cfg)
    if not probe(cfg['url'])['ok']:
        raise ValueError('Application must pass its HTTP baseline check before the drill.')
    started = utcnow(); start = time.monotonic(); samples = []; recovered = False
    ecs.stop_task(cluster=cfg['cluster'], task=task, reason='Explicit portfolio task-replacement drill')
    try:
        consecutive = 0
        while time.monotonic()-start < 600:
            sample = probe(cfg['url']); sample['elapsed_seconds'] = round(time.monotonic()-start, 2)
            samples.append(sample); consecutive = consecutive+1 if sample['ok'] else 0
            running = ecs.list_tasks(cluster=cfg['cluster'], serviceName=cfg['service'], desiredStatus='RUNNING')['taskArns']
            if consecutive >= 3 and running and task not in running:
                service = require_service(ecs, cfg)
                if service['runningCount'] == service['desiredCount'] and service['pendingCount'] == 0:
                    recovered = True; break
            time.sleep(5)
    finally:
        save_json(args.out, {'started_at': started, 'finished_at': utcnow(), 'observed': True,
            'scenario': 'Stop one Fargate task; ECS replaces it', 'recovered': recovered,
            'replacement_and_http_stability_seconds': round(time.monotonic()-start, 2),
            'failed_probes': sum(not s['ok'] for s in samples), 'samples': samples,
            'rpo': 'Not measured; no database failure or restore performed',
            'limitation': 'Sampled requests do not prove continuous availability. ECS may recover between probes.'})
    print('Recovery observed.' if recovered else 'Recovery timed out; inspect ECS events and logs.')
    raise SystemExit(0 if recovered else 1)


if __name__ == '__main__':
    main()
