"""Bounded HTTP validation and ECS/ALB evidence capture. Does not mutate AWS."""
import argparse
import concurrent.futures
import json
import math
import time
import urllib.request
import urllib.error
from common import read_outputs, session_for, require_service, save_json, utcnow


def probe(url):
    start = time.monotonic()
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Caleb-Portfolio-Validation/1.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            body = response.read(2_000_000)
            # A 200 WordPress database error page is not a successful application response.
            ok = response.status == 200 and b'Error establishing a database connection' not in body
            return {'ok': ok, 'status': response.status, 'latency_ms': round((time.monotonic()-start)*1000, 2)}
    except (urllib.error.URLError, TimeoutError, OSError):
        return {'ok': False, 'status': None, 'latency_ms': round((time.monotonic()-start)*1000, 2)}


def percentile(values, q):
    return sorted(values)[max(0, math.ceil(len(values)*q)-1)] if values else None


def summarize(samples):
    successes = [s['latency_ms'] for s in samples if s['ok']]
    return {'requests': len(samples), 'successes': len(successes),
            'errors': len(samples)-len(successes), 'p50_ms': percentile(successes, .5),
            'p95_ms': percentile(successes, .95), 'p99_ms': percentile(successes, .99)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs', default='outputs.json')
    parser.add_argument('--requests', type=int, default=20)
    parser.add_argument('--concurrency', type=int, default=2)
    parser.add_argument('--out', default='evidence/raw/http-validation.json')
    args = parser.parse_args()
    if not 1 <= args.requests <= 5000 or not 1 <= args.concurrency <= 20:
        parser.error('Limit requests to 1-5000 and concurrency to 1-20.')
    cfg = read_outputs(args.outputs); session = session_for(cfg)
    ecs = session.client('ecs'); before = require_service(ecs, cfg)
    start = time.monotonic(); started = utcnow()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        samples = list(pool.map(lambda _: probe(cfg['url']), range(args.requests)))
    elapsed = time.monotonic()-start
    after = require_service(ecs, cfg)
    targets = session.client('elbv2').describe_target_health(TargetGroupArn=cfg['target_group_arn'])
    report = {'started_at': started, 'finished_at': utcnow(), 'profile': cfg['profile'],
              'observed': True, 'summary': summarize(samples), 'duration_seconds': round(elapsed, 2),
              'requests_per_second': round(len(samples)/elapsed, 2),
              'running_before': before['runningCount'], 'running_after': after['runningCount'],
              'desired_after': after['desiredCount'], 'targets': targets['TargetHealthDescriptions'],
              'samples': samples, 'limitations': 'HTTP GET only; excludes login, writes, and authenticated sessions. Short tests may not trigger scaling.'}
    save_json(args.out, report); print(json.dumps(report['summary'], indent=2))
    raise SystemExit(1 if report['summary']['errors'] else 0)


if __name__ == '__main__':
    main()
