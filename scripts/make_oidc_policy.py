"""Write narrowly scoped deployment-role policies; does not change AWS IAM."""
import argparse
from common import read_outputs, save_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outputs', default='outputs.json')
    parser.add_argument('--subject', required=True, help='Exact GitHub OIDC sub claim for the protected aws-deploy environment')
    args = parser.parse_args(); cfg = read_outputs(args.outputs)
    if not args.subject.startswith('repo:') or not args.subject.endswith(':environment:aws-deploy') or '*' in args.subject:
        parser.error('Use an exact repository subject ending :environment:aws-deploy, without wildcards.')
    trust = {'Version': '2012-10-17', 'Statement': [{'Effect': 'Allow',
        'Principal': {'Federated': f"arn:aws:iam::{cfg['account_id']}:oidc-provider/token.actions.githubusercontent.com"},
        'Action': 'sts:AssumeRoleWithWebIdentity', 'Condition': {'StringEquals': {
            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
            'token.actions.githubusercontent.com:sub': args.subject}}}]}
    policy = {'Version': '2012-10-17', 'Statement': [
        {'Effect': 'Allow', 'Action': ['ecs:DescribeServices', 'ecs:UpdateService'], 'Resource': cfg['service_arn']},
        {'Effect': 'Allow', 'Action': ['ecs:DescribeTaskDefinition', 'ecs:RegisterTaskDefinition'], 'Resource': '*'},
        {'Effect': 'Allow', 'Action': ['iam:PassRole'], 'Resource': [cfg['execution_role_arn'], cfg['task_role_arn']],
         'Condition': {'StringEquals': {'iam:PassedToService': 'ecs-tasks.amazonaws.com'}}}]}
    save_json('evidence/raw/oidc-trust.json', trust)
    save_json('evidence/raw/deploy-policy.json', policy)
    print('Policy files created locally. Review them before creating the deployment role.')


if __name__ == '__main__':
    main()
